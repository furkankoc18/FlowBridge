using System.Net;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Threading.Channels;

namespace FlowBridge.Windows.Services;

public sealed class SecureMouseSender : IDisposable
{
    private const int MousePort = 45875;
    private static readonly IPAddress MulticastAddress = IPAddress.Parse("239.255.42.99");
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    private readonly string _localId;
    private readonly string _sessionId = Convert.ToHexString(RandomNumberGenerator.GetBytes(16)).ToLowerInvariant();
    private readonly PeerKeyStore _keyStore;
    private readonly UdpClient _client = new(AddressFamily.InterNetwork);
    private readonly CancellationTokenSource _shutdown = new();
    private readonly Channel<OutgoingMouseEvent> _outgoing = Channel.CreateUnbounded<OutgoingMouseEvent>(
        new UnboundedChannelOptions { SingleReader = true, SingleWriter = false }
    );
    private readonly Dictionary<string, string> _addresses = [];
    private readonly Dictionary<string, byte[]> _keys = [];
    private readonly Dictionary<string, ulong> _sequences = [];
    private readonly object _stateLock = new();

    public SecureMouseSender(string localId, PeerKeyStore keyStore)
    {
        _localId = localId;
        _keyStore = keyStore;
        _ = SendLoopAsync(_shutdown.Token);
    }

    public void SetAddress(string peerId, string address)
    {
        if (!IPAddress.TryParse(address, out var parsed) || parsed.AddressFamily != AddressFamily.InterNetwork)
            return;
        lock (_stateLock) _addresses[peerId] = address;
    }

    public void InvalidatePeer(string peerId)
    {
        lock (_stateLock)
        {
            _keys.Remove(peerId);
            _sequences.Remove(peerId);
        }
    }

    public void Send(RemoteMouseEvent mouseEvent, string peerId) =>
        _outgoing.Writer.TryWrite(new OutgoingMouseEvent(peerId, mouseEvent));

    public void SendReliable(RemoteMouseEvent mouseEvent, string peerId)
    {
        Send(mouseEvent, peerId);
        _ = Task.Delay(30, _shutdown.Token).ContinueWith(
            _ => Send(mouseEvent, peerId),
            CancellationToken.None,
            TaskContinuationOptions.OnlyOnRanToCompletion,
            TaskScheduler.Default
        );
    }

    private async Task SendLoopAsync(CancellationToken cancellationToken)
    {
        try
        {
            await foreach (var outgoing in _outgoing.Reader.ReadAllAsync(cancellationToken))
                await SendAsync(outgoing, cancellationToken).ConfigureAwait(false);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested) { }
    }

    private async Task SendAsync(OutgoingMouseEvent outgoing, CancellationToken cancellationToken)
    {
        string? address;
        byte[]? key;
        ulong sequence;
        lock (_stateLock)
        {
            _addresses.TryGetValue(outgoing.PeerId, out address);
            if (!_keys.TryGetValue(outgoing.PeerId, out key))
            {
                key = _keyStore.Load(outgoing.PeerId);
                if (key is not null) _keys[outgoing.PeerId] = key;
            }
            sequence = (_sequences.GetValueOrDefault(outgoing.PeerId) + 1);
            _sequences[outgoing.PeerId] = sequence;
        }
        if (key is null) return;
        var targetAddress = address is not null && IPAddress.TryParse(address, out var parsedAddress)
            ? parsedAddress
            : MulticastAddress;

        var plain = JsonSerializer.SerializeToUtf8Bytes(outgoing.Event, JsonOptions);
        var nonce = RandomNumberGenerator.GetBytes(12);
        var ciphertext = new byte[plain.Length];
        var tag = new byte[16];
        var aad = Encoding.UTF8.GetBytes(
            $"FlowBridge/mouse/v2|{_localId}|{outgoing.PeerId}|{_sessionId}|{sequence}"
        );
        using (var aes = new AesGcm(key, 16))
            aes.Encrypt(nonce, plain, ciphertext, tag, aad);
        var combined = new byte[nonce.Length + ciphertext.Length + tag.Length];
        nonce.CopyTo(combined, 0);
        ciphertext.CopyTo(combined, nonce.Length);
        tag.CopyTo(combined, nonce.Length + ciphertext.Length);
        var envelope = new SecureMouseEnvelope(
            2,
            _localId,
            outgoing.PeerId,
            _sessionId,
            sequence,
            Convert.ToBase64String(combined)
        );
        var packet = JsonSerializer.SerializeToUtf8Bytes(envelope, JsonOptions);
        if (packet.Length > 2_048) return;
        await _client.SendAsync(
            packet,
            new IPEndPoint(targetAddress, MousePort),
            cancellationToken
        ).ConfigureAwait(false);
    }

    public void Dispose()
    {
        _outgoing.Writer.TryComplete();
        _shutdown.Cancel();
        _client.Dispose();
        _shutdown.Dispose();
    }

    private sealed record OutgoingMouseEvent(string PeerId, RemoteMouseEvent Event);
}
