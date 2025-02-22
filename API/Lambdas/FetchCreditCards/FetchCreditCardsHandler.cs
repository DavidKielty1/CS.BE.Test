using API.Models.Common;
using API.Services.Core.Handlers;
using Amazon.Lambda.Core;
using Amazon.Lambda.Serialization.SystemTextJson;
using Amazon.Lambda.APIGatewayEvents;
using API.Services.CardProviders;
using API.Services.Core.Utils;
using System.Text.Json;

[assembly: LambdaSerializer(typeof(DefaultLambdaJsonSerializer))]

namespace API.Lambdas.FetchCreditCards
{
    public class FetchCreditCardsHandler : LambdaHandler<CreditCardRequest, List<CreditCardRecommendation>>
    {
        private readonly CSCardsProvider _csCardsProvider;
        private readonly ScoredCardsProvider _scoredCardsProvider;
        private readonly ILogger<FetchCreditCardsHandler> _fetchLogger;

        public FetchCreditCardsHandler() : base()
        {
            _csCardsProvider = _serviceProvider.GetRequiredService<CSCardsProvider>();
            _scoredCardsProvider = _serviceProvider.GetRequiredService<ScoredCardsProvider>();
            _fetchLogger = _serviceProvider.GetRequiredService<ILogger<FetchCreditCardsHandler>>();
        }

        public async Task<APIGatewayProxyResponse> FunctionHandler(CreditCardRequest request, ILambdaContext context)
        {
            return await base.FunctionHandler(request, context);
        }

        protected override async Task<List<CreditCardRecommendation>> ProcessRequest(CreditCardRequest request, ILambdaContext context)
        {
            _fetchLogger.LogInformation("""
                FetchCreditCards Input:
                {Request}
                """,
                JsonSerializer.Serialize(request, new JsonSerializerOptions { WriteIndented = true })
            );

            try
            {
                var tasks = new[]
                {
                    _csCardsProvider.GetRecommendations(request, context!),
                    _scoredCardsProvider.GetRecommendations(request, context!)
                };

                var results = await Task.WhenAll(tasks);
                var allCards = results.SelectMany(x => x).ToList();

                if (!allCards.Any())
                {
                    throw new Exception("No credit cards found from any provider");
                }

                return allCards;
            }
            catch (Exception)
            {
                throw;
            }
        }
    }
}
