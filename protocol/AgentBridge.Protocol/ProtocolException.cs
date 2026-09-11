namespace RemoteJARVIS.Protocol;

public sealed class ProtocolException : Exception
{
    public ProtocolException(string code, string message)
        : base(message)
    {
        Code = code;
    }

    public string Code { get; }
}
