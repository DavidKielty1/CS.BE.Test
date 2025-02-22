using System.Text.Json.Serialization;

namespace API.Models.Lambda.Outputs
{
    public class ExecutionOutput
    {
        [JsonPropertyName("message")]
        public string Message { get; set; } = "";

        [JsonPropertyName("cards")]
        public List<Common.CreditCardRecommendation> Cards { get; set; } = [];
    }


}