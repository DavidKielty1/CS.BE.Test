using System.Threading.Tasks;
using Amazon.Lambda.Core;
using API.Models.Common;
using API.Models.CardProviders;

namespace API.Services.Processing.Interfaces;

public interface IResponseProcessor
{
    Task<T> ProcessSuccessResponse<T>(object data, ILambdaContext context);
    Task ProcessFailedRequest(string provider, CreditCardRequest request, Exception error);
    Task NotifySuccess(List<CreditCardRecommendation> cards, CreditCardRequest request);
    object CreateResponse(string message);
    Task<TResponse> ProcessResponseAsync<TResponse>(TResponse response);
    List<CreditCardRecommendation> ProcessCSCardsResponse(CSCardsResponse response);
    List<CreditCardRecommendation> ProcessScoredCardsResponse(ScoredCardsResponse response);
}