using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace RemoteJARVIS.Security;

public enum PermissionLevel { Observe, Chat, Operate, ModifyFiles, ExecuteCommands, Destructive }
public sealed record TrustedDevice(Guid DeviceId, string CertificateSha256, PermissionLevel MaximumPermission, DateTimeOffset CreatedAt, DateTimeOffset? RevokedAt);

/// <summary>No enrollment endpoint exists yet. Only a verified future pairing transaction may enroll.</summary>
public sealed class TrustRegistry
{
    private sealed record RegistryDocument(int Version, Guid HostId, List<TrustedDevice> Devices);
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow,
        AllowDuplicateProperties = false,
        MaxDepth = 8
    };
    private readonly object gate = new();
    private readonly Guid hostId;
    private readonly string? path;
    private List<TrustedDevice> devices;
    public event Action<Guid>? DeviceRevoked;

    public TrustRegistry(Guid hostId, string? path = null)
    {
        if (hostId == Guid.Empty) throw new ArgumentException("Host ID required.", nameof(hostId));
        this.hostId = hostId;
        this.path = path;
        devices = [];
        if (path is not null && File.Exists(path))
        {
            HostIdentityStore.RejectReparsePoint(path);
            if (new FileInfo(path).Length > 1024 * 1024) throw new InvalidDataException("Trust store is too large.");
            var document = JsonSerializer.Deserialize<RegistryDocument>(File.ReadAllBytes(path), JsonOptions)
                ?? throw new InvalidDataException("Invalid trust store.");
            if (document.Version != 1 || document.HostId != hostId || document.Devices is null || document.Devices.Count > 128)
                throw new InvalidDataException("Invalid trust store.");
            foreach (var device in document.Devices)
                if (device is null || device.DeviceId == Guid.Empty || !Enum.IsDefined(device.MaximumPermission) || !ValidHash(device.CertificateSha256))
                    throw new InvalidDataException("Invalid device record.");
            if (document.Devices.Select(d => d.DeviceId).Distinct().Count() != document.Devices.Count ||
                document.Devices.Select(d => d.CertificateSha256).Distinct(StringComparer.OrdinalIgnoreCase).Count() != document.Devices.Count)
                throw new InvalidDataException("Duplicate trusted identity.");
            devices = document.Devices;
        }
    }

    public TrustedDevice? Authenticate(X509Certificate2 certificate, DateTimeOffset now)
    {
        if (certificate.NotBefore.ToUniversalTime() > now.UtcDateTime || certificate.NotAfter.ToUniversalTime() <= now.UtcDateTime)
            return null;
        var usages = certificate.Extensions.OfType<X509EnhancedKeyUsageExtension>().ToArray();
        if (usages.Length != 1 || !usages[0].EnhancedKeyUsages.Cast<Oid>().Any(oid => oid.Value == "1.3.6.1.5.5.7.3.2"))
            return null;
        byte[] hash = SHA256.HashData(certificate.RawData);
        lock (gate)
            return devices.FirstOrDefault(device => device.RevokedAt is null && CryptographicOperations.FixedTimeEquals(Convert.FromHexString(device.CertificateSha256), hash));
    }

    public bool IsAuthorized(Guid deviceId, PermissionLevel required)
    {
        if (!Enum.IsDefined(required)) return false;
        lock (gate) return devices.Any(device => device.DeviceId == deviceId && device.RevokedAt is null && device.MaximumPermission >= required);
    }

    public bool Revoke(Guid deviceId, DateTimeOffset now)
    {
        lock (gate)
        {
            int index = devices.FindIndex(device => device.DeviceId == deviceId);
            if (index < 0 || devices[index].RevokedAt is not null) return false;
            var next = devices.ToList();
            next[index] = next[index] with { RevokedAt = now };
            Persist(next); // durable before changing the in-memory decision
            devices = next;
        }
        DeviceRevoked?.Invoke(deviceId);
        return true;
    }

    internal void EnrollVerifiedDevice(TrustedDevice device)
    {
        if (device.DeviceId == Guid.Empty || device.RevokedAt is not null || !ValidHash(device.CertificateSha256) || !Enum.IsDefined(device.MaximumPermission))
            throw new ArgumentException("Invalid device record.");
        lock (gate)
        {
            if (devices.Count >= 128 || devices.Any(d => d.DeviceId == device.DeviceId || string.Equals(d.CertificateSha256, device.CertificateSha256, StringComparison.OrdinalIgnoreCase)))
                throw new InvalidOperationException("Device already registered or trust registry full.");
            var next = devices.Append(device).ToList();
            Persist(next);
            devices = next;
        }
    }

    private void Persist(List<TrustedDevice> next)
    {
        if (path is not null)
            HostIdentityStore.AtomicWrite(path, JsonSerializer.SerializeToUtf8Bytes(new RegistryDocument(1, hostId, next), JsonOptions));
    }

    private static bool ValidHash(string? value) => value is { Length: 64 } && value.All(Uri.IsHexDigit);
}
