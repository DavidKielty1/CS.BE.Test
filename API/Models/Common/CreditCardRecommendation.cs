namespace API.Models.Common
{
    public class CreditCardRecommendation
    {
        public string Provider { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public decimal Apr { get; set; }
        public int CardScore { get; set; }
    }
}