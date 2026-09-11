using System.Text.Json;

namespace RemoteJARVIS.Protocol;

public sealed record ProtocolEnvelope(
    int ProtocolVersion,
    Guid MessageId,
    Guid SessionId,
    long Sequence,
    DateTimeOffset Timestamp,
    string Type,
    Guid? RequestId,
    Guid? CorrelationId,
    JsonElement Payload);
