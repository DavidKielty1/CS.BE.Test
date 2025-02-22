using System.Text.Json.Serialization;
using API.Models.Common;

namespace API.Models.Lambda.Inputs
{
    public class SNSInput
    {
        public string NotificationType { get; set; } = "UNKNOWN";
        public string Message { get; set; } = "Processing completed";
        public List<CreditCardRecommendation> Cards { get; set; } = [];
        public CreditCardRequestInfo? Request { get; set; }
    }

    public class SQSInput
    {
        [JsonPropertyName("messageBody")]
        public string MessageBody { get; set; } = string.Empty;

        [JsonPropertyName("queueUrl")]
        public string QueueUrl { get; set; } = string.Empty;
    }

    public class StoreInput
    {
        [JsonPropertyName("request")]
        public CreditCardRequest Request { get; set; } = new();

        [JsonPropertyName("cards")]
        public List<CreditCardRecommendation> Cards { get; set; } = [];
    }

    public class NormalizeInput
    {
        public List<CreditCardRecommendation> Cards { get; set; } = [];
    }

    public class StoreInRedisRequestModel
    {
        // Model for storing normalized credit card data in Redis
        [JsonPropertyName("cards")]
        public List<CreditCardRecommendation> Cards { get; set; } = [];

        [JsonPropertyName("request")]
        public CreditCardRequest Request { get; set; } = new();
    }

    public class PublishToSNSRequestModel
    {
        // Model for publishing credit card recommendations to SNS/SQS
        [JsonPropertyName("cards")]
        public List<CreditCardRecommendation> Cards { get; set; } = [];

        [JsonPropertyName("notificationType")]
        public string NotificationType { get; set; } = "";

        [JsonPropertyName("request")]
        public CreditCardRequestInfo Request { get; set; } = new();

        // Constructor to handle direct array input
        [JsonConstructor]
        public PublishToSNSRequestModel() { }
    }
}