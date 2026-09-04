using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Windows;
using FlowBridge.Windows.Models;
using FlowBridge.Windows.Services;

namespace FlowBridge.Windows.ViewModels;

public sealed class MainViewModel : INotifyPropertyChanged, IDisposable
{
    private readonly BonjourDiscoveryService _discovery;
    private readonly PeerControlService _peerControl;
    private readonly TrustStore _trustStore = new();
    private readonly PeerKeyStore _peerKeyStore = new();
    private readonly SecureMouseReceiver _mouseReceiver;
    private readonly SecureMouseSender _mouseSender;
    private readonly WindowsMouseSharingController _windowsMouseController;
    private readonly HashSet<string> _trustedPeerIds;
    private readonly Dictionary<string, PairingKeyExchange> _outgoingExchanges = [];
    private readonly Dictionary<string, PendingPairingSession> _pairingSessions = [];
    private string _discoveryStatus = "Başlatılıyor";
    private bool _isRunning = true;
    private bool _pairingPromptActive;
    private string _firewallStatus = FirewallRuleService.IsConfigured
        ? "Özel ağ kuralları hazır"
        : "İzin gerekli";

    public MainViewModel()
    {
        DeviceId = DeviceIdentityStore.LoadOrCreate();
        DeviceName = Environment.MachineName;
        _trustedPeerIds = _trustStore.Load();
        _trustedPeerIds.RemoveWhere(peerId => !_peerKeyStore.Has(peerId));
        _trustStore.Save(_trustedPeerIds);
        _discovery = new BonjourDiscoveryService(DeviceId, DeviceName);
        _peerControl = new PeerControlService(DeviceId, DeviceName);
        _mouseReceiver = new SecureMouseReceiver(DeviceId, _peerKeyStore);
        _mouseSender = new SecureMouseSender(DeviceId, _peerKeyStore);
        _windowsMouseController = new WindowsMouseSharingController(_mouseSender);
        _discovery.PeerDiscovered += PeerDiscovered;
        _discovery.PeerRemoved += PeerRemoved;
        _discovery.StatusChanged += (_, status) =>
            Application.Current.Dispatcher.Invoke(() => DiscoveryStatus = status);
        _peerControl.HelloReceived += ControlHelloReceived;
        _peerControl.PairRequestReceived += ControlPairRequestReceived;
        _peerControl.PairChallengeReceived += ControlPairChallengeReceived;
        _peerControl.PairAcceptedReceived += ControlPairAcceptedReceived;
        _peerControl.UnpairReceived += ControlUnpairReceived;
        _peerControl.PeerAddressReceived += ControlPeerAddressReceived;
        _mouseReceiver.ReturnRequested += MouseReturnRequested;
        _mouseReceiver.ReturnReceived += MouseReturnReceived;
        _mouseReceiver.HeartbeatRequested += MouseHeartbeatRequested;
        _mouseReceiver.HeartbeatReceived += MouseHeartbeatReceived;
        _discovery.Start();
        _peerControl.Start();
        _mouseReceiver.Start();
    }

    public string DeviceId { get; }
    public string DeviceName { get; }
    public string ShortDeviceId => DeviceId[..8].ToUpperInvariant();
    public ObservableCollection<PeerDevice> Peers { get; } = [];
    public int PeerCount => Peers.Count;
    public string PermissionStatus => "Windows giriş API'leri hazır";
    public string MouseSharingDetail
    {
        get
        {
            var target = Peers.FirstOrDefault(peer => peer.IsTrusted);
            if (target is null)
                return "Kullanmak için diğer FlowBridge cihazını güvenli biçimde eşleştirin.";
            var edge = TransferPolicy.ExitEdge(DeviceId, "windows", target.Id, target.Platform);
            var edgeTitle = edge == TransferEdge.Right ? "sağ" : "sol";
            return $"Bu Windows cihazının {edgeTitle} kenarından {target.Name} cihazına geçin. Geldiğiniz kenara dönün veya Esc'ye basın.";
        }
    }

