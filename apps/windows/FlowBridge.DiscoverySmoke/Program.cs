using Makaretu.Dns;
using FlowBridge.Windows.Services;

const string smokeId = "11111111111111111111111111111111";
var service = new ServiceDiscovery();
var foundRemote = 0;
service.ServiceInstanceDiscovered += (_, args) =>
{
    if (!ServiceName.TryParse(args.ServiceInstanceName.ToString(), out var identity)) return;
    if (identity.Id == smokeId) return;
    Console.WriteLine($"FLOWBRIDGE_REMOTE_FOUND={identity.Name}");
    Interlocked.Exchange(ref foundRemote, 1);
};
var profile = new ServiceProfile(
    $"FB-{smokeId}-Windows-Smoke",
    "_flowbridge._tcp",
    45873,
    null
);
profile.AddProperty("version", "1");
profile.AddProperty("platform", "windows");

service.Mdns.Start();
service.Advertise(profile);
service.Announce(profile);
service.QueryServiceInstances("_flowbridge._tcp");
Console.WriteLine("FLOWBRIDGE_DISCOVERY_SMOKE_READY");
await Task.Delay(TimeSpan.FromSeconds(6));
if (Volatile.Read(ref foundRemote) == 0)
    throw new InvalidOperationException("The .NET DNS-SD client did not discover the running Mac app.");
service.Unadvertise(profile);
service.Dispose();
