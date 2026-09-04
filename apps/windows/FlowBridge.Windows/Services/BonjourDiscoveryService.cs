using FlowBridge.Windows.Models;
using Makaretu.Dns;

namespace FlowBridge.Windows.Services;

public sealed class BonjourDiscoveryService : IDisposable
{
    private const string ServiceType = "_flowbridge._tcp";
    private readonly ServiceDiscovery _discovery = new();
    private readonly string _localId;
    private readonly string _instanceName;
    private ServiceProfile? _profile;
    private Timer? _queryTimer;
    private bool _started;
    private bool _mdnsStarted;

    public BonjourDiscoveryService(string localId, string deviceName)
    {
        _localId = localId;
        _instanceName = ServiceName.Create(localId, deviceName);
        _discovery.ServiceInstanceDiscovered += OnServiceInstanceDiscovered;
        _discovery.ServiceInstanceShutdown += OnServiceInstanceShutdown;
    }

    public event EventHandler<PeerDevice>? PeerDiscovered;
    public event EventHandler<string>? PeerRemoved;
    public event EventHandler<string>? StatusChanged;

    public void Start()
    {
        if (_started) return;
        try
        {
            _profile = new ServiceProfile(_instanceName, ServiceType, 45873, null);
            _profile.AddProperty("version", "1");
            _profile.AddProperty("platform", "windows");
            if (!_mdnsStarted)
            {
                _discovery.Mdns.Start();
                _mdnsStarted = true;
            }
            _discovery.Advertise(_profile);
            _discovery.Announce(_profile);
            _discovery.QueryServiceInstances(ServiceType);
            _queryTimer = new Timer(
                _ => QueryForPeers(),
                null,
                TimeSpan.FromSeconds(3),
                TimeSpan.FromSeconds(3)
            );
            _started = true;
            StatusChanged?.Invoke(this, "Ağ taranıyor");
        }
        catch (Exception error) when (
            error is InvalidOperationException
                or System.Net.Sockets.SocketException
                or ArgumentException
        )
        {
            StatusChanged?.Invoke(this, $"Keşif hatası: {error.Message}");
        }
    }

    public void Stop()
    {
        if (!_started) return;
        if (_profile is not null) _discovery.Unadvertise(_profile);
        _queryTimer?.Dispose();
        _queryTimer = null;
        _profile = null;
        _started = false;
        StatusChanged?.Invoke(this, "Kapalı");
    }

    private void QueryForPeers()
    {
        if (!_started) return;
        try
        {
            _discovery.QueryServiceInstances(ServiceType);
        }
        catch (ObjectDisposedException)
        {
            // Shutdown raced with the periodic query; no recovery is needed.
        }
        catch (System.Net.Sockets.SocketException error)
        {
            StatusChanged?.Invoke(this, $"Keşif hatası: {error.Message}");
        }
    }

    private void OnServiceInstanceDiscovered(object? sender, ServiceInstanceDiscoveryEventArgs args)
    {
        var fullName = args.ServiceInstanceName.ToString();
        if (!ServiceName.TryParse(fullName, out var identity) || identity.Id == _localId) return;
        PeerDiscovered?.Invoke(this, new PeerDevice
        {
            Id = identity.Id,
            Name = identity.Name,
            Platform = "macOS veya Windows",
            ServiceName = fullName,
        });
    }

    private void OnServiceInstanceShutdown(object? sender, ServiceInstanceShutdownEventArgs args)
    {
        if (ServiceName.TryParse(args.ServiceInstanceName.ToString(), out var identity))
            PeerRemoved?.Invoke(this, identity.Id);
    }

    public void Dispose()
    {
        Stop();
        _discovery.ServiceInstanceDiscovered -= OnServiceInstanceDiscovered;
        _discovery.ServiceInstanceShutdown -= OnServiceInstanceShutdown;
        _discovery.Dispose();
    }
}