    public string FirewallStatus
    {
        get => _firewallStatus;
        private set { _firewallStatus = value; OnPropertyChanged(); }
    }

    public string DiscoveryStatus
    {
        get => _discoveryStatus;
        private set { _discoveryStatus = value; OnPropertyChanged(); }
    }

    public bool IsRunning
    {
        get => _isRunning;
        private set { _isRunning = value; OnPropertyChanged(); OnPropertyChanged(nameof(RunningAction)); }
    }

    public string RunningAction => IsRunning ? "Paylaşımı durdur" : "Paylaşımı başlat";

    public void ToggleRunning()
    {
        if (IsRunning)
        {
            _discovery.Stop();
            Peers.Clear();
            _windowsMouseController.Configure(false, null);
            _mouseReceiver.SetEnabled(false);
        }
        else
        {
            _discovery.Start();
            _mouseReceiver.SetEnabled(true);
        }
        IsRunning = !IsRunning;
        RefreshWindowsMouseSharing();
        OnPropertyChanged(nameof(PeerCount));
    }

    public string PairingCodeFor(PeerDevice peer) => PairingCode.Create(DeviceId, peer.Id);

    public async Task StartPairingAsync(PeerDevice peer)
    {
        if (peer.IsPairingPending) return;
        peer.IsPairingPending = true;
        var requestId = Guid.NewGuid().ToString("N");
        var exchange = PairingKeyExchange.Create();
        _outgoingExchanges[requestId] = exchange;
        await _peerControl.SendPairRequestAsync(peer.Id, requestId, exchange.PublicKey);
        _ = ExpirePairingRequestAsync(peer, requestId);
    }

    public async Task RemoveTrustAsync(PeerDevice peer)
    {
        var key = _peerKeyStore.Load(peer.Id);
        if (key is null)
        {
            RemoveTrustLocally(peer.Id);
            return;
        }
        var authentication = ControlAuthentication.Create(
            ControlMessageType.Unpair,
            DeviceId,
            peer.Id,
            null,
            key
        );
        await _peerControl.SendUnpairAsync(peer.Id, authentication);
        RemoveTrustLocally(peer.Id);
    }

    public async Task ConfigureFirewallAsync()
    {
        FirewallStatus = "Windows yönetici onayı bekleniyor";
        var configured = await FirewallRuleService.ConfigureAsync();
        FirewallStatus = configured ? "Özel ağ kuralları hazır" : "İzin verilmedi";
        if (configured && !IsRunning) ToggleRunning();
    }

    private void PeerDiscovered(object? sender, PeerDevice peer)
    {
        Application.Current.Dispatcher.Invoke(() => UpsertPeer(peer));
    }

    private void ControlHelloReceived(object? sender, ControlEnvelope envelope)
    {
        Application.Current.Dispatcher.Invoke(() =>
        {
            UpsertPeer(new PeerDevice
            {
                Id = envelope.FromId,
                Name = envelope.FromName,
                Platform = envelope.Platform,
                ServiceName = "FlowBridge control channel",
            });
            RefreshWindowsMouseSharing();
        });
    }

    private void ControlPeerAddressReceived(object? sender, PeerAddressEvent peerAddress)
    {
        _mouseSender.SetAddress(peerAddress.PeerId, peerAddress.Address);
    }

    private void MouseReturnRequested(object? sender, string peerId) =>
        _mouseSender.SendReliable(new RemoteMouseEvent("return"), peerId);

    private void MouseReturnReceived(object? sender, string peerId) =>
        Application.Current.Dispatcher.Invoke(() => _windowsMouseController.ReturnFromRemote(peerId));

    private void MouseHeartbeatRequested(object? sender, string peerId) =>
        _mouseSender.Send(new RemoteMouseEvent("heartbeatAck"), peerId);

