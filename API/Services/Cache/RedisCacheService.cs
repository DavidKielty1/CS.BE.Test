using System.Text.Json;
using API.Models.Common;
using StackExchange.Redis;
using API.Services.Cache.Interfaces;

namespace API.Services.Cache;

public class RedisCacheService : IRedisCacheService
{
    private const int DEFAULT_EXPIRY_MINUTES = 10;
    private readonly IDatabase _db;
    private readonly ILogger<RedisCacheService> _logger;
    private readonly JsonSerializerOptions _jsonOptions;
    private readonly IConnectionMultiplexer _redis;
    private static readonly ConfigurationOptions RedisConfig = new()
    {
        EndPoints = { "52.56.244.42:6379" },
        ConnectTimeout = 1000,        // 1 second
        SyncTimeout = 1000,           // 1 second
        AbortOnConnectFail = false,
        ConnectRetry = 0,             // No retries
        KeepAlive = 60,
        AllowAdmin = false,
    };

    public RedisCacheService(
        IConnectionMultiplexer redis,
        ILogger<RedisCacheService> logger)
    {
        _redis = redis;
        _db = redis.GetDatabase();
        _logger = logger;
        _jsonOptions = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
    }

    public async Task Store(string key, List<CreditCardRecommendation> cards)
    {
        try
        {
            var json = JsonSerializer.Serialize(cards);
            await _db.StringSetAsync(
                key,
                json,
                TimeSpan.FromMinutes(DEFAULT_EXPIRY_MINUTES)
            );
            _logger.LogInformation("Successfully stored data for key: {Key}", key);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to store data for key: {Key}", key);
            throw;
        }
    }

    public async Task SetAsync<T>(string key, T value) where T : class
    {
        _logger.LogInformation("Attempting to set Redis key: {Key}", key);
        if (!_redis.IsConnected)
        {
            _logger.LogWarning("Redis not connected. Skip setting key: {Key}", key);
            return;
        }

        try
        {
            var serialized = JsonSerializer.Serialize(value, _jsonOptions);
            _logger.LogDebug("Setting Redis value: {Key} = {@Value}", key, value);
            await _db.StringSetAsync(key, serialized, TimeSpan.FromMinutes(DEFAULT_EXPIRY_MINUTES));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error setting Redis key: {Key}", key);
            throw;
        }
    }

    public async Task<T?> GetAsync<T>(string key) where T : class
    {
        _logger.LogInformation("Attempting to get from Redis. Key: {Key}", key);
        if (!_redis.IsConnected)
        {
            _logger.LogWarning("Redis not connected. Returning null for key: {Key}", key);
            return null;
        }

        try
        {
            var value = await _db.StringGetAsync(key);
            if (!value.HasValue)
            {
                _logger.LogDebug("Cache miss for key: {Key}", key);
                return null;
            }

            _logger.LogDebug("Cache hit for key: {Key}", key);
            return JsonSerializer.Deserialize<T>(value.ToString(), _jsonOptions);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving from Redis. Key: {Key}", key);
            return null;
        }
    }

    public async Task RemoveAsync(string key)
    {
        await _db.KeyDeleteAsync(key);
    }

    public async Task<List<CreditCardRecommendation>> GetRequestResults(string key)
    {
        if (!_redis.IsConnected) return new List<CreditCardRecommendation>();

        try
        {
            var value = await _db.StringGetAsync(key).WaitAsync(TimeSpan.FromSeconds(1));
            return value.HasValue
                ? JsonSerializer.Deserialize<List<CreditCardRecommendation>>(value.ToString(), _jsonOptions)
                    ?? new List<CreditCardRecommendation>()
                : new List<CreditCardRecommendation>();
        }
        catch
        {
            return new List<CreditCardRecommendation>();
        }
    }
}