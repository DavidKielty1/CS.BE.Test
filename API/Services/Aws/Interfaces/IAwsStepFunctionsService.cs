namespace API.Services.Aws.Interfaces;

public interface IAwsStepFunctionsService
{
    Task<string> StartStateMachineAsync<T>(T input);
    Task<string> GetExecutionResult(string executionArn);
}