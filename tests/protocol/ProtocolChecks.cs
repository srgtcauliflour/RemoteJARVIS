using System.Globalization;
using System.Text;
using System.Text.Json;
using RemoteJARVIS.Protocol;

public static class ProtocolChecks
{
    public static void Run(Action<bool, string> check)
    {
        DateTimeOffset now = new(2026, 9, 11, 3, 0, 0, TimeSpan.Zero);
        Guid sessionId = Guid.Parse("aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee");
        Guid messageId = Guid.Parse("11111111-2222-4333-8444-555555555555");
        Guid requestId = Guid.Parse("66666666-7777-4888-8999-aaaaaaaaaaaa");

        byte[] valid = Envelope(now, sessionId, messageId, 1, requestId: requestId);
        ProtocolEnvelope parsed = ProtocolCodec.Parse(valid, sessionId, 1, now);
        check(parsed.ProtocolVersion == 1, "protocol parses supported version");
        check(parsed.MessageId == messageId && parsed.SessionId == sessionId, "protocol parses identifiers");
        check(parsed.Sequence == 1 && parsed.Type == "request.execute", "protocol parses sequence and type");
        check(parsed.RequestId == requestId && parsed.CorrelationId is null, "protocol parses optional identifiers");
        check(parsed.Payload.GetProperty("nested").GetProperty("ok").GetBoolean(), "protocol retains cloned payload");

        ExpectCode(check, "protocol rejects wrong session", "securityViolation", () =>
            ProtocolCodec.Parse(valid, Guid.NewGuid(), 1, now));
        ExpectCode(check, "protocol rejects replayed sequence", "securityViolation", () =>
            ProtocolCodec.Parse(valid, sessionId, 2, now));
        ExpectCode(check, "protocol rejects nonpositive sequence", "securityViolation", () =>
            ProtocolCodec.Parse(Envelope(now, sessionId, messageId, 0), sessionId, 1, now));

        ExpectCode(check, "protocol rejects newer version", "protocolMismatch", () =>
            ProtocolCodec.Parse(Envelope(now, sessionId, messageId, 1, protocolVersion: 2), sessionId, 1, now));
        ExpectCode(check, "protocol rejects older version", "protocolMismatch", () =>
            ProtocolCodec.Parse(Envelope(now, sessionId, messageId, 1, protocolVersion: 0), sessionId, 1, now));

        string duplicateNested = Json(valid).Replace(
            "\"nested\":{\"ok\":true}",
            "\"nested\":{\"ok\":true,\"ok\":false}",
            StringComparison.Ordinal);
        ExpectCode(check, "protocol rejects duplicate nested payload properties", "invalidRequest", () =>
            ProtocolCodec.Parse(Encoding.UTF8.GetBytes(duplicateNested), sessionId, 1, now));

        ExpectCode(check, "protocol rejects oversized frames", "invalidRequest", () =>
            ProtocolCodec.Parse(new byte[ProtocolCodec.MaximumFrameBytes + 1], sessionId, 1, now));
        ExpectCode(check, "protocol rejects malformed JSON", "invalidRequest", () =>
            ProtocolCodec.Parse(Encoding.UTF8.GetBytes("{\"protocolVersion\":"), sessionId, 1, now));

        string missingPayload = Json(valid).Replace(
            ",\"payload\":{\"nested\":{\"ok\":true}}",
            string.Empty,
            StringComparison.Ordinal);
        ExpectCode(check, "protocol rejects missing mandatory fields", "invalidRequest", () =>
            ProtocolCodec.Parse(Encoding.UTF8.GetBytes(missingPayload), sessionId, 1, now));

        string unknownField = Json(valid).Replace(
            "\"payload\":",
            "\"extra\":true,\"payload\":",
            StringComparison.Ordinal);
        ExpectCode(check, "protocol rejects unknown top-level fields", "invalidRequest", () =>
            ProtocolCodec.Parse(Encoding.UTF8.GetBytes(unknownField), sessionId, 1, now));

        ExpectCode(check, "protocol rejects stale timestamps", "sessionExpired", () =>
            ProtocolCodec.Parse(Envelope(now.AddMinutes(-5).AddTicks(-1), sessionId, messageId, 1), sessionId, 1, now));
        ExpectCode(check, "protocol rejects future timestamps", "sessionExpired", () =>
            ProtocolCodec.Parse(Envelope(now.AddMinutes(5).AddTicks(1), sessionId, messageId, 1), sessionId, 1, now));

        using JsonDocument payloadDocument = JsonDocument.Parse("{\"answer\":42,\"items\":[1,2,3]}");
        var original = new ProtocolEnvelope(
            1,
            messageId,
            sessionId,
            7,
            now,
            "response.complete",
            requestId,
            messageId,
            payloadDocument.RootElement.Clone());
        byte[] serialized = ProtocolCodec.Serialize(original);
        ProtocolEnvelope roundTrip = ProtocolCodec.Parse(serialized, sessionId, 7, now);
        check(roundTrip.ProtocolVersion == original.ProtocolVersion &&
              roundTrip.MessageId == original.MessageId &&
              roundTrip.SessionId == original.SessionId &&
              roundTrip.Sequence == original.Sequence &&
              roundTrip.Timestamp == original.Timestamp &&
              roundTrip.Type == original.Type &&
              roundTrip.RequestId == original.RequestId &&
              roundTrip.CorrelationId == original.CorrelationId,
            "protocol round-trips envelope fields");
        check(roundTrip.Payload.GetRawText() == original.Payload.GetRawText(), "protocol round-trips payload");
        check(!Json(serialized).Contains("\n", StringComparison.Ordinal), "protocol serialization is compact");
    }

    private static byte[] Envelope(
        DateTimeOffset timestamp,
        Guid sessionId,
        Guid messageId,
        long sequence,
        int protocolVersion = 1,
        Guid? requestId = null)
    {
        string optionalRequestId = requestId is Guid value
            ? $",\"requestId\":\"{value:D}\""
            : string.Empty;
        string json = "{" +
            $"\"protocolVersion\":{protocolVersion}," +
            $"\"messageId\":\"{messageId:D}\"," +
            $"\"sessionId\":\"{sessionId:D}\"," +
            $"\"sequence\":{sequence}," +
            $"\"timestamp\":\"{timestamp.ToString("O", CultureInfo.InvariantCulture)}\"," +
            "\"type\":\"request.execute\"" +
            optionalRequestId +
            ",\"correlationId\":null," +
            "\"payload\":{\"nested\":{\"ok\":true}}" +
            "}";
        return Encoding.UTF8.GetBytes(json);
    }

    private static string Json(byte[] utf8) => Encoding.UTF8.GetString(utf8);

    private static void ExpectCode(
        Action<bool, string> check,
        string name,
        string expectedCode,
        Action action)
    {
        try
        {
            action();
            check(false, name);
        }
        catch (ProtocolException exception)
        {
            check(exception.Code == expectedCode, name);
        }
        catch (Exception)
        {
            check(false, name);
        }
    }
}