    private void MouseHeartbeatReceived(object? sender, string peerId) =>
        _windowsMouseController.AcknowledgeHeartbeat(peerId);

    private void ControlPairRequestReceived(object? sender, ControlEnvelope envelope)
    {
        Application.Current.Dispatcher.Invoke(() =>
        {
            if (_pairingPromptActive || _trustedPeerIds.Contains(envelope.FromId)) return;
            _pairingPromptActive = true;
            try
            {
                var peer = UpsertPeer(new PeerDevice
                {
                    Id = envelope.FromId,
                    Name = envelope.FromName,
                    Platform = envelope.Platform,
                    ServiceName = "FlowBridge control channel",
                });
                if (envelope.Version != 3 || envelope.RequestId is null || envelope.PublicKey is null)
                {
                    MessageBox.Show(
                        "Karşı cihaz eski eşleştirme protokolünü kullanıyor. FlowBridge'i iki cihazda da 0.4.0 veya daha yeni sürüme güncelleyin.",
                        "FlowBridge güncelleme gerekli",
                        MessageBoxButton.OK,
                        MessageBoxImage.Warning
                    );
                    return;
                }
                byte[] peerKey;
                using (var exchange = PairingKeyExchange.Create())
                {
                    try
                    {
                        peerKey = exchange.DerivePeerKey(envelope.PublicKey, DeviceId, peer.Id);
                    }
                    catch (FormatException) { return; }
                    catch (System.Security.Cryptography.CryptographicException) { return; }
                    _ = _peerControl.SendPairChallengeAsync(
                        peer.Id,
                        envelope.RequestId,
                        exchange.PublicKey
                    );
                }
                var session = new PendingPairingSession(envelope.RequestId, peer, peerKey);
                _pairingSessions[envelope.RequestId] = session;
                _ = ExpirePairingSessionAsync(peer, envelope.RequestId);
                var result = MessageBox.Show(
                    $"{peer.Name} eşleştirme istiyor. Diğer cihazdaki kodla karşılaştır:\n\n{PairingKeyExchange.VerificationCode(peerKey)}\n\nKod eşleşiyor mu?",
                    "FlowBridge eşleştirme isteği",
                    MessageBoxButton.YesNo,
                    MessageBoxImage.Information
                );
                if (result != MessageBoxResult.Yes)
                {
                    _pairingSessions.Remove(envelope.RequestId);
                    peer.IsPairingPending = false;
                    return;
                }
                session.LocalApproved = true;
                var authentication = ControlAuthentication.Create(
                    ControlMessageType.PairAccepted,
                    DeviceId,
                    peer.Id,
                    envelope.RequestId,
                    session.PeerKey
                );
                _ = _peerControl.SendPairAcceptedAsync(peer.Id, envelope.RequestId, authentication);
                TryCompletePairing(session);
            }
            finally
            {
                _pairingPromptActive = false;
            }
        });
    }

