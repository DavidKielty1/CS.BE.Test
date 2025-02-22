using Amazon.StepFunctions.Model;
using Amazon.StepFunctions;
using API.Services.Aws.Interfaces;

namespace API.Services.Aws;

public class AwsStepFunctionsService : IAwsStepFunctionsService
{
    private readonly IAmazonStepFunctions _stepFunctionsClient;
    private readonly IConfiguration _configuration;

    public AwsStepFunctionsService(
        IAmazonStepFunctions stepFunctionsClient,
        IConfiguration configuration)
    {
        _stepFunctionsClient = stepFunctionsClient;
        _configuration = configuration;
    }

    public async Task<string> StartStateMachineAsync<T>(T input)
    {
        var response = await _stepFunctionsClient.StartExecutionAsync(new StartExecutionRequest
        {
            StateMachineArn = _configuration.GetValue<string>("AWS:StateMachineArn")
                ?? throw new InvalidOperationException("StateMachineArn not configured in appsettings.json"),
            Input = System.Text.Json.JsonSerializer.Serialize(input)
        });
        return response.ExecutionArn;
    }

    public async Task<string> GetExecutionResult(string executionArn)
    {
        // First get the execution status
        var execution = await _stepFunctionsClient.DescribeExecutionAsync(new DescribeExecutionRequest
        {
            ExecutionArn = executionArn
        });

        if (execution.Status != ExecutionStatus.SUCCEEDED)
        {
            throw new InvalidOperationException($"Execution {executionArn} is in state {execution.Status}");
        }

        var response = await _stepFunctionsClient.GetExecutionHistoryAsync(new GetExecutionHistoryRequest
        {
            ExecutionArn = executionArn,
            ReverseOrder = true
        });

        var successEvent = response.Events
            .FirstOrDefault(e => e.Type == HistoryEventType.ExecutionSucceeded);

        if (successEvent?.ExecutionSucceededEventDetails == null)
        {
            throw new InvalidOperationException("Could not find success event in execution history");
        }

        return successEvent.ExecutionSucceededEventDetails.Output;
    }
}