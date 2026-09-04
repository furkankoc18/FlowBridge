using System.Net;
using System.Net.Sockets;
using System.Text.Json;

namespace FlowBridge.Windows.Services;

public sealed class PeerControlService : IDisposable
{
    private const int ControlPort = 45874;
    private static readonly IPAddress MulticastAddress = IPAddress.Parse("239.255.42.99");
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    private readonly string _localId;
    private readonly string _localName;
    private readonly UdpClient _client;
    private readonly CancellationTokenSource _shutdown = new();
    private readonly HashSet<string> _handledRequests = [];
    private readonly object _handledRequestsLock = new();
    private Timer? _helloTimer;

    public PeerControlService(string localId, string localName)
    {
        _localId = localId;
        _localName = localName;
        _client = new UdpClient(AddressFamily.InterNetwork)
        {
            ExclusiveAddressUse = false,
        };
        _client.Client.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.ReuseAddress, true);
        _client.Client.Bind(new IPEndPoint(IPAddress.Any, ControlPort));
        _client.JoinMulticastGroup(MulticastAddress);
    }

    public event EventHandler<ControlEnvelope>? HelloReceived;
    public event EventHandler<ControlEnvelope>? PairRequestReceived;
    public event EventHandler<ControlEnvelope>? PairChallengeReceived;
    public event EventHandler<ControlEnvelope>? PairAcceptedReceived;
    public event EventHandler<ControlEnvelope>? UnpairReceived;
    public event EventHandler<PeerAddressEvent>? PeerAddressReceived;

    public void Start()
    {
        _ = ReceiveLoopAsync(_shutdown.Token);
        _helloTimer = new Timer(
            _ => _ = SendHelloAsync(),
            null,
            TimeSpan.Zero,
            TimeSpan.FromSeconds(2)
        );
    }

    public Task SendPairRequestAsync(string peerId, string requestId, string publicKey) =>
        SendRepeatedAsync(ControlEnvelope.PairRequest(_localId, _localName, peerId, requestId, publicKey));

    public Task SendPairChallengeAsync(string peerId, string requestId, string publicKey) =>
        SendRepeatedAsync(ControlEnvelope.PairChallenge(_localId, _localName, peerId, requestId, publicKey));

    public Task SendPairAcceptedAsync(string peerId, string requestId, string authentication) =>
        SendRepeatedAsync(ControlEnvelope.PairAccepted(_localId, _localName, peerId, requestId, authentication));

    public Task SendUnpairAsync(string peerId, string authentication) =>
        SendRepeatedAsync(ControlEnvelope.Unpair(_localId, _localName, peerId, authentication));

    private Task SendHelloAsync() => SendAsync(ControlEnvelope.Hello(_localId, _localName));

    private async Task SendRepeatedAsync(ControlEnvelope envelope)
    {
        try
        {
            await SendAsync(envelope);
            await Task.Delay(200, _shutdown.Token).ConfigureAwait(false);
            await SendAsync(envelope);
            await Task.Delay(500, _shutdown.Token).ConfigureAwait(false);
            await SendAsync(envelope);
        }
        catch (OperationCanceledException) when (_shutdown.IsCancellationRequested)
        {
            // Application shutdown can cancel reliability repeats after the first datagram.
        }
    }

    private async Task SendAsync(ControlEnvelope envelope)
    {
        if (_shutdown.IsCancellationRequested) return;
        var payload = JsonSerializer.SerializeToUtf8Bytes(envelope, JsonOptions);
        if (payload.Length > 2_048) throw new InvalidOperationException("Control message is too large.");
        try
        {
            await _client.SendAsync(payload, new IPEndPoint(MulticastAddress, ControlPort));
        }
        catch (ObjectDisposedException)
        {
            // Application shutdown raced with an outgoing datagram.
        }
        catch (SocketException) when (_shutdown.IsCancellationRequested)
        {
            // The socket was closed as part of application shutdown.
        }
    }

    private async Task ReceiveLoopAsync(CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested)
        {
            try
            {
                var datagram = await _client.ReceiveAsync(cancellationToken);
                if (datagram.Buffer.Length > 2_048) continue;
                var envelope = JsonSerializer.Deserialize<ControlEnvelope>(datagram.Buffer, JsonOptions);
                if (!IsValid(envelope) || envelope!.FromId == _localId) continue;
                if (envelope.ToId is not null && envelope.ToId != _localId) continue;
                PeerAddressReceived?.Invoke(
                    this,
                    new PeerAddressEvent(envelope.FromId, datagram.RemoteEndPoint.Address.ToString())
                );

                switch (envelope.Type)
                {
                    case ControlMessageType.Hello:
                        HelloReceived?.Invoke(this, envelope);
                        break;
                    case ControlMessageType.PairRequest when MarkRequestAsNew(envelope.RequestId):
                        PairRequestReceived?.Invoke(this, envelope);
                        break;
                    case ControlMessageType.PairChallenge when MarkRequestAsNew(envelope.RequestId):
                        PairChallengeReceived?.Invoke(this, envelope);
                        break;
                    case ControlMessageType.PairAccepted:
                        PairAcceptedReceived?.Invoke(this, envelope);
                        break;
                    case ControlMessageType.Unpair:
                        UnpairReceived?.Invoke(this, envelope);
                        break;
                }
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                break;
            }
            catch (ObjectDisposedException)
            {
                break;
            }
            catch (JsonException)
            {
                // Ignore malformed packets from the local network.
            }
            catch (SocketException) when (!cancellationToken.IsCancellationRequested)
            {
                await Task.Delay(500, cancellationToken).ConfigureAwait(false);
            }
        }
    }

    private bool MarkRequestAsNew(string? requestId)
    {
        if (requestId is null) return false;
        lock (_handledRequestsLock)
        {
            if (_handledRequests.Count > 256) _handledRequests.Clear();
            return _handledRequests.Add(requestId);
        }
    }

    private static bool IsValid(ControlEnvelope? envelope) =>
        envelope is
        {
            Version: 2 or 3,
            FromId.Length: 32,
            FromName.Length: > 0 and <= 80,
        }
        && envelope.FromId.All(Uri.IsHexDigit)
        && (envelope.ToId is null
            || envelope.ToId.Length == 32 && envelope.ToId.All(Uri.IsHexDigit));

    public void Dispose()
    {
        _helloTimer?.Dispose();
        _shutdown.Cancel();
        _client.Dispose();
        _shutdown.Dispose();
    }
}