    private void ControlPairChallengeReceived(object? sender, ControlEnvelope envelope)
    {
        Application.Current.Dispatcher.Invoke(() =>
        {
            if (_pairingPromptActive) return;
            _pairingPromptActive = true;
            try
            {
                if (envelope.Version != 3 || envelope.RequestId is null || envelope.PublicKey is null) return;
                if (!_outgoingExchanges.Remove(envelope.RequestId, out var exchange)) return;
                var peer = Peers.FirstOrDefault(item => item.Id == envelope.FromId);
                if (peer is null) { exchange.Dispose(); return; }
                byte[] peerKey;
                try
                {
                    peerKey = exchange.DerivePeerKey(envelope.PublicKey, DeviceId, peer.Id);
                }
                catch (FormatException) { peer.IsPairingPending = false; return; }
                catch (System.Security.Cryptography.CryptographicException)
                {
                    peer.IsPairingPending = false;
                    return;
                }
                finally { exchange.Dispose(); }

                var session = new PendingPairingSession(envelope.RequestId, peer, peerKey);
                _pairingSessions[envelope.RequestId] = session;
                _ = ExpirePairingSessionAsync(peer, envelope.RequestId);
                var result = MessageBox.Show(
                    $"{peer.Name} cihazında otomatik açılan kodla karşılaştır:\n\n{PairingKeyExchange.VerificationCode(peerKey)}\n\nKod eşleşiyor mu?",
                    "FlowBridge güvenli eşleştirme",
                    MessageBoxButton.YesNo,
                    MessageBoxImage.Information
                );
                if (result != MessageBoxResult.Yes)
                {
                    _pairingSessions.Remove(envelope.RequestId);
                    peer.IsPairingPending = false;
                    return;
                }
                session.LocalApproved = true;
                var authentication = ControlAuthentication.Create(
                    ControlMessageType.PairAccepted,
                    DeviceId,
                    peer.Id,
                    envelope.RequestId,
                    session.PeerKey
                );
                _ = _peerControl.SendPairAcceptedAsync(peer.Id, envelope.RequestId, authentication);
                TryCompletePairing(session);
            }
            finally
            {
                _pairingPromptActive = false;
            }
        });
    }

    private void ControlPairAcceptedReceived(object? sender, ControlEnvelope envelope)
    {
        Application.Current.Dispatcher.Invoke(() =>
        {
            if (envelope.RequestId is null
                || !_pairingSessions.TryGetValue(envelope.RequestId, out var session)
                || session.Peer.Id != envelope.FromId) return;
            if (!ControlAuthentication.Verify(
                    envelope.Authentication,
                    ControlMessageType.PairAccepted,
                    envelope.FromId,
                    DeviceId,
                    envelope.RequestId,
                    session.PeerKey
                )) return;
            session.RemoteApproved = true;
            TryCompletePairing(session);
        });
    }

    private void TryCompletePairing(PendingPairingSession session)
    {
        if (!session.LocalApproved || !session.RemoteApproved) return;
        _pairingSessions.Remove(session.RequestId);
        TrustLocally(session.Peer, session.PeerKey);
    }

    private async Task ExpirePairingRequestAsync(PeerDevice peer, string requestId)
    {
        await Task.Delay(TimeSpan.FromSeconds(8));
        await Application.Current.Dispatcher.InvokeAsync(() =>
        {
            if (!_outgoingExchanges.Remove(requestId, out var exchange)) return;
            exchange.Dispose();
            peer.IsPairingPending = false;
            MessageBox.Show(
                "Karşı cihaz güvenli eşleştirme isteğine yanıt vermedi. İki cihazda da FlowBridge 0.4.0 veya daha yeni sürümünü kullanın ve ağ iznini denetleyin.",
                "FlowBridge eşleştirme zaman aşımı",
                MessageBoxButton.OK,
                MessageBoxImage.Warning
            );
        });
    }

    private async Task ExpirePairingSessionAsync(PeerDevice peer, string requestId)
    {
        await Task.Delay(TimeSpan.FromSeconds(30));
        await Application.Current.Dispatcher.InvokeAsync(() =>
        {
            if (_pairingSessions.Remove(requestId)) peer.IsPairingPending = false;
        });
    }

    private void ControlUnpairReceived(object? sender, ControlEnvelope envelope) =>
        Application.Current.Dispatcher.Invoke(() =>
        {
            var key = _peerKeyStore.Load(envelope.FromId);
            if (key is null || !ControlAuthentication.Verify(
                    envelope.Authentication,
                    ControlMessageType.Unpair,
                    envelope.FromId,
                    DeviceId,
                    null,
                    key
                )) return;
            RemoveTrustLocally(envelope.FromId);
        });

