using System.Runtime.InteropServices;

namespace FlowBridge.Windows.Services;

public sealed class WindowsMouseSharingController : IDisposable
{
    private const int WhMouseLl = 14;
    private const int WhKeyboardLl = 13;
    private const int WmMouseMove = 0x0200;
    private const int WmLeftButtonDown = 0x0201;
    private const int WmLeftButtonUp = 0x0202;
    private const int WmRightButtonDown = 0x0204;
    private const int WmRightButtonUp = 0x0205;
    private const int WmMiddleButtonDown = 0x0207;
    private const int WmMiddleButtonUp = 0x0208;
    private const int WmMouseWheel = 0x020A;
    private const uint LlmhfInjected = 0x00000001;
    private const uint LlkHfInjected = 0x00000010;
    private const int WmKeyDown = 0x0100;
    private const int WmSysKeyDown = 0x0104;
    private const uint VkEscape = 0x1B;
    private const double Sensitivity = 1.7;
    private const double ReturnResistance = 45;

    private readonly SecureMouseSender _sender;
    private readonly SynchronizationContext? _uiContext;
    private readonly NativeMethods.LowLevelMouseProc _mouseCallback;
    private readonly NativeMethods.LowLevelKeyboardProc _keyboardCallback;
    private readonly object _movementLock = new();
    private nint _mouseHook;
    private nint _keyboardHook;
    private string? _targetPeerId;
    private TransferEdge _exitEdge = TransferEdge.Left;
    private bool _enabled;
    private bool _remoteActive;
    private bool _cursorHidden;
    private int _anchorX;
    private int _anchorY;
    private int _returnY;
    private Point _lastLocalPoint;
    private double _distanceFromRight;
    private double _returnOvershoot;
    private double _pendingDx;
    private double _pendingDy;
    private Timer? _movementTimer;
    private Timer? _heartbeatTimer;
    private long _lastHeartbeatAcknowledgementTicks;

    public WindowsMouseSharingController(SecureMouseSender sender)
    {
        _sender = sender;
        _uiContext = SynchronizationContext.Current;
        _mouseCallback = MouseHookCallback;
        _keyboardCallback = KeyboardHookCallback;
    }

    public void Configure(bool enabled, string? targetPeerId, TransferEdge exitEdge = TransferEdge.Left)
    {
        _enabled = enabled;
        _targetPeerId = targetPeerId;
        _exitEdge = exitEdge;
        if (enabled && targetPeerId is not null) InstallHook();
        else
        {
            DeactivateRemote();
            RemoveHook();
        }
    }

    private void InstallHook()
    {
        if (_mouseHook != 0) return;
        _mouseHook = NativeMethods.SetWindowsHookExMouse(
            WhMouseLl,
            _mouseCallback,
            NativeMethods.GetModuleHandle(null),
            0
        );
        _keyboardHook = NativeMethods.SetWindowsHookExKeyboard(
            WhKeyboardLl,
            _keyboardCallback,
            NativeMethods.GetModuleHandle(null),
            0
        );
    }

    private void RemoveHook()
    {
        if (_mouseHook != 0) _ = NativeMethods.UnhookWindowsHookEx(_mouseHook);
        if (_keyboardHook != 0) _ = NativeMethods.UnhookWindowsHookEx(_keyboardHook);
        _mouseHook = _keyboardHook = 0;
    }

