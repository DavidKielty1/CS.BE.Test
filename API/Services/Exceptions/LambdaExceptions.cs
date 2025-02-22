using System.Net;

namespace API.Services
{
    public class LambdaException : Exception
    {
        public string ErrorType { get; }
        public string ErrorContext { get; }

        public LambdaException(
            string message,
            Exception? innerException,
            string errorType,
            string errorContext) : base(message, innerException)
        {
            ErrorType = errorType;
            ErrorContext = errorContext;
        }
    }

    public class ApiException : LambdaException
    {
        public HttpStatusCode StatusCode { get; }

        public ApiException(
            string message,
            Exception innerException,
            HttpStatusCode statusCode,
            string context) : base(
                message,
                innerException,
                "API_ERROR",
                context)
        {
            StatusCode = statusCode;
        }
    }

    public class ValidationException : LambdaException
    {
        public ValidationException(
            string message,
            string context) : base(
                message,
                null,
                "VALIDATION_ERROR",
                context)
        {
        }
    }
}