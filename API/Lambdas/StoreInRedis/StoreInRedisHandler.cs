using API.Models.Lambda.Inputs;
using API.Services.Core.Handlers;
using API.Services.Core.Utils;
using API.Services.Cache.Interfaces;
using Amazon.Lambda.Core;
using Amazon.Lambda.Serialization.SystemTextJson;
using StackExchange.Redis;

namespace API.Lambdas.StoreInRedis
{
    public class StoreInRedisHandler : LambdaHandler<StoreInput, object>
    {
        private readonly IRedisCacheService _redisCacheService;
        private readonly ILogger<StoreInRedisHandler> _storeLogger;

        public StoreInRedisHandler() : base()
        {
            _redisCacheService = _serviceProvider.GetRequiredService<IRedisCacheService>();
            _storeLogger = _serviceProvider.GetRequiredService<ILogger<StoreInRedisHandler>>();
        }

        [LambdaSerializer(typeof(DefaultLambdaJsonSerializer))]
        protected override async Task<object> ProcessRequest(StoreInput input, ILambdaContext context)
        {
            try
            {
                _storeLogger.LogInformation("Storing {Count} cards in Redis", input.Cards.Count);
                var key = KeyBuilder.BuildKey(
                    input.Request.Name,
                    input.Request.Score,
                    input.Request.Salary);

                await _redisCacheService.SetAsync(key, input.Cards);
                _storeLogger.LogInformation("Successfully stored cards in Redis");

                return new
                {
                    success = true,
                    message = "Successfully stored cards",
                    cards = input.Cards,
                    cacheKey = key
                };
            }
            catch (RedisConnectionException ex)
            {
                _storeLogger.LogWarning(ex, "Failed to store in Redis, continuing with response");
                return new
                {
                    success = false,
                    message = "Redis storage failed but continuing",
                    cards = input.Cards,
                    error = ex.Message
                };
            }
            catch (Exception ex)
            {
                _storeLogger.LogError(ex, "Unexpected error storing in Redis");
                return new
                {
                    success = false,
                    message = "Failed to store cards but continuing",
                    cards = input.Cards,
                    error = ex.Message
                };
            }
        }
    }
}
