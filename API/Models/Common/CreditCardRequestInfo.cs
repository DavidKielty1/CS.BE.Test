using System.Text.Json.Serialization;

namespace API.Models.Common
{
    public class CreditCardRequestInfo
    {
        [JsonPropertyName("name")]
        public string Name { get; set; } = "";

        [JsonPropertyName("score")]
        public int Score { get; set; }

        [JsonPropertyName("salary")]
        public int Salary { get; set; }
    }
}