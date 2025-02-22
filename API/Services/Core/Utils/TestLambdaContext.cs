using Amazon.Lambda.Core;

namespace API.Services.Core.Utils;

public class TestLambdaContext : ILambdaContext
{
    public string AwsRequestId => "test-request";
    public IClientContext ClientContext => null;
    public string FunctionName => "test-function";
    public string FunctionVersion => "test-version";
    public ICognitoIdentity Identity => null;
    public string InvokedFunctionArn => "test-arn";
    public ILambdaLogger Logger => new TestLambdaLogger();
    public string LogGroupName => "test-log-group";
    public string LogStreamName => "test-log-stream";
    public int MemoryLimitInMB => 128;
    public TimeSpan RemainingTime => TimeSpan.FromSeconds(30);
}

public class TestLambdaLogger : ILambdaLogger
{
    public void Log(string message) { }
    public void LogLine(string message) { }
}