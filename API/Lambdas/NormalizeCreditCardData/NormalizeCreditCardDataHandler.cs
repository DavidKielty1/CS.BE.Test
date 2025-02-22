using Amazon.Lambda.Core;
using Amazon.Lambda.APIGatewayEvents;
using API.Models.Common;
using API.Models.Lambda.Inputs;
using API.Services.Core.Handlers;
using Amazon.Lambda.Serialization.SystemTextJson;
using API.Services.Processing.Interfaces;

namespace API.Lambdas.NormalizeCreditCardData
{
    public class NormalizeCreditCardDataHandler : LambdaHandler<NormalizeInput, List<CreditCardRecommendation>>
    {
        private readonly ILogger<NormalizeCreditCardDataHandler> _normalizeLogger;
        private readonly IRequestProcessor _cardProcessor;

        public NormalizeCreditCardDataHandler() : base()
        {
            _normalizeLogger = _serviceProvider.GetRequiredService<ILogger<NormalizeCreditCardDataHandler>>();
            _cardProcessor = _serviceProvider.GetRequiredService<IRequestProcessor>();
        }


        [LambdaSerializer(typeof(DefaultLambdaJsonSerializer))]
        public async Task<APIGatewayProxyResponse> FunctionHandler(NormalizeInput input, ILambdaContext context)
        {
            return await base.FunctionHandler(input, context);
        }

        protected override Task<List<CreditCardRecommendation>> ProcessRequest(NormalizeInput input, ILambdaContext? context)
        {
            try
            {
                _normalizeLogger.LogInformation("Normalize Lambda started: {@Input}", input);
                _normalizeLogger.LogInformation("Lambda context: {@Context}", new { context?.FunctionName, context?.RemainingTime });

                var cards = input.Cards ?? throw new ArgumentNullException(nameof(input.Cards));
                _normalizeLogger.LogInformation("Processing {Count} cards for normalization", cards.Count);

                _normalizeLogger.LogInformation("Starting card normalization process");
                var normalizedCards = _cardProcessor.NormalizeAndSortCards(cards);
                _normalizeLogger.LogInformation("Cards normalized and sorted: {@NormalizedCards}", normalizedCards);

                foreach (var card in normalizedCards)
                {
                    _normalizeLogger.LogDebug("Normalized card: {@Card}", card);
                }

                _normalizeLogger.LogInformation("Normalization complete. Processed {Count} cards", normalizedCards.Count);
                return Task.FromResult(normalizedCards);
            }
            catch (Exception ex)
            {
                _normalizeLogger.LogError(ex, "Normalization failed. Input: {@Input}", input);
                throw;
            }
        }
    }
}
