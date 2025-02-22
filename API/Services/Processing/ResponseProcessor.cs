using Amazon.Lambda.Core;
using API.Models.Common;
using API.Models.Messages;
using API.Services.Aws.Interfaces;
using API.Services.Processing.Interfaces;
using API.Models.Lambda.Inputs;
using System.Text.Json;
using API.Models.CardProviders;

namespace API.Services.Processing;

public class ResponseProcessor : IResponseProcessor
{
    private static readonly JsonSerializerOptions _jsonOptions = new()
    {
        PropertyNameCaseInsensitive = true
    };

    private readonly IAwsMessagingService _messaging;
    private readonly ILogger<ResponseProcessor> _logger;
    private readonly IConfiguration _configuration;

    public ResponseProcessor(
        IAwsMessagingService messaging,
        ILogger<ResponseProcessor> logger,
        IConfiguration configuration)
    {
        _messaging = messaging;
        _logger = logger;
        _configuration = configuration;
    }

    public async Task<T> ProcessSuccessResponse<T>(object data, ILambdaContext context)
    {
        _logger.LogInformation("Processing success response: {@Data}", data);
        try
        {
            var response = await Task.Run(() => JsonSerializer.Deserialize<T>(
                JsonSerializer.Serialize(data, _jsonOptions),
                _jsonOptions));

            _logger.LogInformation("Successfully processed response: {@Response}", response);
            return response ?? throw new InvalidOperationException("Failed to process response");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to process success response. Data: {@Data}", data);
            throw;
        }
    }

    public async Task ProcessFailedRequest(string provider, CreditCardRequest request, Exception error)
    {
        _logger.LogWarning("Processing failed request from {Provider}. Request: {@Request}, Error: {Error}",
            provider, request, error.Message);

        var failedMessage = new FailedRequestMessage
        {
            Provider = provider,
            Request = request,
            Error = error.Message,
            Timestamp = DateTime.UtcNow
        };

        _logger.LogInformation("Publishing failed request message: {@Message}", failedMessage);
        await _messaging.PublishMessageAsync(failedMessage);
    }

    private async Task QueueFailedRequest(string provider, CreditCardRequest request)
    {
        var queueUrl = _configuration["AWS:SqsQueueUrl"]
            ?? throw new InvalidOperationException("AWS:SqsQueueUrl not configured");

        var failedMessage = new FailedRequestMessage
        {
            Provider = provider,
            Request = request,
            Timestamp = DateTime.UtcNow
        };

        await _messaging.SendToSqs(queueUrl, failedMessage);
        _logger.LogInformation("Queued failed request for retry: {Provider}", provider);
    }

    public async Task NotifySuccess(List<CreditCardRecommendation> cards, CreditCardRequest request)
    {
        var message = new PublishToSNSRequestModel
        {
            Cards = cards,
            NotificationType = "Success",
            Request = new CreditCardRequestInfo
            {
                Name = request.Name,
                Score = request.Score,
                Salary = request.Salary
            }
        };

        await _messaging.PublishToSns(message);
        _logger.LogInformation("Published success notification for: {Name}", request.Name);
    }

    public T CreateResponse<T>(string message) where T : class
    {
        return JsonSerializer.Deserialize<T>(
            JsonSerializer.Serialize(new { message })) ?? throw new ArgumentException("Failed to create response");
    }

    public object CreateResponse(string message)
    {
        return new { message };
    }

    public Task<TResponse> ProcessResponseAsync<TResponse>(TResponse response)
    {
        return Task.FromResult(response);
    }

    public List<CreditCardRecommendation> ProcessCSCardsResponse(CSCardsResponse response)
    {
        return response.Cards.Select(card => new CreditCardRecommendation
        {
            Provider = "CSCards",
            Name = card.CardName,
            Apr = Convert.ToDecimal(card.Apr),
            CardScore = Convert.ToInt32(card.Eligibility)
        }).ToList();
    }

    public List<CreditCardRecommendation> ProcessScoredCardsResponse(ScoredCardsResponse response)
    {
        return response.Cards.Select(card => new CreditCardRecommendation
        {
            Provider = "ScoredCards",
            Name = card.Card,
            Apr = Convert.ToDecimal(card.Apr),
            CardScore = Convert.ToInt32(card.ApprovalRating * 100)
        }).ToList();
    }
}