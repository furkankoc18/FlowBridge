namespace FlowBridge.Windows.Services;

public enum TransferEdge
{
    Left,
    Right,
}

public static class TransferPolicy
{
    public static TransferEdge ExitEdge(
        string localId,
        string localPlatform,
        string peerId,
        string peerPlatform
    )
    {
        var localIsMac = localPlatform.Contains("mac", StringComparison.OrdinalIgnoreCase);
        var peerIsMac = peerPlatform.Contains("mac", StringComparison.OrdinalIgnoreCase);
        var localIsWindows = localPlatform.Contains("windows", StringComparison.OrdinalIgnoreCase);
        var peerIsWindows = peerPlatform.Contains("windows", StringComparison.OrdinalIgnoreCase);
        if (localIsMac && peerIsWindows) return TransferEdge.Right;
        if (localIsWindows && peerIsMac) return TransferEdge.Left;
        return string.CompareOrdinal(localId, peerId) < 0 ? TransferEdge.Right : TransferEdge.Left;
    }
}
