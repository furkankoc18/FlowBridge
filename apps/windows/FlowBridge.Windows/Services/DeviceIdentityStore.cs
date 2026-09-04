using System.IO;
using System.Security.Cryptography;
using System.Text;

namespace FlowBridge.Windows.Services;

public static class DeviceIdentityStore
{
    private static readonly byte[] Entropy = Encoding.UTF8.GetBytes("FlowBridge/device-identity/v1");

    public static string LoadOrCreate()
    {
        var directory = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "FlowBridge"
        );
        var path = Path.Combine(directory, "device.identity");

        try
        {
            if (File.Exists(path))
            {
                var protectedBytes = File.ReadAllBytes(path);
                var clearBytes = ProtectedData.Unprotect(
                    protectedBytes,
                    Entropy,
                    DataProtectionScope.CurrentUser
                );
                var existing = Encoding.UTF8.GetString(clearBytes);
                if (existing.Length == 32) return existing;
            }

            Directory.CreateDirectory(directory);
            var identifier = Convert.ToHexString(RandomNumberGenerator.GetBytes(16)).ToLowerInvariant();
            var encrypted = ProtectedData.Protect(
                Encoding.UTF8.GetBytes(identifier),
                Entropy,
                DataProtectionScope.CurrentUser
            );
            File.WriteAllBytes(path, encrypted);
            return identifier;
        }
        catch (CryptographicException)
        {
            return Guid.NewGuid().ToString("N");
        }
        catch (IOException)
        {
            return Guid.NewGuid().ToString("N");
        }
    }
}
