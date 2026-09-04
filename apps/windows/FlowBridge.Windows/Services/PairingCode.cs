using System.Security.Cryptography;
using System.Text;

namespace FlowBridge.Windows.Services;

public static class PairingCode
{
    public static string Create(string localId, string remoteId)
    {
        var ids = new[] { localId, remoteId };
        Array.Sort(ids, StringComparer.Ordinal);
        var transcript = Encoding.UTF8.GetBytes(string.Join('|', ids));
        var digest = SHA256.HashData(transcript);
        var value = ((uint)digest[0] << 24)
            | ((uint)digest[1] << 16)
            | ((uint)digest[2] << 8)
            | digest[3];
        return (value % 1_000_000).ToString("D6", System.Globalization.CultureInfo.InvariantCulture);
    }
}
