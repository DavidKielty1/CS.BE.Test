using Amazon.Lambda.Core;
using Amazon.Lambda.SQSEvents;
using System.Text.Json;
using API.Models.Messages;
using API.Models.Common;
using API.Services.Core.Handlers;
using API.Services.Processing.Interfaces;
using Amazon.Lambda.Serialization.SystemTextJson;
using Amazon.Lambda.APIGatewayEvents;
using API.Services.CardProviders;
using API.Services.Aws.Interfaces;

namespace API.Lambdas.ProcessFailedRequests
{
    public class ProcessFailedRequestsHandler : LambdaHandler<SQSEvent, List<CreditCardRecommendation>>
    {
        private readonly IRequestProcessor _cardProcessor;
        private readonly IResponseProcessor _messagingService;
        private readonly IAwsMessagingService _awsMessaging;
        private readonly IConfiguration _configuration;
        private readonly ILogger<ProcessFailedRequestsHandler> _retryLogger;

        public ProcessFailedRequestsHandler() : base()
        {
            _cardProcessor = _serviceProvider.GetRequiredService<IRequestProcessor>();
            _messagingService = _serviceProvider.GetRequiredService<IResponseProcessor>();
            _awsMessaging = _serviceProvider.GetRequiredService<IAwsMessagingService>();
            _configuration = _serviceProvider.GetRequiredService<IConfiguration>();
            _retryLogger = _serviceProvider.GetRequiredService<ILogger<ProcessFailedRequestsHandler>>();
        }

        [LambdaSerializer(typeof(DefaultLambdaJsonSerializer))]
        public async Task<APIGatewayProxyResponse> FunctionHandler(SQSEvent sqsEvent, ILambdaContext context)
        {
            return await base.FunctionHandler(sqsEvent, context);
        }

        [LambdaSerializer(typeof(DefaultLambdaJsonSerializer))]
        protected override async Task<List<CreditCardRecommendation>> ProcessRequest(SQSEvent sqsEvent, ILambdaContext? context)
        {
            if (sqsEvent?.Records == null || !sqsEvent.Records.Any())
            {
                return new List<CreditCardRecommendation>();
            }

            if (context == null) throw new ArgumentNullException(nameof(context));

            foreach (var message in sqsEvent.Records)
            {
                try
                {
                    var failedRequest = JsonSerializer.Deserialize<FailedRequestMessage>(message.Body)
                        ?? throw new ArgumentException("Invalid message format");

                    // Try to fetch from both providers again
                    var csCardsProvider = _serviceProvider.GetRequiredService<CSCardsProvider>();
                    var scoredCardsProvider = _serviceProvider.GetRequiredService<ScoredCardsProvider>();

                    var tasks = new[]
                    {
                        csCardsProvider.GetRecommendations(failedRequest.Request, context),
                        scoredCardsProvider.GetRecommendations(failedRequest.Request, context)
                    };

                    var results = await Task.WhenAll(tasks);
                    var allCards = results.SelectMany(x => x).ToList();

                    if (allCards.Any())
                    {
                        await _messagingService.NotifySuccess(allCards, failedRequest.Request);
                        return allCards;
                    }

                    // If still no cards, send to DLQ
                    var dlqUrl = _configuration["AWS:DLQUrl"]
                        ?? throw new InvalidOperationException("DLQ URL not configured");

                    await _awsMessaging.SendToSqs(
                        dlqUrl,
                        failedRequest
                    );
                }
                catch (Exception ex)
                {
                    _retryLogger.LogError(ex, "Failed to process request in retry handler");
                    throw;
                }
            }

            return new List<CreditCardRecommendation>();
        }
    }
}