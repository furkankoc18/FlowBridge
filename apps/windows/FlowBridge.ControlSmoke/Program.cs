using FlowBridge.Windows.Services;

var firstPairingCompleted = new TaskCompletionSource<string>(
    TaskCreationOptions.RunContinuationsAsynchronously
);
var reversePairingCompleted = new TaskCompletionSource<string>(
    TaskCreationOptions.RunContinuationsAsynchronously
);
const string MacId = "22222222222222222222222222222222";
const string WindowsId = "11111111111111111111111111111111";
const string FirstRequestId = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
const string ReverseRequestId = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
PairingKeyExchange? exchange = null;
PairingKeyExchange? reverseExchange = null;
byte[]? peerKey = null;
byte[]? reversePeerKey = null;
using var service = new PeerControlService(
    WindowsId,
    "Windows-Control-Smoke"
);
service.PairRequestReceived += async (_, envelope) =>
{
    if (envelope.FromId != MacId || envelope.RequestId != FirstRequestId || envelope.PublicKey is null) return;
    try
    {
        exchange = PairingKeyExchange.Create();
        peerKey = exchange.DerivePeerKey(
            envelope.PublicKey,
            WindowsId,
            MacId
        );
        await service.SendPairChallengeAsync(MacId, envelope.RequestId, exchange.PublicKey);
    }
    catch (Exception error)
    {
        Console.WriteLine(error);
    }
};
service.PairChallengeReceived += async (_, envelope) =>
{
    if (envelope.FromId != MacId
        || envelope.RequestId != ReverseRequestId
        || envelope.PublicKey is null
        || reverseExchange is null) return;
    reversePeerKey = reverseExchange.DerivePeerKey(
        envelope.PublicKey,
        "11111111111111111111111111111111",
        MacId
    );
    var authentication = ControlAuthentication.Create(
        ControlMessageType.PairAccepted,
        WindowsId,
        MacId,
        ReverseRequestId,
        reversePeerKey
    );
    await service.SendPairAcceptedAsync(MacId, ReverseRequestId, authentication);
};
service.PairAcceptedReceived += (_, envelope) =>
{
    if (envelope.FromId != MacId) return;
    if (envelope.RequestId == FirstRequestId && peerKey is not null)
    {
        var authentication = ControlAuthentication.Create(
            ControlMessageType.PairAccepted,
            WindowsId,
            MacId,
            FirstRequestId,
            peerKey
        );
        _ = service.SendPairAcceptedAsync(MacId, FirstRequestId, authentication);
        firstPairingCompleted.TrySetResult(PairingKeyExchange.VerificationCode(peerKey));
    }
    else if (envelope.RequestId == ReverseRequestId && reversePeerKey is not null)
    {
        reversePairingCompleted.TrySetResult(PairingKeyExchange.VerificationCode(reversePeerKey));
    }
};
service.Start();

var completed = await Task.WhenAny(firstPairingCompleted.Task, Task.Delay(TimeSpan.FromSeconds(8)));
if (completed != firstPairingCompleted.Task)
    throw new InvalidOperationException("Mac initiated pairing timed out.");
Console.WriteLine($"Mac initiated pairing passed: {await firstPairingCompleted.Task}");

reverseExchange = PairingKeyExchange.Create();
await service.SendPairRequestAsync(MacId, ReverseRequestId, reverseExchange.PublicKey);
completed = await Task.WhenAny(reversePairingCompleted.Task, Task.Delay(TimeSpan.FromSeconds(8)));
if (completed != reversePairingCompleted.Task)
    throw new InvalidOperationException("Windows initiated pairing timed out.");
Console.WriteLine($"Windows initiated pairing passed: {await reversePairingCompleted.Task}");
exchange?.Dispose();
reverseExchange.Dispose();