    private nint MouseHookCallback(int code, nint message, nint data)
    {
        if (code < 0 || !_enabled || _targetPeerId is null)
            return NativeMethods.CallNextHookEx(_mouseHook, code, message, data);
        try
        {
            var hookData = Marshal.PtrToStructure<MouseHookData>(data);
            if ((hookData.Flags & LlmhfInjected) != 0)
                return NativeMethods.CallNextHookEx(_mouseHook, code, message, data);

            var messageCode = unchecked((int)message);
            if (!_remoteActive)
            {
                if (messageCode == WmMouseMove)
                {
                    var movingTowardExit = _exitEdge == TransferEdge.Left
                        ? hookData.Point.X < _lastLocalPoint.X
                        : hookData.Point.X > _lastLocalPoint.X;
                    _lastLocalPoint = hookData.Point;
                    var width = Math.Max(1, NativeMethods.GetSystemMetrics(0));
                    var reachedExit = _exitEdge == TransferEdge.Left
                        ? hookData.Point.X <= 1
                        : hookData.Point.X >= width - 2;
                    if (reachedExit && movingTowardExit)
                    {
                        ActivateRemote(hookData.Point);
                        return 1;
                    }
                }
                return NativeMethods.CallNextHookEx(_mouseHook, code, message, data);
            }

            switch (messageCode)
            {
                case WmMouseMove:
                    HandleMovement(hookData.Point);
                    break;
                case WmLeftButtonDown:
                    FlushMovement();
                    _sender.SendReliable(new RemoteMouseEvent("down", Button: 0), _targetPeerId);
                    break;
                case WmLeftButtonUp:
                    FlushMovement();
                    _sender.SendReliable(new RemoteMouseEvent("up", Button: 0), _targetPeerId);
                    break;
                case WmRightButtonDown:
                    FlushMovement();
                    _sender.SendReliable(new RemoteMouseEvent("down", Button: 1), _targetPeerId);
                    break;
                case WmRightButtonUp:
                    FlushMovement();
                    _sender.SendReliable(new RemoteMouseEvent("up", Button: 1), _targetPeerId);
                    break;
                case WmMiddleButtonDown:
                    FlushMovement();
                    _sender.SendReliable(new RemoteMouseEvent("down", Button: 2), _targetPeerId);
                    break;
                case WmMiddleButtonUp:
                    FlushMovement();
                    _sender.SendReliable(new RemoteMouseEvent("up", Button: 2), _targetPeerId);
                    break;
                case WmMouseWheel:
                    FlushMovement();
                    var wheelDelta = unchecked((short)(hookData.MouseData >> 16));
                    _sender.Send(new RemoteMouseEvent("scroll", ScrollY: wheelDelta / 120.0), _targetPeerId);
                    break;
            }
            return 1;
        }
        catch
        {
            DeactivateRemote();
            return NativeMethods.CallNextHookEx(_mouseHook, code, message, data);
        }
    }

    private nint KeyboardHookCallback(int code, nint message, nint data)
    {
        if (code >= 0 && _remoteActive)
        {
            var messageCode = unchecked((int)message);
            if (messageCode is WmKeyDown or WmSysKeyDown)
            {
                var hookData = Marshal.PtrToStructure<KeyboardHookData>(data);
                if ((hookData.Flags & LlkHfInjected) == 0 && hookData.VirtualKeyCode == VkEscape)
                {
                    DeactivateRemote();
                    return 1;
                }
            }
        }
        return NativeMethods.CallNextHookEx(_keyboardHook, code, message, data);
    }

    public void ReturnFromRemote(string peerId)
    {
        if (_remoteActive && _targetPeerId == peerId) DeactivateRemote();
    }

    public void AcknowledgeHeartbeat(string peerId)
    {
        if (_remoteActive && _targetPeerId == peerId)
            Interlocked.Exchange(ref _lastHeartbeatAcknowledgementTicks, DateTime.UtcNow.Ticks);
    }

    private void ActivateRemote(Point point)
    {
        if (_targetPeerId is null) return;
        _remoteActive = true;
        Interlocked.Exchange(ref _lastHeartbeatAcknowledgementTicks, DateTime.UtcNow.Ticks);
        _returnY = point.Y;
        _distanceFromRight = 8;
        _returnOvershoot = 0;
        _anchorX = Math.Max(1, NativeMethods.GetSystemMetrics(0) / 2);
        _anchorY = Math.Max(1, NativeMethods.GetSystemMetrics(1) / 2);
        HideCursor();
        _ = NativeMethods.SetCursorPos(_anchorX, _anchorY);
        var height = Math.Max(1, NativeMethods.GetSystemMetrics(1));
        var normalizedY = Math.Clamp(point.Y / (double)Math.Max(1, height - 1), 0, 1);
        var entryEdge = _exitEdge == TransferEdge.Left ? "right" : "left";
        _sender.Send(new RemoteMouseEvent("enter", NormalizedY: normalizedY, Edge: entryEdge), _targetPeerId);
        _movementTimer = new Timer(_ => FlushMovement(), null, 8, 8);
        _heartbeatTimer = new Timer(
            _ =>
            {
                if (_remoteActive && _targetPeerId is not null)
                {
                    var lastAck = new DateTime(
                        Interlocked.Read(ref _lastHeartbeatAcknowledgementTicks),
                        DateTimeKind.Utc
                    );
                    if (DateTime.UtcNow - lastAck > TimeSpan.FromMilliseconds(500))
                    {
                        _uiContext?.Post(_ => DeactivateRemote(), null);
                        return;
                    }
                    _sender.Send(new RemoteMouseEvent("heartbeat"), _targetPeerId);
                }
            },
            null,
            100,
            100
        );
    }

