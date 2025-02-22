using Amazon.Lambda.Core;
using API.Models.Common;

namespace API.Services.CardProviders.Interfaces;

public interface ICardProvider
{
    string ProviderName { get; }
    Task<List<CreditCardRecommendation>> GetRecommendations(
        CreditCardRequest request,
        ILambdaContext context);
}