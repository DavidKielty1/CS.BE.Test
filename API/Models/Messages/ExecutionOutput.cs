using API.Models.Common;
using System.Text.Json.Serialization;

namespace API.Models.Messages;

public class ExecutionOutput
{
    [JsonPropertyName("cards")]
    public List<CreditCardRecommendation> Cards { get; set; } = new();

    [JsonPropertyName("status")]
    public string Status { get; set; } = string.Empty;
}