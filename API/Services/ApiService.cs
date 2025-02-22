using System.Net.Http.Headers;
using System.Text.Json;
using System.Text;
using API.Models.CardProviders;

namespace API.Services
{
    public class ApiService
    {
        private readonly HttpClient _client;
        private readonly ILogger<ApiService> _logger;

        public ApiService(HttpClient client, ILogger<ApiService> logger)
        {
            _client = client;
            _logger = logger;
        }

        public async Task<T> SendRequest<T>(string endpoint, object request)
        {
            try
            {
                var requestBody = JsonSerializer.Serialize(request, new JsonSerializerOptions
                {
                    PropertyNamingPolicy = JsonNamingPolicy.CamelCase
                });

                var requestMessage = new HttpRequestMessage(HttpMethod.Post, endpoint)
                {
                    Content = new StringContent(requestBody, Encoding.UTF8, "application/json")
                };

                _logger.LogInformation("Request: {Endpoint} {Body}", endpoint, requestBody);

                var response = await _client.SendAsync(requestMessage);
                var content = await response.Content.ReadAsStringAsync();

                _logger.LogInformation("Response: Status {Status} Content: {Content}",
                    (int)response.StatusCode,
                    content);

                if (!response.IsSuccessStatusCode)
                {
                    throw new HttpRequestException($"API returned {(int)response.StatusCode}: {content}");
                }

                if (typeof(T) == typeof(CSCardsResponse))
                {
                    content = $"{{\"cards\":{content}}}";
                }

                return JsonSerializer.Deserialize<T>(content, new JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                }) ?? throw new InvalidOperationException("Failed to deserialize response");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Request failed");
                throw;
            }
        }
    }
}