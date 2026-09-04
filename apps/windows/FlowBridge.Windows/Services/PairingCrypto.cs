using System.Security.Cryptography;
using System.Text;

namespace FlowBridge.Windows.Services;

public sealed class PairingKeyExchange : IDisposable
{
    private readonly ECDiffieHellman _agreement;

    private PairingKeyExchange(ECDiffieHellman agreement, string publicKey)
    {
        _agreement = agreement;
        PublicKey = publicKey;
    }

    public string PublicKey { get; }

    public static PairingKeyExchange Create()
    {
        var agreement = ECDiffieHellman.Create(ECCurve.NamedCurves.nistP256);
        var parameters = agreement.ExportParameters(false);
        var point = new byte[65];
        point[0] = 0x04;
        parameters.Q.X!.CopyTo(point, 1);
        parameters.Q.Y!.CopyTo(point, 33);
        return new PairingKeyExchange(agreement, Convert.ToBase64String(point));
    }

    public byte[] DerivePeerKey(string remotePublicKey, string localId, string remoteId)
    {
        var point = Convert.FromBase64String(remotePublicKey);
        if (point.Length != 65 || point[0] != 0x04)
            throw new CryptographicException("Invalid P-256 public key.");

        var remoteParameters = new ECParameters
        {
            Curve = ECCurve.NamedCurves.nistP256,
            Q = new ECPoint
            {
                X = point[1..33],
                Y = point[33..65],
            },
        };
        using var remote = ECDiffieHellman.Create(remoteParameters);
        var sharedSecret = _agreement.DeriveRawSecretAgreement(remote.PublicKey);
        var transcript = Encoding.UTF8.GetBytes(
            "FlowBridge/pairing/v1|" + string.Join('|', new[] { localId, remoteId }.Order())
        );
        var material = new byte[sharedSecret.Length + transcript.Length];
        sharedSecret.CopyTo(material, 0);
        transcript.CopyTo(material, sharedSecret.Length);
        CryptographicOperations.ZeroMemory(sharedSecret);
        var key = SHA256.HashData(material);
        CryptographicOperations.ZeroMemory(material);
        return key;
    }

    public static string VerificationCode(ReadOnlySpan<byte> peerKey)
    {
        var digest = SHA256.HashData(peerKey);
        var value = ((uint)digest[0] << 24 | (uint)digest[1] << 16 | (uint)digest[2] << 8 | digest[3])
            % 1_000_000;
        return value.ToString("D6");
    }

    public void Dispose() => _agreement.Dispose();
}

public static class ControlAuthentication
{
    public static string Create(
        string type,
        string fromId,
        string toId,
        string? requestId,
        ReadOnlySpan<byte> key
    )
    {
        var message = Encoding.UTF8.GetBytes(
            $"FlowBridge/control/v3|{type}|{fromId}|{toId}|{requestId ?? string.Empty}"
        );
        using var hmac = new HMACSHA256(key.ToArray());
        return Convert.ToBase64String(hmac.ComputeHash(message));
    }

    public static bool Verify(
        string? authentication,
        string type,
        string fromId,
        string toId,
        string? requestId,
        ReadOnlySpan<byte> key
    )
    {
        if (authentication is null) return false;
        byte[] received;
        try { received = Convert.FromBase64String(authentication); }
        catch (FormatException) { return false; }
        var expected = Convert.FromBase64String(Create(type, fromId, toId, requestId, key));
        return CryptographicOperations.FixedTimeEquals(received, expected);
    }
}
