using System.Globalization;
using System.Text.Json;

namespace RemoteJARVIS.Protocol;

public static class ProtocolCodec
{
    public const int MaximumFrameBytes = 65_536;

    private const int SupportedProtocolVersion = 1;
    private static readonly TimeSpan MaximumClockSkew = TimeSpan.FromMinutes(5);
    private static readonly HashSet<string> AllowedProperties = new(StringComparer.Ordinal)
    {
        "protocolVersion",
        "messageId",
        "sessionId",
        "sequence",
        "timestamp",
        "type",
        "requestId",
        "correlationId",
        "payload",
    };

    private static readonly string[] TimestampFormats =
    {
        "yyyy-MM-dd'T'HH:mm:ssK",
        "yyyy-MM-dd'T'HH:mm:ss.FFFFFFFK",
    };

    public static ProtocolEnvelope Parse(
        ReadOnlyMemory<byte> utf8,
        Guid expectedSessionId,
        long expectedSequence,
        DateTimeOffset now)
    {
        if (utf8.Length > MaximumFrameBytes)
        {
            throw InvalidRequest("Envelope exceeds the maximum frame size.");
        }

        if (expectedSessionId == Guid.Empty || expectedSequence <= 0)
        {
            throw InvalidRequest("Expected protocol state is invalid.");
        }

        JsonDocument document;
        try
        {
            document = JsonDocument.Parse(
                utf8,
                new JsonDocumentOptions
                {
                    AllowTrailingCommas = false,
                    CommentHandling = JsonCommentHandling.Disallow,
                    MaxDepth = 16,
                });
        }
        catch (JsonException)
        {
            throw InvalidRequest("Envelope is not valid JSON.");
        }

        using (document)
        {
            JsonElement root = document.RootElement;
            if (root.ValueKind != JsonValueKind.Object)
            {
                throw InvalidRequest("Envelope must be a JSON object.");
            }

            ValidateProperties(root);
            ValidateEnvelopeProperties(root);

            int protocolVersion = ReadInt32(root, "protocolVersion");
            if (protocolVersion != SupportedProtocolVersion)
            {
                throw ProtocolMismatch("Protocol version is not supported.");
            }

            Guid messageId = ReadRequiredGuid(root, "messageId");
            Guid sessionId = ReadRequiredGuid(root, "sessionId");
            long sequence = ReadInt64(root, "sequence");
            DateTimeOffset timestamp = ReadTimestamp(root);
            string type = ReadType(root);
            Guid? requestId = ReadOptionalGuid(root, "requestId");
            Guid? correlationId = ReadOptionalGuid(root, "correlationId");
            JsonElement payload = ReadPayload(root);

            if (sessionId != expectedSessionId)
            {
                throw SecurityViolation("Envelope session does not match the secure transport session.");
            }

            if (sequence <= 0 || sequence != expectedSequence)
            {
                throw SecurityViolation("Envelope sequence is invalid for the secure transport session.");
            }

            if (timestamp < now - MaximumClockSkew || timestamp > now + MaximumClockSkew)
            {
                throw SessionExpired("Envelope timestamp is outside the accepted session window.");
            }

            return new ProtocolEnvelope(
                protocolVersion,
                messageId,
                sessionId,
                sequence,
                timestamp,
                type,
                requestId,
                correlationId,
                payload.Clone());
        }
    }

    public static byte[] Serialize(ProtocolEnvelope envelope)
    {
        ArgumentNullException.ThrowIfNull(envelope);

        ValidateForSerialization(envelope);

        using var stream = new MemoryStream();
        using (var writer = new Utf8JsonWriter(stream, new JsonWriterOptions { Indented = false }))
        {
            writer.WriteStartObject();
            writer.WriteNumber("protocolVersion", envelope.ProtocolVersion);
            writer.WriteString("messageId", envelope.MessageId);
            writer.WriteString("sessionId", envelope.SessionId);
            writer.WriteNumber("sequence", envelope.Sequence);
            writer.WriteString("timestamp", envelope.Timestamp);
            writer.WriteString("type", envelope.Type);

            if (envelope.RequestId is Guid requestId)
            {
                writer.WriteString("requestId", requestId);
            }

            if (envelope.CorrelationId is Guid correlationId)
            {
                writer.WriteString("correlationId", correlationId);
            }

            writer.WritePropertyName("payload");
            envelope.Payload.WriteTo(writer);
            writer.WriteEndObject();
        }

        if (stream.Length > MaximumFrameBytes)
        {
            throw InvalidRequest("Envelope exceeds the maximum frame size.");
        }

        return stream.ToArray();
    }

    private static void ValidateProperties(JsonElement element)
    {
        if (element.ValueKind == JsonValueKind.Object)
        {
            var names = new HashSet<string>(StringComparer.Ordinal);
            foreach (JsonProperty property in element.EnumerateObject())
            {
                if (!names.Add(property.Name))
                {
                    throw InvalidRequest("Envelope contains a duplicate JSON property.");
                }

                ValidateProperties(property.Value);
            }
        }
        else if (element.ValueKind == JsonValueKind.Array)
        {
            foreach (JsonElement item in element.EnumerateArray())
            {
                ValidateProperties(item);
            }
        }
    }

