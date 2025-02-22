using API.Models.Lambda.Inputs;
using System.Text.Json;
using API.Models.Messages;
using API.Services.Core.Handlers;
using API.Services.Aws.Interfaces;
using Amazon.Lambda.Core;
using Amazon.Lambda.SQSEvents;
using Amazon.Lambda.APIGatewayEvents;
using Amazon.Lambda.Serialization.SystemTextJson;
using API.Services.Processing.Interfaces;
using System.ComponentModel.DataAnnotations;

namespace API.Lambdas.PublishToSQS;

public class PublishToSQSHandler : LambdaHandler<SQSInput, object>
{
    private readonly IAwsMessagingService _messagingService;

    // Required by Lambda
    public PublishToSQSHandler() : base()
    {
        _messagingService = _serviceProvider.GetRequiredService<IAwsMessagingService>();
    }

    public PublishToSQSHandler(IServiceProvider serviceProvider)
        : base(serviceProvider)
    {
        _messagingService = serviceProvider.GetRequiredService<IAwsMessagingService>();
    }

    // Required Lambda entry point
    [LambdaSerializer(typeof(DefaultLambdaJsonSerializer))]
    protected override async Task<object> ProcessRequest(SQSInput input, ILambdaContext context)
    {
        if (string.IsNullOrEmpty(input.QueueUrl))
        {
            throw new ArgumentException("QueueUrl cannot be null or empty");
        }

        if (string.IsNullOrEmpty(input.MessageBody))
        {
            throw new ArgumentException("MessageBody cannot be null or empty");
        }

        var failedRequest = JsonSerializer.Deserialize<FailedRequestMessage>(
            input.MessageBody)
            ?? throw new ArgumentException("Failed to deserialize message");

        // Validate the request has required fields
        if (string.IsNullOrEmpty(failedRequest.Request.Name))
        {
            throw new ValidationException("Name is required in the request");
        }

        try
        {
            // Attempt to process the request again
            var cardProcessor = _serviceProvider.GetRequiredService<IRequestProcessor>();
            var results = await cardProcessor.ProcessCreditCardRequest(failedRequest.Request, context);

            if (results.Any())
            {
                return results;
            }

            // If still no results, send to DLQ
            await _messagingService.SendToSqs(
                input.QueueUrl,
                failedRequest
            );
            throw new Exception("Failed to process request after retry");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to process request in SQS handler");
            throw;
        }
    }
}