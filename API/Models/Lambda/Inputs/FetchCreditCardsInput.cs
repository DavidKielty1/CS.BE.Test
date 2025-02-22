namespace API.Models.Lambda.Inputs;

using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

public class FetchCreditCardsInput
{
    [Required(ErrorMessage = "Name is required")]
    [StringLength(100, MinimumLength = 1)]
    [JsonPropertyName("name")]
    public string Name { get; set; } = "";

    [Range(0, 700, ErrorMessage = "Credit score must be between 0 and 700")]
    [JsonPropertyName("score")]
    public int Score { get; set; }

    [Range(0, int.MaxValue, ErrorMessage = "Salary cannot be negative")]
    [JsonPropertyName("salary")]
    public int Salary { get; set; }
}