using Amazon.Lambda.Core;
using API.Models.Common;
using API.Models.CardProviders;
using API.Services.CardProviders.Interfaces;
using API.Utils;

namespace API.Services.CardProviders;

public class ScoredCardsProvider : ICardProvider
{
    private readonly ApiService _api;
    private readonly string _endpoint;
    private readonly ILogger<ScoredCardsProvider> _logger;

    public string ProviderName => "ScoredCards";

    public ScoredCardsProvider(ApiService api, IConfiguration configuration, ILogger<ScoredCardsProvider> logger)
    {
        _api = api;
        _endpoint = configuration["SCOREDCARDS_ENDPOINT"]
            ?? throw new InvalidOperationException("SCOREDCARDS_ENDPOINT not set");
        _logger = logger;
    }

    public async Task<List<CreditCardRecommendation>> GetRecommendations(
        CreditCardRequest request,
        ILambdaContext context)
    {
        try
        {
            var scoredRequest = new ScoredCardsRequest
            {
                Name = request.Name,
                Score = RequestNormalizer.NormalizeScore(request.Score),
                Salary = RequestNormalizer.NormalizeSalary(request.Salary)
            };

            var response = await _api.SendRequest<ScoredCardsResponse>(_endpoint, scoredRequest);
            _logger.LogInformation("ScoredCards raw response: {@Response}", response);

            var recommendations = response.Cards.Select(card => new CreditCardRecommendation
            {
                Provider = ProviderName,
                Name = card.Card,
                Apr = Convert.ToDecimal(card.Apr),
                CardScore = Convert.ToInt32(card.ApprovalRating * 100)
            }).ToList();

            _logger.LogInformation("ScoredCards processed recommendations: {@Recommendations}", recommendations);
            return recommendations;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching from ScoredCards. Request: {@Request}", request);
            return new List<CreditCardRecommendation>();
        }
    }
}