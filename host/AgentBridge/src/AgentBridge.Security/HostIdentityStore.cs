using System.Net;
using System.Runtime.Versioning;
using System.Security.AccessControl;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Security.Principal;
using System.Text.Json;

namespace RemoteJARVIS.Security;

public sealed record HostIdentity(Guid HostId, X509Certificate2 Certificate, string Fingerprint) : IDisposable
{
    public void Dispose() => Certificate.Dispose();
}

/// <summary>Windows-only durable identity. Only the public certificate is stored in JSON.</summary>
[SupportedOSPlatform("windows")]
public static class HostIdentityStore
{
    private sealed record StoredIdentity(int Version, Guid HostId, string KeyName, string Certificate);

    public static HostIdentity LoadOrCreate(string directory, DateTimeOffset now)
    {
        directory = SecureDirectory(directory);
        string metadataPath = Path.Combine(directory, "host.json");
        // An exclusive file handle prevents two processes from creating different identities.
        using var gate = new FileStream(Path.Combine(directory, "identity.lock"), FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
        StoredIdentity record;
        X509Certificate2 certificate;
        if (File.Exists(metadataPath))
        {
            RejectReparsePoint(metadataPath);
            record = JsonSerializer.Deserialize<StoredIdentity>(File.ReadAllBytes(metadataPath))
                ?? throw new InvalidDataException("Host identity metadata is invalid.");
            if (record.Version != 1 || record.HostId == Guid.Empty || record.KeyName != $"RemoteJARVIS.Host.{record.HostId:N}")
                throw new InvalidDataException("Host identity metadata is invalid.");
            if (!CngKey.Exists(record.KeyName, CngProvider.MicrosoftSoftwareKeyStorageProvider))
                throw new CryptographicException("The trusted host key is missing. Explicit recovery is required.");
            using var key = CngKey.Open(record.KeyName, CngProvider.MicrosoftSoftwareKeyStorageProvider);
            if (key.ExportPolicy != CngExportPolicies.None)
                throw new CryptographicException("Host key export policy is invalid.");
            using var signer = new ECDsaCng(key);
            using var publicCertificate = X509CertificateLoader.LoadCertificate(Convert.FromBase64String(record.Certificate));
            certificate = publicCertificate.CopyWithPrivateKey(signer); // also verifies public/private correspondence
            if (certificate.NotAfter.ToUniversalTime() <= now.AddDays(30).UtcDateTime)
            {
                certificate.Dispose();
                certificate = IssueLocalCertificate(signer, record.HostId, now);
                record = record with { Certificate = Convert.ToBase64String(certificate.RawData) };
                AtomicWrite(metadataPath, JsonSerializer.SerializeToUtf8Bytes(record));
            }
        }
        else
        {
            Guid hostId = Guid.NewGuid();
            string keyName = $"RemoteJARVIS.Host.{hostId:N}";
            using var key = CngKey.Create(CngAlgorithm.ECDsaP256, keyName, new CngKeyCreationParameters
            {
                Provider = CngProvider.MicrosoftSoftwareKeyStorageProvider,
                ExportPolicy = CngExportPolicies.None,
                KeyUsage = CngKeyUsages.Signing
            });
            using var signer = new ECDsaCng(key);
            certificate = IssueLocalCertificate(signer, hostId, now);
            record = new(1, hostId, keyName, Convert.ToBase64String(certificate.RawData));
            try { AtomicWrite(metadataPath, JsonSerializer.SerializeToUtf8Bytes(record)); }
            catch { certificate.Dispose(); key.Delete(); throw; }
        }
        using var publicKey = certificate.GetECDsaPublicKey() ?? throw new CryptographicException("Unexpected host key type.");
        string fingerprint = Convert.ToHexStringLower(SHA256.HashData(publicKey.ExportSubjectPublicKeyInfo()));
        return new(record.HostId, certificate, fingerprint);
    }

    private static X509Certificate2 IssueLocalCertificate(ECDsa signer, Guid hostId, DateTimeOffset now)
    {
        var request = new CertificateRequest($"CN=RemoteJARVIS-{hostId:N}", signer, HashAlgorithmName.SHA256);
        request.CertificateExtensions.Add(new X509BasicConstraintsExtension(false, false, 0, true));
        request.CertificateExtensions.Add(new X509KeyUsageExtension(X509KeyUsageFlags.DigitalSignature, true));
        request.CertificateExtensions.Add(new X509EnhancedKeyUsageExtension(new OidCollection { new("1.3.6.1.5.5.7.3.1") }, true));
        var names = new SubjectAlternativeNameBuilder();
        names.AddDnsName("localhost");
        names.AddIpAddress(IPAddress.Loopback);
        request.CertificateExtensions.Add(names.Build());
        return request.CreateSelfSigned(now.AddMinutes(-5), now.AddDays(397));
    }

    public static string SecureDirectory(string path)
    {
        path = Path.GetFullPath(path);
        for (DirectoryInfo? ancestor = new(path); ancestor is not null; ancestor = ancestor.Parent)
            if (ancestor.Exists && (ancestor.Attributes & FileAttributes.ReparsePoint) != 0)
                throw new IOException("Security storage cannot use a reparse point.");
        Directory.CreateDirectory(path);
        using var user = WindowsIdentity.GetCurrent();
        var sid = user.User ?? throw new InvalidOperationException("No Windows identity.");
        var acl = new DirectorySecurity();
        acl.SetOwner(sid);
        acl.SetAccessRuleProtection(true, false);
        const InheritanceFlags inheritance = InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit;
        acl.AddAccessRule(new FileSystemAccessRule(sid, FileSystemRights.FullControl, inheritance, PropagationFlags.None, AccessControlType.Allow));
        acl.AddAccessRule(new FileSystemAccessRule(new SecurityIdentifier(WellKnownSidType.LocalSystemSid, null), FileSystemRights.FullControl, inheritance, PropagationFlags.None, AccessControlType.Allow));
        new DirectoryInfo(path).SetAccessControl(acl);
        return path;
    }

    internal static void RejectReparsePoint(string path)
    {
        if (File.Exists(path) && (File.GetAttributes(path) & FileAttributes.ReparsePoint) != 0)
            throw new IOException("Security files cannot be reparse points.");
    }

    internal static void AtomicWrite(string path, byte[] bytes)
    {
        RejectReparsePoint(path);
        string temporary = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            using (var file = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None, 4096, FileOptions.WriteThrough))
            {
                file.Write(bytes);
                file.Flush(true);
            }
            File.Move(temporary, path, true);
        }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }
}
