using Amazon.SimpleNotificationService;
using Amazon.SQS;
using Amazon.Lambda.SNSEvents;
using Amazon.Lambda.Core;
using Amazon.Lambda.APIGatewayEvents;
using Amazon.Lambda.Serialization.SystemTextJson;
using API.Models.Common;
using API.Models.Lambda.Inputs;
using API.Services.Core.Handlers;
using API.Services.Aws.Interfaces;
using System.Text.Json;

namespace API.Lambdas.PublishToSNS
{
    public class PublishToSNSHandler : LambdaHandler<SNSInput, object>
    {
        private readonly IAwsMessagingService _messagingService;

        // Required by Lambda
        public PublishToSNSHandler() : base()
        {
            _messagingService = _serviceProvider.GetRequiredService<IAwsMessagingService>();
        }

        public PublishToSNSHandler(IServiceProvider serviceProvider)
            : base(serviceProvider)
        {
            _messagingService = serviceProvider.GetRequiredService<IAwsMessagingService>();
        }

        [LambdaSerializer(typeof(DefaultLambdaJsonSerializer))]
        protected override async Task<object> ProcessRequest(SNSInput input, ILambdaContext context)
        {
            var request = new PublishToSNSRequestModel
            {
                Cards = input.Cards,
                NotificationType = input.NotificationType,
                Request = input.Request ?? new CreditCardRequestInfo()
            };

            await _messagingService.PublishMessageAsync(request);

            return new { message = "Published to SNS", cards = input.Cards };
        }
    }
}