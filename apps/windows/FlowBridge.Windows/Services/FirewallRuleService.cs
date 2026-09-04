using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Text;

namespace FlowBridge.Windows.Services;

public static class FirewallRuleService
{
    private const string DiscoveryRule = "FlowBridge Local Discovery";

    private static string MarkerPath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "FlowBridge",
        "firewall-v3.configured"
    );

    public static bool IsConfigured
    {
        get
        {
            try
            {
                var executable = Environment.ProcessPath;
                return !string.IsNullOrWhiteSpace(executable)
                    && File.Exists(MarkerPath)
                    && string.Equals(
                        File.ReadAllText(MarkerPath, Encoding.UTF8).Trim(),
                        executable,
                        StringComparison.OrdinalIgnoreCase
                    );
            }
            catch (IOException)
            {
                return false;
            }
            catch (UnauthorizedAccessException)
            {
                return false;
            }
        }
    }

    public static async Task<bool> ConfigureAsync()
    {
        var executable = Environment.ProcessPath;
        if (string.IsNullOrWhiteSpace(executable)) return false;

        var escapedExecutable = executable.Replace("'", "''", StringComparison.Ordinal);
        var script = string.Join(
            "; ",
            $"Get-NetFirewallRule -DisplayName '{DiscoveryRule}' -ErrorAction SilentlyContinue | Remove-NetFirewallRule",
            "Get-NetFirewallRule -DisplayName 'FlowBridge Secure Transport' -ErrorAction SilentlyContinue | Remove-NetFirewallRule",
            $"New-NetFirewallRule -DisplayName '{DiscoveryRule}' -Direction Inbound -Action Allow -Program '{escapedExecutable}' -Protocol UDP -LocalPort 5353,45874,45875 -Profile Private | Out-Null"
        );
        var encoded = Convert.ToBase64String(Encoding.Unicode.GetBytes(script));
        var startInfo = new ProcessStartInfo
        {
            FileName = "powershell.exe",
            Arguments = $"-NoProfile -NonInteractive -EncodedCommand {encoded}",
            UseShellExecute = true,
            Verb = "runas",
            WindowStyle = ProcessWindowStyle.Hidden,
        };

        try
        {
            using var process = Process.Start(startInfo);
            if (process is null) return false;
            await process.WaitForExitAsync();
            if (process.ExitCode != 0) return false;

            var directory = Path.GetDirectoryName(MarkerPath);
            if (directory is not null) Directory.CreateDirectory(directory);
            await File.WriteAllTextAsync(MarkerPath, executable, Encoding.UTF8);
            return true;
        }
        catch (Win32Exception error) when (error.NativeErrorCode == 1223)
        {
            return false;
        }
        catch (IOException)
        {
            return false;
        }
    }
}
