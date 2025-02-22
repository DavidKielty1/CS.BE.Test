using Amazon.Lambda.Core;
using API.Models.Common;
using API.Models.CardProviders;
using API.Services.CardProviders.Interfaces;
using API.Utils;
using API.Services.Processing.Interfaces;

namespace API.Services.CardProviders;

public class CSCardsProvider : ICardProvider
{
    private readonly ApiService _api;
    private readonly string _endpoint;
    private readonly ILogger<CSCardsProvider> _logger;
    private readonly IRequestProcessor _requestProcessor;
    private readonly IResponseProcessor _responseProcessor;

    public string ProviderName => "CSCards";

    public CSCardsProvider(ApiService api, IConfiguration configuration, ILogger<CSCardsProvider> logger, IRequestProcessor requestProcessor, IResponseProcessor responseProcessor)
    {
        _api = api;
        _endpoint = configuration["CSCARDS_ENDPOINT"]
            ?? throw new InvalidOperationException("CSCARDS_ENDPOINT not set");
        _logger = logger;
        _requestProcessor = requestProcessor;
        _responseProcessor = responseProcessor;
    }

    public async Task<List<CreditCardRecommendation>> GetRecommendations(
        CreditCardRequest request,
        ILambdaContext context)
    {
        try
        {
            var csRequest = _requestProcessor.ProcessCSCardsRequest(request);
            var response = await _api.SendRequest<CSCardsResponse>(_endpoint, csRequest);
            return _responseProcessor.ProcessCSCardsResponse(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching from CSCards. Request: {@Request}", request);
            throw;
        }
    }
}