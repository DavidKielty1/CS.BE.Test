namespace API.Services.Core.Exceptions;

public class LambdaException : Exception
{
    public string ErrorType { get; }
    public string Context { get; }

    public LambdaException(
        string message,
        Exception? innerException = null,
        string errorType = "PROCESSING_ERROR",
        string context = "LAMBDA")
        : base(message, innerException)
    {
        ErrorType = errorType;
        Context = context;
    }
}