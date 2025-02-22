using Amazon.SimpleNotificationService;
using Amazon.SQS;
using Amazon.SQS.Model;
using API.Services.Aws.Interfaces;
using System.Text.Json;
using Amazon.SimpleNotificationService.Model;
using Amazon.StepFunctions;
using API.Models.Common;
using Amazon.StepFunctions.Model;

namespace API.Services.Aws;

public class AwsMessagingService : IAwsMessagingService
{
    private readonly IAmazonSimpleNotificationService _snsClient;
    private readonly IAmazonSQS _sqsClient;
    private readonly IAmazonStepFunctions _stepFunctions;
    private readonly IConfiguration _configuration;
    private readonly ILogger<AwsMessagingService> _logger;

    public AwsMessagingService(
        IAmazonSimpleNotificationService snsClient,
        IAmazonSQS sqsClient,
        IAmazonStepFunctions stepFunctions,
        IConfiguration configuration,
        ILogger<AwsMessagingService> logger)
    {
        _snsClient = snsClient;
        _sqsClient = sqsClient;
        _stepFunctions = stepFunctions;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task PublishToSns<T>(T message)
    {
        var topicArn = _configuration["AWS:SnsTopicArn"]
            ?? throw new InvalidOperationException("SNS Topic ARN not configured");

        var json = JsonSerializer.Serialize(message);
        await _snsClient.PublishAsync(topicArn, json);
        _logger.LogInformation("Published message to SNS: {TopicArn}", topicArn);
    }

    public async Task<string> SendToSqs<T>(string queueUrl, T message)
    {
        _logger.LogInformation("Sending message to SQS: {QueueUrl}", queueUrl);
        _logger.LogDebug("Message content: {@Message}", message);

        try
        {
            var request = new SendMessageRequest
            {
                QueueUrl = queueUrl,
                MessageBody = JsonSerializer.Serialize(message)
            };

            var response = await _sqsClient.SendMessageAsync(request);
            _logger.LogInformation("Successfully sent message to SQS. MessageId: {MessageId}", response.MessageId);
            return response.MessageId;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send message to SQS. Queue: {QueueUrl}", queueUrl);
            throw;
        }
    }

    public async Task PublishToAll<T>(T message)
    {
        await PublishToSns(message);
        var queueUrl = _configuration["AWS:SqsQueueUrl"];
        if (!string.IsNullOrEmpty(queueUrl))
        {
            await SendToSqs(queueUrl, message);
        }
    }

    public async Task<List<Message>> ReceiveFromSqs(string queueUrl, int maxMessages = 10)
    {
        var response = await _sqsClient.ReceiveMessageAsync(new ReceiveMessageRequest
        {
            QueueUrl = queueUrl,
            MaxNumberOfMessages = maxMessages
        });
        return response.Messages;
    }

    public async Task DeleteFromSqs(string queueUrl, string receiptHandle)
    {
        await _sqsClient.DeleteMessageAsync(queueUrl, receiptHandle);
        _logger.LogInformation("Deleted message from SQS: {QueueUrl}", queueUrl);
    }

    public async Task PublishMessageAsync<T>(T message)
    {
        _logger.LogInformation("Publishing message to SNS: {@Message}", message);
        try
        {
            var request = new PublishRequest
            {
                TopicArn = _configuration["AWS:SNSTopicArn"],
                Message = JsonSerializer.Serialize(message)
            };

            var response = await _snsClient.PublishAsync(request);
            _logger.LogInformation("Successfully published to SNS. MessageId: {MessageId}", response.MessageId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to publish message to SNS");
            throw;
        }
    }

    public async Task SendMessageAsync(string queueUrl, string message)
    {
        await _sqsClient.SendMessageAsync(queueUrl, message);
    }

    public async Task<string> StartStateMachineAsync(CreditCardRequest request)
    {
        try
        {
            var startExecutionRequest = new StartExecutionRequest
            {
                StateMachineArn = _configuration["AWS:StateMachineArn"],
                Input = JsonSerializer.Serialize(request)
            };

            var response = await _stepFunctions.StartExecutionAsync(startExecutionRequest);
            _logger.LogInformation("State machine execution started. ExecutionArn: {ExecutionArn}", response.ExecutionArn);

            return response.ExecutionArn;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to start state machine execution for request: {@Request}", request);
            throw;
        }
    }

    public async Task<string?> GetExecutionResult(string executionArn)
    {
        _logger.LogInformation("Getting execution result for ARN: {ExecutionArn}", executionArn);
        try
        {
            var describeRequest = new DescribeExecutionRequest
            {
                ExecutionArn = executionArn
            };

            var maxAttempts = 30; // 30 seconds timeout
            var attempts = 0;

            while (attempts < maxAttempts)
            {
                var response = await _stepFunctions.DescribeExecutionAsync(describeRequest);

                if (response.Status == ExecutionStatus.SUCCEEDED)
                {
                    _logger.LogInformation("Execution completed successfully. Output: {Output}", response.Output);
                    return response.Output;
                }

                if (response.Status == ExecutionStatus.FAILED)
                {
                    _logger.LogError("Execution failed. Error: {Error}", response.Error);
                    throw new Exception($"State machine execution failed: {response.Error}");
                }

                _logger.LogDebug("Execution still in progress. Status: {Status}. Attempt: {Attempt}/{MaxAttempts}",
                    response.Status, attempts + 1, maxAttempts);
                await Task.Delay(1000); // Wait 1 second before next check
                attempts++;
            }

            _logger.LogWarning("Execution timed out after {Attempts} attempts", attempts);
            throw new TimeoutException("State machine execution timed out");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting execution result for ARN: {ExecutionArn}", executionArn);
            throw;
        }
    }
}