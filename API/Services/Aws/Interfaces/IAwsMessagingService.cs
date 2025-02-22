using Amazon.SQS.Model;
using API.Models.Common;
using API.Models.Lambda.Inputs;

namespace API.Services.Aws.Interfaces;


public interface IAwsMessagingService
{
    Task PublishToSns<T>(T message);
    Task<string> SendToSqs<T>(string queueUrl, T message);
    Task PublishToAll<T>(T message);
    Task<List<Message>> ReceiveFromSqs(string queueUrl, int maxMessages = 10);
    Task DeleteFromSqs(string queueUrl, string receiptHandle);
    Task PublishMessageAsync<T>(T message);
    Task SendMessageAsync(string queueUrl, string message);
    Task<string> StartStateMachineAsync(CreditCardRequest request);
    Task<string?> GetExecutionResult(string executionArn);
}