using System.Text.Json.Serialization;

namespace API.Models.Messages
{
    public class FailedRequestMessage
    {
        [JsonPropertyName("provider")]
        public string Provider { get; set; } = string.Empty;

        [JsonPropertyName("request")]
        public Common.CreditCardRequest Request { get; set; } = new();

        [JsonPropertyName("timestamp")]
        public DateTime Timestamp { get; set; }

        [JsonPropertyName("error")]
        public string? Error { get; set; }

        [JsonPropertyName("failedProvider")]
        public string? FailedProvider { get; set; }
    }
}