    private PeerDevice UpsertPeer(PeerDevice candidate)
    {
        var existing = Peers.FirstOrDefault(peer => peer.Id == candidate.Id);
        if (existing is not null)
        {
            existing.Name = candidate.Name;
            existing.Platform = candidate.Platform;
            existing.ServiceName = candidate.ServiceName;
            return existing;
        }
        candidate.IsTrusted = _trustedPeerIds.Contains(candidate.Id);
        Peers.Add(candidate);
        OnPropertyChanged(nameof(PeerCount));
        return candidate;
    }

    private void TrustLocally(PeerDevice peer, byte[] peerKey)
    {
        _peerKeyStore.Save(peer.Id, peerKey);
        _mouseReceiver.InvalidatePeer(peer.Id);
        _mouseSender.InvalidatePeer(peer.Id);
        _trustedPeerIds.Add(peer.Id);
        peer.IsPairingPending = false;
        peer.IsTrusted = true;
        _trustStore.Save(_trustedPeerIds);
        RefreshWindowsMouseSharing();
    }

    private void RemoveTrustLocally(string peerId)
    {
        _trustedPeerIds.Remove(peerId);
        _peerKeyStore.Remove(peerId);
        _mouseReceiver.InvalidatePeer(peerId);
        _mouseSender.InvalidatePeer(peerId);
        var peer = Peers.FirstOrDefault(item => item.Id == peerId);
        if (peer is not null)
        {
            peer.IsPairingPending = false;
            peer.IsTrusted = false;
        }
        _trustStore.Save(_trustedPeerIds);
        RefreshWindowsMouseSharing();
    }

    private void RefreshWindowsMouseSharing()
    {
        var target = Peers.FirstOrDefault(peer => peer.IsTrusted);
        var exitEdge = target is null
            ? TransferEdge.Left
            : TransferPolicy.ExitEdge(DeviceId, "windows", target.Id, target.Platform);
        _windowsMouseController.Configure(IsRunning && target is not null, target?.Id, exitEdge);
        OnPropertyChanged(nameof(MouseSharingDetail));
    }

    private void PeerRemoved(object? sender, string peerId)
    {
        Application.Current.Dispatcher.Invoke(() =>
        {
            var existing = Peers.FirstOrDefault(peer => peer.Id == peerId);
            if (existing is not null) Peers.Remove(existing);
            RefreshWindowsMouseSharing();
            OnPropertyChanged(nameof(PeerCount));
        });
    }

    public void Dispose()
    {
        _discovery.PeerDiscovered -= PeerDiscovered;
        _discovery.PeerRemoved -= PeerRemoved;
        _peerControl.HelloReceived -= ControlHelloReceived;
        _peerControl.PairRequestReceived -= ControlPairRequestReceived;
        _peerControl.PairChallengeReceived -= ControlPairChallengeReceived;
        _peerControl.PairAcceptedReceived -= ControlPairAcceptedReceived;
        _peerControl.UnpairReceived -= ControlUnpairReceived;
        _peerControl.PeerAddressReceived -= ControlPeerAddressReceived;
        _mouseReceiver.ReturnRequested -= MouseReturnRequested;
        _mouseReceiver.ReturnReceived -= MouseReturnReceived;
        _mouseReceiver.HeartbeatRequested -= MouseHeartbeatRequested;
        _mouseReceiver.HeartbeatReceived -= MouseHeartbeatReceived;
        _windowsMouseController.Dispose();
        _peerControl.Dispose();
        _mouseReceiver.Dispose();
        _mouseSender.Dispose();
        foreach (var exchange in _outgoingExchanges.Values) exchange.Dispose();
        _discovery.Dispose();
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    private void OnPropertyChanged([CallerMemberName] string? propertyName = null) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
}

internal sealed class PendingPairingSession(string requestId, PeerDevice peer, byte[] peerKey)
{
    public string RequestId { get; } = requestId;
    public PeerDevice Peer { get; } = peer;
    public byte[] PeerKey { get; } = peerKey;
    public bool LocalApproved { get; set; }
    public bool RemoteApproved { get; set; }
}
