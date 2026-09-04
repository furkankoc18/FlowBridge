using System.Text;

namespace FlowBridge.Windows.Services;

public static class ServiceName
{
    private const string ServiceSuffix = "._flowbridge._tcp";

    public static string Create(string deviceId, string deviceName)
    {
        var safeName = deviceName.Replace('.', '-').Replace('|', '-');
        if (safeName.Length > 20) safeName = safeName[..20];
        return $"FB-{deviceId}-{safeName}";
    }

    public static bool TryParse(string fullyQualifiedName, out DiscoveredIdentity identity)
    {
        identity = default;
        var suffixIndex = fullyQualifiedName.IndexOf(ServiceSuffix, StringComparison.OrdinalIgnoreCase);
        var instance = suffixIndex >= 0
            ? fullyQualifiedName[..suffixIndex]
            : fullyQualifiedName;
        instance = instance.TrimEnd('.');
        var parts = instance.Split('-', 3, StringSplitOptions.None);
        if (parts.Length != 3 || parts[0] != "FB" || parts[1].Length != 32) return false;
        if (!parts[1].All(Uri.IsHexDigit)) return false;
        identity = new DiscoveredIdentity(parts[1].ToLowerInvariant(), DecodeDnsLabel(parts[2]));
        return true;
    }

    private static string DecodeDnsLabel(string value)
    {
        var decoded = new StringBuilder(value.Length);
        for (var index = 0; index < value.Length; index++)
        {
            if (value[index] != '\\' || index + 1 >= value.Length)
            {
                decoded.Append(value[index]);
                continue;
            }

            if (index + 3 < value.Length
                && char.IsAsciiDigit(value[index + 1])
                && char.IsAsciiDigit(value[index + 2])
                && char.IsAsciiDigit(value[index + 3]))
            {
                var numeric = ((value[index + 1] - '0') * 100)
                    + ((value[index + 2] - '0') * 10)
                    + (value[index + 3] - '0');
                if (numeric <= byte.MaxValue)
                {
                    decoded.Append((char)numeric);
                    index += 3;
                    continue;
                }
            }

            decoded.Append(value[++index]);
        }
        return decoded.ToString();
    }
}

public readonly record struct DiscoveredIdentity(string Id, string Name);
