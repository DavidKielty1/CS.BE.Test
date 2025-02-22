using Amazon.Lambda.Core;
using API.Models.Common;
using API.Models;
using System.Threading.Tasks;
using API.Models.CardProviders;

namespace API.Services.Processing.Interfaces;

public interface IRequestProcessor
{
    Task<List<CreditCardRecommendation>> ProcessCreditCardRequest(
        CreditCardRequest request,
        ILambdaContext? context);

    Task<List<CreditCardRecommendation>> GetCachedResults(string key);
    Task CacheResults(CreditCardRequest request, List<CreditCardRecommendation> cards);

    T ProcessInput<T>(object input) where T : class, new();

    Task<CreditCardRecommendation> ProcessRequestAsync(CreditCardRequest request);

    List<CreditCardRecommendation> NormalizeAndSortCards(List<CreditCardRecommendation> cards);

    CSCardsRequest ProcessCSCardsRequest(CreditCardRequest request);
    ScoredCardsRequest ProcessScoredCardsRequest(CreditCardRequest request);
}