    private void HandleMovement(Point point)
    {
        var dx = (point.X - _anchorX) * Sensitivity;
        var dy = (point.Y - _anchorY) * Sensitivity;
        _ = NativeMethods.SetCursorPos(_anchorX, _anchorY);
        var movementTowardReturn = _exitEdge == TransferEdge.Left ? dx > 0 : dx < 0;
        var returnDelta = _exitEdge == TransferEdge.Left ? dx : -dx;
        if (movementTowardReturn)
        {
            var proposed = _distanceFromRight - returnDelta;
            if (proposed <= 0)
            {
                _distanceFromRight = 0;
                _returnOvershoot += Math.Abs(dx);
                if (_returnOvershoot >= ReturnResistance)
                {
                    DeactivateRemote();
                    return;
                }
            }
            else _distanceFromRight = proposed;
        }
        else
        {
            _distanceFromRight = Math.Min(10_000, _distanceFromRight + Math.Abs(dx));
            _returnOvershoot = 0;
        }
        lock (_movementLock)
        {
            _pendingDx += dx;
            _pendingDy += dy;
        }
    }

    private void FlushMovement()
    {
        if (!_remoteActive || _targetPeerId is null) return;
        double dx;
        double dy;
        lock (_movementLock)
        {
            dx = _pendingDx;
            dy = _pendingDy;
            _pendingDx = _pendingDy = 0;
        }
        if (dx != 0 || dy != 0)
            _sender.Send(new RemoteMouseEvent("move", Dx: dx, Dy: dy), _targetPeerId);
    }

    private void DeactivateRemote()
    {
        if (!_remoteActive) return;
        FlushMovement();
        _remoteActive = false;
        _movementTimer?.Dispose();
        _heartbeatTimer?.Dispose();
        _movementTimer = _heartbeatTimer = null;
        lock (_movementLock) _pendingDx = _pendingDy = 0;
        if (_targetPeerId is not null)
            _sender.SendReliable(new RemoteMouseEvent("leave"), _targetPeerId);
        ShowCursor();
        var width = Math.Max(1, NativeMethods.GetSystemMetrics(0));
        var returnX = _exitEdge == TransferEdge.Left ? 4 : width - 5;
        _ = NativeMethods.SetCursorPos(returnX, _returnY);
    }

    private void HideCursor()
    {
        if (_cursorHidden) return;
        while (NativeMethods.ShowCursor(false) >= 0) { }
        _cursorHidden = true;
    }

    private void ShowCursor()
    {
        if (!_cursorHidden) return;
        while (NativeMethods.ShowCursor(true) < 0) { }
        _cursorHidden = false;
    }

    public void Dispose()
    {
        DeactivateRemote();
        RemoveHook();
    }

    [StructLayout(LayoutKind.Sequential)]
    private readonly struct Point { public readonly int X; public readonly int Y; }

    [StructLayout(LayoutKind.Sequential)]
    private readonly struct MouseHookData
    {
        public readonly Point Point;
        public readonly uint MouseData;
        public readonly uint Flags;
        public readonly uint Time;
        public readonly nuint ExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private readonly struct KeyboardHookData
    {
        public readonly uint VirtualKeyCode;
        public readonly uint ScanCode;
        public readonly uint Flags;
        public readonly uint Time;
        public readonly nuint ExtraInfo;
    }

    private static class NativeMethods
    {
        internal delegate nint LowLevelMouseProc(int code, nint message, nint data);
        internal delegate nint LowLevelKeyboardProc(int code, nint message, nint data);

        [DllImport("user32.dll", EntryPoint = "SetWindowsHookExW", SetLastError = true)]
        internal static extern nint SetWindowsHookExMouse(int hookId, LowLevelMouseProc callback, nint module, uint threadId);

        [DllImport("user32.dll", EntryPoint = "SetWindowsHookExW", SetLastError = true)]
        internal static extern nint SetWindowsHookExKeyboard(int hookId, LowLevelKeyboardProc callback, nint module, uint threadId);

        [DllImport("user32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool UnhookWindowsHookEx(nint hook);

        [DllImport("user32.dll")]
        internal static extern nint CallNextHookEx(nint hook, int code, nint message, nint data);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool SetCursorPos(int x, int y);

        [DllImport("user32.dll")]
        internal static extern int GetSystemMetrics(int index);

        [DllImport("user32.dll")]
        internal static extern int ShowCursor([MarshalAs(UnmanagedType.Bool)] bool show);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
        internal static extern nint GetModuleHandle(string? moduleName);
    }
}
