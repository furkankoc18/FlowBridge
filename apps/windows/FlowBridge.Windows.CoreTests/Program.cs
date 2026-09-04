using FlowBridge.Windows.Services;
using System.Security.Cryptography;
using System.Text;

static void Require(bool condition, string message)
{
    if (!condition) throw new InvalidOperationException(message);
}

Require(
    PairingCode.Create("device-a", "device-b") == PairingCode.Create("device-b", "device-a"),
    "Pairing code must be independent of device order."
);
Require(
    PairingCode.Create("device-a", "device-b") != PairingCode.Create("device-a", "attacker"),
    "A changed device identity must change the code."
);
Require(PairingCode.Create("left", "right").Length == 6, "Pairing code must have six digits.");
Require(
    PairingCode.Create("left", "right") == "616188",
    "Pairing code must match the cross-platform test vector."
);

var id = "0123456789abcdef0123456789abcdef";
var instance = ServiceName.Create(id, "Windows-PC");
Require(
    ServiceName.TryParse($"{instance}._flowbridge._tcp.local.", out var parsed),
    "Service name should parse."
);
Require(parsed.Id == id && parsed.Name == "Windows-PC", "Parsed identity should round-trip.");
Require(
    ServiceName.TryParse(
        $@"FB-{id}-Furkan\032MacBook\032Pro._flowbridge._tcp.local.",
        out var escapedName
    ) && escapedName.Name == "Furkan MacBook Pro",
    "Escaped DNS labels should be decoded for display."
);
Require(
    !ServiceName.TryParse("malicious._flowbridge._tcp.local.", out _),
    "Malformed service names must be rejected."
);
Require(
    TransferPolicy.ExitEdge("a", "macOS", "b", "windows") == TransferEdge.Right,
    "Mac to Windows must use the established right edge."
);
Require(
    TransferPolicy.ExitEdge("b", "windows", "a", "macOS") == TransferEdge.Left,
    "Windows to Mac must use the established left edge."
);
Require(
    TransferPolicy.ExitEdge("a", "windows", "b", "windows") == TransferEdge.Right
        && TransferPolicy.ExitEdge("b", "windows", "a", "windows") == TransferEdge.Left,
    "Same-platform peers must use complementary edges."
);
Require(
    ControlAuthentication.Create(
        "pairAccepted",
        id,
        "fedcba9876543210fedcba9876543210",
        "request-1",
        Enumerable.Range(0, 32).Select(value => (byte)value).ToArray()
    ) == "e/3bi7qNcEhHaSkjOCvrheMqqSUQj7n48WG3PNi/nc8=",
    "Control HMAC must match the cross-platform test vector."
);
var mouseKey = Enumerable.Range(0, 32).Select(value => (byte)value).ToArray();
var mouseNonce = Enumerable.Range(0, 12).Select(value => (byte)value).ToArray();
var mousePlaintext = Encoding.UTF8.GetBytes("{\"kind\":\"move\",\"dx\":1.5}");
var mouseAad = Encoding.UTF8.GetBytes(
    $"FlowBridge/mouse/v2|{id}|fedcba9876543210fedcba9876543210|00112233445566778899aabbccddeeff|42"
);
var mouseCiphertext = new byte[mousePlaintext.Length];
var mouseTag = new byte[16];
using (var aes = new AesGcm(mouseKey, 16))
    aes.Encrypt(mouseNonce, mousePlaintext, mouseCiphertext, mouseTag, mouseAad);
var mouseCombined = mouseNonce.Concat(mouseCiphertext).Concat(mouseTag).ToArray();
Require(
    Convert.ToBase64String(mouseCombined)
        == "AAECAwQFBgcICQoLPCC9cquB4CGvLPj91MtUT+eupQ7BVWoB0Oyoc05zVjS18kbdos1bPA==",
    "Mouse AES-GCM envelope must match the cross-platform test vector."
);

using (var left = PairingKeyExchange.Create())
using (var right = PairingKeyExchange.Create())
{
    var leftKey = left.DerivePeerKey(right.PublicKey, id, "fedcba9876543210fedcba9876543210");
    var rightKey = right.DerivePeerKey(left.PublicKey, "fedcba9876543210fedcba9876543210", id);
    Require(leftKey.SequenceEqual(rightKey), "Both peers must derive the same pairing key.");
    Require(
        PairingKeyExchange.VerificationCode(leftKey) == PairingKeyExchange.VerificationCode(rightKey),
        "Both peers must show the same verification code."
    );
    var authentication = ControlAuthentication.Create(
        "pairAccepted",
        id,
        "fedcba9876543210fedcba9876543210",
        "request-1",
        leftKey
    );
    Require(
        ControlAuthentication.Verify(
            authentication,
            "pairAccepted",
            id,
            "fedcba9876543210fedcba9876543210",
            "request-1",
            rightKey
        ),
        "Authenticated control message must verify on the peer."
    );
    Require(
        !ControlAuthentication.Verify(
            authentication,
            "unpair",
            id,
            "fedcba9876543210fedcba9876543210",
            null,
            rightKey
        ),
        "Authentication must be bound to the control message."
    );
}

Console.WriteLine("Windows core tests passed.");
