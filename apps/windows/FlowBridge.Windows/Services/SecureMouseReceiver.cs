using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace FlowBridge.Windows.Services;

public sealed class SecureMouseReceiver : IDisposable
{
    private const int MousePort = 45875;
    private static readonly IPAddress MulticastAddress = IPAddress.Parse("239.255.42.99");
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    private readonly string _localId;
    private readonly PeerKeyStore _keyStore;
    private readonly UdpClient _client;
    private readonly CancellationTokenSource _shutdown = new();
    private readonly Dictionary<string, ulong> _lastSequences = [];
    private readonly Dictionary<string, byte[]> _cachedKeys = [];
    private readonly object _stateLock = new();
    private DateTime _lastAuthenticatedEvent = DateTime.MinValue;
    private bool _leftDown;
    private bool _rightDown;
    private bool _middleDown;
    private string? _activePeerId;
    private TransferEdge _activeEntryEdge = TransferEdge.Left;
    private double _returnOvershoot;
    private Timer? _failsafeTimer;
    private volatile bool _enabled = true;

    private const double ReturnResistance = 45;

    public SecureMouseReceiver(string localId, PeerKeyStore keyStore)
    {
        _localId = localId;
        _keyStore = keyStore;
        _client = new UdpClient(AddressFamily.InterNetwork) { ExclusiveAddressUse = false };
        _client.Client.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.ReuseAddress, true);
        _client.Client.Bind(new IPEndPoint(IPAddress.Any, MousePort));
        _client.JoinMulticastGroup(MulticastAddress);
    }

    public void Start()
    {
        _ = ReceiveLoopAsync(_shutdown.Token);
        _failsafeTimer = new Timer(_ => CheckFailsafe(), null, 100, 100);
    }

    public event EventHandler<string>? ReturnRequested;
    public event EventHandler<string>? ReturnReceived;
    public event EventHandler<string>? HeartbeatRequested;
    public event EventHandler<string>? HeartbeatReceived;

    public void SetEnabled(bool enabled)
    {
        _enabled = enabled;
        if (!enabled)
        {
            _activePeerId = null;
            ReleaseButtons();
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
                var envelope = JsonSerializer.Deserialize<SecureMouseEnvelope>(datagram.Buffer, JsonOptions);
                if (!IsValid(envelope) || envelope!.ToId != _localId) continue;
                var key = KeyFor(envelope.FromId);
                var sequenceKey = SequenceKey(envelope);
                if (key is null || !IsPotentiallyFresh(sequenceKey, envelope.Sequence)) continue;
                var mouseEvent = Decrypt(envelope, key);
                if (mouseEvent is null || !CommitSequence(sequenceKey, envelope.Sequence)) continue;
                lock (_stateLock) _lastAuthenticatedEvent = DateTime.UtcNow;
                if (!_enabled) continue;
                if (mouseEvent.Kind == "return") ReturnReceived?.Invoke(this, envelope.FromId);
                else if (mouseEvent.Kind == "heartbeat") HeartbeatRequested?.Invoke(this, envelope.FromId);
                else if (mouseEvent.Kind == "heartbeatAck") HeartbeatReceived?.Invoke(this, envelope.FromId);
                else Apply(mouseEvent, envelope.FromId);
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested) { break; }
            catch (ObjectDisposedException) { break; }
            catch (JsonException) { }
            catch (CryptographicException) { }
            catch (FormatException) { }
            catch (SocketException) when (!cancellationToken.IsCancellationRequested)
            {
                await Task.Delay(250, cancellationToken).ConfigureAwait(false);
            }
        }
    }

    public void InvalidatePeer(string peerId)
    {
        lock (_stateLock)
        {
            _cachedKeys.Remove(peerId);
            foreach (var key in _lastSequences.Keys.Where(key => key.StartsWith(peerId + "|", StringComparison.Ordinal)).ToArray())
                _lastSequences.Remove(key);
        }
    }

    private byte[]? KeyFor(string peerId)
    {
        lock (_stateLock)
        {
            if (_cachedKeys.TryGetValue(peerId, out var cached)) return cached;
        }
        var loaded = _keyStore.Load(peerId);
        if (loaded is null) return null;
        lock (_stateLock) _cachedKeys[peerId] = loaded;
        return loaded;
    }

    private bool IsPotentiallyFresh(string peerId, ulong sequence)
    {
        lock (_stateLock)
        {
            return !_lastSequences.TryGetValue(peerId, out var previous) || sequence > previous;
        }
    }

    private bool CommitSequence(string peerId, ulong sequence)
    {
        lock (_stateLock)
        {
            if (_lastSequences.TryGetValue(peerId, out var previous) && sequence <= previous) return false;
            _lastSequences[peerId] = sequence;
            return true;
        }
    }

    private static RemoteMouseEvent? Decrypt(SecureMouseEnvelope envelope, byte[] key)
    {
        var combined = Convert.FromBase64String(envelope.Sealed);
        if (combined.Length < 29) return null;
        var nonce = combined.AsSpan(0, 12);
        var ciphertext = combined.AsSpan(12, combined.Length - 28);
        var tag = combined.AsSpan(combined.Length - 16, 16);
        var plaintext = new byte[ciphertext.Length];
        var aad = Encoding.UTF8.GetBytes(
            $"FlowBridge/mouse/v2|{envelope.FromId}|{envelope.ToId}|{envelope.SessionId}|{envelope.Sequence}"
        );
        using var aes = new AesGcm(key, 16);
        aes.Decrypt(nonce, ciphertext, tag, plaintext, aad);
        return JsonSerializer.Deserialize<RemoteMouseEvent>(plaintext, JsonOptions);
    }

    private void Apply(RemoteMouseEvent mouseEvent, string peerId)
    {
        switch (mouseEvent.Kind)
        {
            case "enter":
                _activePeerId = peerId;
                _activeEntryEdge = string.Equals(mouseEvent.Edge, "right", StringComparison.OrdinalIgnoreCase)
                    ? TransferEdge.Right
                    : TransferEdge.Left;
                _returnOvershoot = 0;
                var width = Math.Max(1, NativeMethods.GetSystemMetrics(0));
                var height = Math.Max(1, NativeMethods.GetSystemMetrics(1));
                var entryX = _activeEntryEdge == TransferEdge.Left ? 8 : width - 9;
                NativeMethods.SetCursorPos(entryX, (int)Math.Round(mouseEvent.NormalizedY * (height - 1)));
                break;
            case "move":
                if (_activePeerId != peerId) break;
                if (NativeMethods.GetCursorPos(out var cursor))
                {
                    var screenWidth = Math.Max(1, NativeMethods.GetSystemMetrics(0));
                    var proposedX = cursor.X + mouseEvent.Dx;
                    var pushingOutside = _activeEntryEdge == TransferEdge.Left
                        ? mouseEvent.Dx < 0 && proposedX <= 1
                        : mouseEvent.Dx > 0 && proposedX >= screenWidth - 1;
                    if (pushingOutside)
                    {
                        _returnOvershoot += Math.Abs(mouseEvent.Dx);
                        if (_returnOvershoot >= ReturnResistance)
                        {
                            _activePeerId = null;
                            _returnOvershoot = 0;
                            ReleaseButtons();
                            ReturnRequested?.Invoke(this, peerId);
                            break;
                        }
                    }
                    else if ((_activeEntryEdge == TransferEdge.Left && mouseEvent.Dx > 0)
                             || (_activeEntryEdge == TransferEdge.Right && mouseEvent.Dx < 0))
                    {
                        _returnOvershoot = 0;
                    }
                }
                SendMouse((int)Math.Round(mouseEvent.Dx), (int)Math.Round(mouseEvent.Dy), 0, MouseFlags.Move);
                break;
            case "down": if (_activePeerId == peerId) SetButton(mouseEvent.Button, true); break;
            case "up": if (_activePeerId == peerId) SetButton(mouseEvent.Button, false); break;
            case "scroll":
                if (_activePeerId != peerId) break;
                SendMouse(0, 0, unchecked((uint)((int)Math.Round(mouseEvent.ScrollY * 120))), MouseFlags.Wheel);
                break;
            case "leave":
                if (_activePeerId != peerId) break;
                _activePeerId = null;
                _returnOvershoot = 0;
                ReleaseButtons();
                break;
            case "heartbeat": break;
        }
    }

    private void SetButton(int button, bool down)
    {
        var flag = button switch
        {
            0 => down ? MouseFlags.LeftDown : MouseFlags.LeftUp,
            1 => down ? MouseFlags.RightDown : MouseFlags.RightUp,
            2 => down ? MouseFlags.MiddleDown : MouseFlags.MiddleUp,
            _ => (MouseFlags)0,
        };
        if (flag == 0) return;
        lock (_stateLock)
        {
            if (button == 0) _leftDown = down;
            if (button == 1) _rightDown = down;
            if (button == 2) _middleDown = down;
        }
        SendMouse(0, 0, 0, flag);
    }

    private void CheckFailsafe()
    {
        lock (_stateLock)
        {
            if (DateTime.UtcNow - _lastAuthenticatedEvent <= TimeSpan.FromMilliseconds(500)) return;
        }
        ReleaseButtons();
    }

    private void ReleaseButtons()
    {
        bool left;
        bool right;
        bool middle;
        lock (_stateLock)
        {
            left = _leftDown; right = _rightDown; middle = _middleDown;
            _leftDown = _rightDown = _middleDown = false;
        }
        if (left) SendMouse(0, 0, 0, MouseFlags.LeftUp);
        if (right) SendMouse(0, 0, 0, MouseFlags.RightUp);
        if (middle) SendMouse(0, 0, 0, MouseFlags.MiddleUp);
    }

    private static void SendMouse(int dx, int dy, uint data, MouseFlags flags)
    {
        var input = new Input
        {
            Type = 0,
            Union = new InputUnion
            {
                Mouse = new MouseInput { Dx = dx, Dy = dy, MouseData = data, Flags = flags },
            },
        };
        _ = NativeMethods.SendInput(1, [input], Marshal.SizeOf<Input>());
    }

    private static bool IsValid(SecureMouseEnvelope? envelope) =>
        envelope is { Version: 2, FromId.Length: 32, ToId.Length: 32, SessionId.Length: 32, Sealed.Length: > 0 and < 1_500 }
        && envelope.FromId.All(Uri.IsHexDigit)
        && envelope.ToId.All(Uri.IsHexDigit)
        && envelope.SessionId.All(Uri.IsHexDigit);

    private static string SequenceKey(SecureMouseEnvelope envelope) =>
        $"{envelope.FromId}|{envelope.SessionId}";

    public void Dispose()
    {
        _failsafeTimer?.Dispose();
        _shutdown.Cancel();
        _client.Dispose();
        ReleaseButtons();
        _shutdown.Dispose();
    }

    [Flags]
    private enum MouseFlags : uint
    {
        Move = 0x0001, LeftDown = 0x0002, LeftUp = 0x0004, RightDown = 0x0008,
        RightUp = 0x0010, MiddleDown = 0x0020, MiddleUp = 0x0040, Wheel = 0x0800,
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MouseInput
    {
        public int Dx; public int Dy; public uint MouseData; public MouseFlags Flags;
        public uint Time; public nint ExtraInfo;
    }

    [StructLayout(LayoutKind.Explicit)]
    private struct InputUnion { [FieldOffset(0)] public MouseInput Mouse; }

    [StructLayout(LayoutKind.Sequential)]
    private struct Input { public uint Type; public InputUnion Union; }

    private static class NativeMethods
    {
        [DllImport("user32.dll", SetLastError = true)]
        internal static extern uint SendInput(uint count, [In] Input[] inputs, int size);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool SetCursorPos(int x, int y);

        [DllImport("user32.dll")]
        internal static extern int GetSystemMetrics(int index);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool GetCursorPos(out Point point);
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct Point { public int X; public int Y; }
}

internal sealed record SecureMouseEnvelope(
    int Version,
    string FromId,
    string ToId,
    string SessionId,
    ulong Sequence,
    string Sealed
);

public sealed record RemoteMouseEvent(
    string Kind,
    double Dx = 0,
    double Dy = 0,
    int Button = 0,
    double ScrollY = 0,
    double NormalizedY = 0.5,
    string? Edge = null
);