public sealed record PeerAddressEvent(string PeerId, string Address);

public static class ControlMessageType
{
    public const string Hello = "hello";
    public const string PairRequest = "pairRequest";
    public const string PairChallenge = "pairChallenge";
    public const string PairAccepted = "pairAccepted";
    public const string Unpair = "unpair";
}

public sealed record ControlEnvelope(
    string Type,
    int Version,
    string FromId,
    string FromName,
    string Platform,
    string? ToId,
    string? RequestId,
    string? PublicKey,
    string? Authentication
)
{
    public static ControlEnvelope Hello(string fromId, string fromName) =>
        new(ControlMessageType.Hello, 3, fromId, fromName, "windows", null, null, null, null);

    public static ControlEnvelope PairRequest(
        string fromId,
        string fromName,
        string toId,
        string requestId,
        string publicKey
    ) => new(ControlMessageType.PairRequest, 3, fromId, fromName, "windows", toId, requestId, publicKey, null);

    public static ControlEnvelope PairChallenge(
        string fromId,
        string fromName,
        string toId,
        string requestId,
        string publicKey
    ) => new(ControlMessageType.PairChallenge, 3, fromId, fromName, "windows", toId, requestId, publicKey, null);

    public static ControlEnvelope PairAccepted(
        string fromId,
        string fromName,
        string toId,
        string requestId,
        string authentication
    ) => new(ControlMessageType.PairAccepted, 3, fromId, fromName, "windows", toId, requestId, null, authentication);

    public static ControlEnvelope Unpair(string fromId, string fromName, string toId, string authentication) =>
        new(ControlMessageType.Unpair, 3, fromId, fromName, "windows", toId, null, null, authentication);
}
