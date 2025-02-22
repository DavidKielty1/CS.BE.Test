using Microsoft.AspNetCore.Mvc;
using API.Models.Common;
using API.Services.Aws.Interfaces;
using API.Services.Cache.Interfaces;
using API.Services.Core.Utilities;
using API.Services.CardProviders;

namespace API.Controllers
{
    [ApiController]
    [Route("api/credit-cards")]
    public class CreditCardController : ControllerBase
    {
        private readonly IAwsMessagingService _messagingService;
        private readonly IRedisCacheService _redisCacheService;
        private readonly ILogger<CreditCardController> _logger;
        private readonly CSCardsProvider _csCardsProvider;

        public CreditCardController(
            IAwsMessagingService messagingService,
            IRedisCacheService redisCacheService,
            ILogger<CreditCardController> logger,
            CSCardsProvider csCardsProvider)
        {
            _messagingService = messagingService;
            _redisCacheService = redisCacheService;
            _logger = logger;
            _csCardsProvider = csCardsProvider;
        }





        [HttpPost("process")]
        public async Task<IActionResult> ProcessCreditCard([FromBody] CreditCardRequest request)
        {


            try
            {
                // TESTING ENDPOINT ----------------------- !!!!!
                // TESTING ENDPOINT 
                // TESTING ENDPOINT
                // try
                // {
                //     _logger.LogInformation("Direct CSCards test request: {@Request}", request);

                //     // Call CSCards directly
                //     var cards = await _csCardsProvider.GetRecommendations(request, null!);

                //     return Ok(new
                //     {
                //         Success = true,
                //         Cards = cards
                //     });
                // }
                // catch (HttpRequestException ex)
                // {
                //     _logger.LogError(ex, "CSCards API error: {Message}", ex.Message);
                //     return StatusCode((int?)ex.StatusCode ?? 500, new
                //     {
                //         Success = false,
                //         Error = ex.Message
                //     });
                // }
                // catch (Exception ex)
                // {
                //     _logger.LogError(ex, "Error testing CSCards: {Message}", ex.Message);
                //     return StatusCode(500, new
                //     {
                //         Success = false,
                //         Error = ex.Message
                //     });
                // }
                // TESTING ENDPOINT
                // TESTING ENDPOINT
                // TESTING ENDPOINT ----------------------- !!!!!

                var redisKey = RequestNormalizer.BuildRedisKey(request.Name, request.Score, request.Salary);
                _logger.LogInformation("Generated Redis key: {RedisKey}", redisKey);

                // Check cache first
                _logger.LogInformation("Checking Redis cache for key: {RedisKey}", redisKey);
                var cachedResults = await _redisCacheService.GetRequestResults(redisKey);
                if (cachedResults.Any())
                {
                    _logger.LogInformation("Cache hit! Found {Count} cards for {Name}", cachedResults.Count, request.Name);
                    return Ok(cachedResults);
                }
                _logger.LogInformation("Cache miss for {Name}, proceeding with providers", request.Name);

                var executionArn = await _messagingService.StartStateMachineAsync(request);
                _logger.LogInformation("State machine started. ARN: {ExecutionArn}", executionArn);


                var result = await _messagingService.GetExecutionResult(executionArn);
                _logger.LogInformation("State machine execution completed. Result: {@Result}", result);

                return Ok(result);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing credit card request: {@Request}", request);
                return StatusCode(500, new { message = "Internal server error" });
            }
        }
    }
}
