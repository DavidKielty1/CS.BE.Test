using System.Threading.Tasks;
using API.Models.Common;

namespace API.Services.Cache.Interfaces;

public interface IRedisCacheService
{
    Task<T?> GetAsync<T>(string key) where T : class;
    Task SetAsync<T>(string key, T value) where T : class;
    Task RemoveAsync(string key);
    Task<List<CreditCardRecommendation>> GetRequestResults(string key);
    Task Store(string redisKey, List<CreditCardRecommendation> cards);

}
