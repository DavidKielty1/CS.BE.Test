using Amazon.Lambda.Core;
using API.Models.Common;

namespace API.Utils
{
    public static class ResponseProcessor
    {
        public static List<CreditCardRecommendation> ProcessProviderResponse<T>(
            T? response,
            string provider,
            Func<T, List<CreditCardRecommendation>> mapper,
            ILambdaContext context)
        {
            if (response == null)
            {
                context.Logger.LogWarning($"No response from {provider}");
                return new List<CreditCardRecommendation>();
            }

            try
            {
                return mapper(response);
            }
            catch (Exception ex)
            {
                context.Logger.LogError($"Error mapping {provider} response: {ex.Message}");
                throw;
            }
        }
    }
}