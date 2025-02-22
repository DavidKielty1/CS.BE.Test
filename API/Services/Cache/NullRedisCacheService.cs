using API.Services.Cache.Interfaces;
using API.Models.Common;

namespace API.Services.Cache;

public class NullRedisCacheService : IRedisCacheService
{
    public Task<T?> GetAsync<T>(string key) where T : class => Task.FromResult<T?>(null);
    public Task SetAsync<T>(string key, T value) where T : class => Task.CompletedTask;
    public Task RemoveAsync(string key) => Task.CompletedTask;
    public Task<List<CreditCardRecommendation>> GetRequestResults(string key) => Task.FromResult(new List<CreditCardRecommendation>());
    public Task Store(string redisKey, List<CreditCardRecommendation> cards) => Task.CompletedTask;
}
