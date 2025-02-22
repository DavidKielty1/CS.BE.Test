using Amazon.Lambda.Core;
using API.Models.Common;
using API.Models.CardProviders;
using API.Services.Cache.Interfaces;
using API.Services.CardProviders.Interfaces;
using API.Services.Processing.Interfaces;
using API.Services.Core.Utils;
using API.Utils;
using System.Text.Json;

namespace API.Services.Processing;

public class RequestProcessor : IRequestProcessor
{
    private readonly ICardProviderFactory _providerFactory;
    private readonly IRedisCacheService _cache;
    private readonly ILogger<RequestProcessor> _logger;

    public RequestProcessor(
        ICardProviderFactory providerFactory,
        IRedisCacheService cache,
        ILogger<RequestProcessor> logger)
    {
        _providerFactory = providerFactory;
        _cache = cache;
        _logger = logger;
    }

    public async Task<List<CreditCardRecommendation>> ProcessCreditCardRequest(
        CreditCardRequest request,
        ILambdaContext? context)
    {
        try
        {
            _logger.LogInformation("Starting credit card request processing: {@Request}", request);
            var results = new List<CreditCardRecommendation>();
            var providers = _providerFactory.GetAllProviders();
            _logger.LogInformation("Retrieved {Count} providers", providers.Count());

            foreach (var provider in providers)
            {
                try
                {
                    _logger.LogInformation("Requesting recommendations from provider: {Provider}", provider.ProviderName);
                    var providerResults = await provider.GetRecommendations(request, context ?? throw new ArgumentNullException(nameof(context)));
                    _logger.LogInformation("Provider {Provider} returned {Count} recommendations", provider.ProviderName, providerResults.Count);
                    results.AddRange(providerResults);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error from provider {Provider}", provider.ProviderName);
                }
            }

            if (!results.Any())
            {
                _logger.LogWarning("No recommendations found from any provider for request: {@Request}", request);
                throw new ValidationException("No credit card recommendations found", "card_recommendations");
            }

            _logger.LogInformation("Successfully processed request. Total recommendations: {Count}", results.Count);
            return results;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to process credit card request: {@Request}", request);
            throw;
        }
    }

    public async Task<List<CreditCardRecommendation>> GetCachedResults(string key)
    {
        return await _cache.GetAsync<List<CreditCardRecommendation>>(key)
            ?? new List<CreditCardRecommendation>();
    }

    public async Task CacheResults(CreditCardRequest request, List<CreditCardRecommendation> cards)
    {
        var key = KeyBuilder.BuildKey(request.Name, request.Score, request.Salary);
        await _cache.SetAsync(key, cards);
    }

    public T ProcessInput<T>(object input) where T : class, new()
    {
        return JsonSerializer.Deserialize<T>(
            JsonSerializer.Serialize(input)) ?? new T();
    }

    public async Task<CreditCardRecommendation> ProcessRequestAsync(CreditCardRequest request)
    {
        // Or if you need async behavior:
        return await Task.FromResult(new CreditCardRecommendation());
    }

    public List<CreditCardRecommendation> NormalizeAndSortCards(List<CreditCardRecommendation> cards)
    {
        _logger.LogInformation("Starting card normalization for {Count} cards", cards.Count);
        var providers = _providerFactory.GetAllProviders();
        var normalizedCards = new List<CreditCardRecommendation>();

        foreach (var group in cards.GroupBy(c => c.Provider))
        {
            _logger.LogInformation("Normalizing cards for provider: {Provider}", group.Key);
            var provider = providers.FirstOrDefault(p => p.ProviderName == group.Key)
                ?? throw new ArgumentException($"Unknown provider: {group.Key}");

            var providerCards = group.Select(card => new CreditCardRecommendation
            {
                Provider = card.Provider,
                Name = card.Name,
                Apr = card.Apr,
                CardScore = provider.ProviderName switch
                {
                    "CSCards" => card.CardScore * 10,
                    "ScoredCards" => card.CardScore,
                    _ => card.CardScore
                }
            });
            _logger.LogDebug("Normalized scores for provider {Provider}: {@Cards}", group.Key, providerCards);
            normalizedCards.AddRange(providerCards);
        }

        normalizedCards.Sort((a, b) => b.CardScore.CompareTo(a.CardScore));
        _logger.LogInformation("Completed normalization. Cards sorted by score: {@Cards}", normalizedCards);
        return normalizedCards;
    }

    public CSCardsRequest ProcessCSCardsRequest(CreditCardRequest request)
    {
        return new CSCardsRequest
        {
            Name = request.Name,
            CreditScore = RequestNormalizer.NormalizeScore(request.Score)
        };
    }

    public ScoredCardsRequest ProcessScoredCardsRequest(CreditCardRequest request)
    {
        return new ScoredCardsRequest
        {
            Name = request.Name,
            Score = request.Score,
            Salary = request.Salary
        };
    }
}