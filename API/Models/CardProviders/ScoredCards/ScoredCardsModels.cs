using System.Text.Json.Serialization;

namespace API.Models.CardProviders
{
    public class ScoredCardsRequest
    {
        [JsonPropertyName("name")]
        public string Name { get; set; } = "";

        [JsonPropertyName("score")]
        public int Score { get; set; }

        [JsonPropertyName("salary")]
        public int Salary { get; set; }
    }

    public class ScoredCardsResponse
    {
        public List<ScoredCard> Cards { get; set; } = new();
    }

    public class ScoredCard
    {
        [JsonPropertyName("card")]
        public string Card { get; set; } = "";

        [JsonPropertyName("apr")]
        public double Apr { get; set; }
        [JsonPropertyName("approvalRating")]
        public double ApprovalRating { get; set; }
    }
}