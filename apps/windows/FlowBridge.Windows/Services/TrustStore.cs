using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace FlowBridge.Windows.Services;

public sealed class TrustStore
{
    private static readonly byte[] Entropy = Encoding.UTF8.GetBytes("FlowBridge/trusted-peers/v1");
    private readonly string _path;

    public TrustStore()
    {
        var directory = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "FlowBridge"
        );
        Directory.CreateDirectory(directory);
        _path = Path.Combine(directory, "trusted-peers.dat");
    }

    public HashSet<string> Load()
    {
        try
        {
            if (!File.Exists(_path)) return [];
            var clearBytes = ProtectedData.Unprotect(
                File.ReadAllBytes(_path),
                Entropy,
                DataProtectionScope.CurrentUser
            );
            return JsonSerializer.Deserialize<HashSet<string>>(clearBytes) ?? [];
        }
        catch (CryptographicException)
        {
            return [];
        }
        catch (IOException)
        {
            return [];
        }
        catch (JsonException)
        {
            return [];
        }
    }

    public void Save(IEnumerable<string> peerIds)
    {
        var serialized = JsonSerializer.SerializeToUtf8Bytes(peerIds.Order(StringComparer.Ordinal));
        var encrypted = ProtectedData.Protect(
            serialized,
            Entropy,
            DataProtectionScope.CurrentUser
        );
        File.WriteAllBytes(_path, encrypted);
    }
}
