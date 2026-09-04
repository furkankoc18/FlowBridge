using System.IO;
using System.Security.Cryptography;
using System.Text;

namespace FlowBridge.Windows.Services;

public sealed class PeerKeyStore
{
    private static readonly byte[] Entropy = Encoding.UTF8.GetBytes("FlowBridge/peer-key/v1");
    private readonly string _directory;

    public PeerKeyStore()
    {
        _directory = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "FlowBridge",
            "peer-keys"
        );
        Directory.CreateDirectory(_directory);
    }

    public bool Has(string peerId) => Load(peerId) is not null;

    public byte[]? Load(string peerId)
    {
        if (!IsValidPeerId(peerId)) return null;
        try
        {
            var path = Path.Combine(_directory, peerId + ".dat");
            if (!File.Exists(path)) return null;
            var key = ProtectedData.Unprotect(File.ReadAllBytes(path), Entropy, DataProtectionScope.CurrentUser);
            return key.Length == 32 ? key : null;
        }
        catch (CryptographicException) { return null; }
        catch (IOException) { return null; }
    }

    public void Save(string peerId, ReadOnlySpan<byte> key)
    {
        if (!IsValidPeerId(peerId) || key.Length != 32)
            throw new ArgumentException("Invalid peer key.");
        var encrypted = ProtectedData.Protect(key.ToArray(), Entropy, DataProtectionScope.CurrentUser);
        File.WriteAllBytes(Path.Combine(_directory, peerId + ".dat"), encrypted);
    }

    public void Remove(string peerId)
    {
        if (!IsValidPeerId(peerId)) return;
        try { File.Delete(Path.Combine(_directory, peerId + ".dat")); }
        catch (IOException) { }
    }

    private static bool IsValidPeerId(string peerId) =>
        peerId.Length == 32 && peerId.All(Uri.IsHexDigit);
}
