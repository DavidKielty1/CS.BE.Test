using System.Text.Json.Serialization;

namespace API.Models.CardProviders
{
    public class CSCardsRequest
    {
        [JsonPropertyName("name")]
        public string Name { get; set; } = "";

        [JsonPropertyName("creditScore")]
        public int CreditScore { get; set; }
    }

    public class CSCardsResponse
    {
        [JsonPropertyName("cards")]
        public List<CSCard> Cards { get; set; } = new();
    }

    public class CSCard
    {
        [JsonPropertyName("apr")]
        public double Apr { get; set; }

        [JsonPropertyName("cardName")]
        public string CardName { get; set; } = "";

        [JsonPropertyName("eligibility")]
        public double Eligibility { get; set; }
    }
}