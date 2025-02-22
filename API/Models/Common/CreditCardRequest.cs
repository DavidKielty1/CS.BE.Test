namespace API.Models.Common
{
    using System.Text.Json.Serialization;

    public class CreditCardRequest
    {
        [JsonPropertyName("name")]
        public string Name { get; set; } = "";

        [JsonPropertyName("score")]
        public int Score { get; set; }

        [JsonPropertyName("salary")]
        public int Salary { get; set; }
    }
}