    private static void ValidateEnvelopeProperties(JsonElement root)
    {
        foreach (JsonProperty property in root.EnumerateObject())
        {
            if (!AllowedProperties.Contains(property.Name))
            {
                throw InvalidRequest("Envelope contains an unsupported field.");
            }
        }
    }

    private static int ReadInt32(JsonElement root, string name)
    {
        if (!root.TryGetProperty(name, out JsonElement value) ||
            value.ValueKind != JsonValueKind.Number ||
            !value.TryGetInt32(out int result))
        {
            throw InvalidRequest("Envelope is missing a required integer field.");
        }

        return result;
    }

    private static long ReadInt64(JsonElement root, string name)
    {
        if (!root.TryGetProperty(name, out JsonElement value) ||
            value.ValueKind != JsonValueKind.Number ||
            !value.TryGetInt64(out long result))
        {
            throw InvalidRequest("Envelope is missing a required integer field.");
        }

        return result;
    }

    private static Guid ReadRequiredGuid(JsonElement root, string name)
    {
        if (!root.TryGetProperty(name, out JsonElement value) ||
            value.ValueKind != JsonValueKind.String ||
            !TryReadGuid(value, out Guid result) ||
            result == Guid.Empty)
        {
            throw InvalidRequest("Envelope is missing a required identifier field.");
        }

        return result;
    }

    private static Guid? ReadOptionalGuid(JsonElement root, string name)
    {
        if (!root.TryGetProperty(name, out JsonElement value) || value.ValueKind == JsonValueKind.Null)
        {
            return null;
        }

        if (value.ValueKind != JsonValueKind.String ||
            !TryReadGuid(value, out Guid result) ||
            result == Guid.Empty)
        {
            throw InvalidRequest("Envelope contains an invalid optional identifier field.");
        }

        return result;
    }

    private static bool TryReadGuid(JsonElement value, out Guid result)
    {
        string? text = value.GetString();
        return Guid.TryParseExact(text, "D", out result);
    }

    private static DateTimeOffset ReadTimestamp(JsonElement root)
    {
        if (!root.TryGetProperty("timestamp", out JsonElement value) || value.ValueKind != JsonValueKind.String)
        {
            throw InvalidRequest("Envelope is missing a required timestamp field.");
        }

        string? text = value.GetString();
        if (text is null ||
            !DateTimeOffset.TryParseExact(
                text,
                TimestampFormats,
                CultureInfo.InvariantCulture,
                DateTimeStyles.None,
                out DateTimeOffset result))
        {
            throw InvalidRequest("Envelope contains an invalid timestamp field.");
        }

        return result;
    }

    private static string ReadType(JsonElement root)
    {
        if (!root.TryGetProperty("type", out JsonElement value) || value.ValueKind != JsonValueKind.String)
        {
            throw InvalidRequest("Envelope is missing a required type field.");
        }

        string? type = value.GetString();
        if (!IsValidType(type))
        {
            throw InvalidRequest("Envelope contains an invalid type field.");
        }

        return type!;
    }

    private static JsonElement ReadPayload(JsonElement root)
    {
        if (!root.TryGetProperty("payload", out JsonElement payload) || payload.ValueKind != JsonValueKind.Object)
        {
            throw InvalidRequest("Envelope payload must be a JSON object.");
        }

        return payload;
    }

    private static bool IsValidType(string? type)
    {
        if (string.IsNullOrEmpty(type) || type.Length > 64 || type[0] is < 'a' or > 'z')
        {
            return false;
        }

        bool previousWasDot = false;
        for (int index = 1; index < type.Length; index++)
        {
            char current = type[index];
            if (current == '.')
            {
                if (previousWasDot)
                {
                    return false;
                }

                previousWasDot = true;
                continue;
            }

            if (current is not (>= 'a' and <= 'z') and not (>= '0' and <= '9'))
            {
                return false;
            }

            previousWasDot = false;
        }

        return !previousWasDot;
    }

    private static void ValidateForSerialization(ProtocolEnvelope envelope)
    {
        if (envelope.ProtocolVersion != SupportedProtocolVersion)
        {
            throw ProtocolMismatch("Protocol version is not supported.");
        }

        if (envelope.MessageId == Guid.Empty || envelope.SessionId == Guid.Empty)
        {
            throw InvalidRequest("Envelope contains an invalid identifier field.");
        }

        if (envelope.Sequence <= 0)
        {
            throw InvalidRequest("Envelope sequence must be positive.");
        }

        if (!IsValidType(envelope.Type))
        {
            throw InvalidRequest("Envelope contains an invalid type field.");
        }

        if (envelope.RequestId == Guid.Empty || envelope.CorrelationId == Guid.Empty)
        {
            throw InvalidRequest("Envelope contains an invalid optional identifier field.");
        }

        try
        {
            if (envelope.Payload.ValueKind != JsonValueKind.Object)
            {
                throw InvalidRequest("Envelope payload must be a JSON object.");
            }

            ValidateProperties(envelope.Payload);
        }
        catch (InvalidOperationException)
        {
            throw InvalidRequest("Envelope payload is unavailable.");
        }
    }

    private static ProtocolException InvalidRequest(string message) => new("invalidRequest", message);

    private static ProtocolException ProtocolMismatch(string message) => new("protocolMismatch", message);

    private static ProtocolException SessionExpired(string message) => new("sessionExpired", message);

    private static ProtocolException SecurityViolation(string message) => new("securityViolation", message);
}
