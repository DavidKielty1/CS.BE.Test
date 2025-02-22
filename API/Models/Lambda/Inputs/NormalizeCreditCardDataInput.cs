namespace API.Models.Lambda.Inputs;

using System.Text.Json.Serialization;
using API.Models.Common;

public class NormalizeCreditCardDataInput
{
    [JsonPropertyName("cards")]
    public List<CreditCardRecommendation> Cards { get; set; } = new();
}