using System.Text.Json;
using Amazon.Lambda.Core;
using Amazon.Lambda.APIGatewayEvents;
using Amazon.Lambda.Logging.AspNetCore;
using API.Services.Processing.Interfaces;
using FluentValidation;
using Microsoft.Extensions.Logging;

namespace API.Services.Core.Handlers;

public abstract class LambdaHandler<TInput, TOutput>
{
    protected readonly IServiceProvider _serviceProvider;
    protected readonly ILogger<LambdaHandler<TInput, TOutput>> _logger;
    protected readonly IRequestProcessor _requestProcessor;
    protected readonly IResponseProcessor _responseProcessor;
    protected readonly IValidator<TInput>? _validator;

    // Constructor for Lambda runtime
    protected LambdaHandler()
    {
        _serviceProvider = LambdaInitializer.GetServiceProvider().GetAwaiter().GetResult();

        // Configure logging for Lambda environment
        var loggerFactory = LoggerFactory.Create(builder =>
        {
            builder.AddLambdaLogger();
            builder.SetMinimumLevel(Microsoft.Extensions.Logging.LogLevel.Debug);
        });

        _logger = loggerFactory.CreateLogger<LambdaHandler<TInput, TOutput>>();
        _requestProcessor = _serviceProvider.GetRequiredService<IRequestProcessor>();
        _responseProcessor = _serviceProvider.GetRequiredService<IResponseProcessor>();
        _validator = _serviceProvider.GetService<IValidator<TInput>>();
    }

    // Constructor for API usage
    protected LambdaHandler(IServiceProvider serviceProvider)
    {
        _serviceProvider = serviceProvider;
        _logger = serviceProvider.GetRequiredService<ILogger<LambdaHandler<TInput, TOutput>>>();
        _requestProcessor = serviceProvider.GetRequiredService<IRequestProcessor>();
        _responseProcessor = serviceProvider.GetRequiredService<IResponseProcessor>();
        _validator = serviceProvider.GetService<IValidator<TInput>>();
    }

    public async Task<APIGatewayProxyResponse> FunctionHandler(object input, ILambdaContext context)
    {
        try
        {
            var typedInput = DeserializeAndValidate(input);
            var result = await ProcessRequest(typedInput, context);
            return new APIGatewayProxyResponse
            {
                StatusCode = 200,
                Body = JsonSerializer.Serialize(result)
            };
        }
        catch (Exception ex) when (ex is not LambdaException)
        {
            _logger.LogError(ex, "Error processing request");
            return new APIGatewayProxyResponse
            {
                StatusCode = 500,
                Body = JsonSerializer.Serialize(new
                {
                    error = "PROCESSING_ERROR",
                    message = ex.Message,
                    type = typeof(TInput).Name
                })
            };
        }
    }

    protected abstract Task<TOutput> ProcessRequest(TInput input, ILambdaContext context);

    private TInput DeserializeAndValidate(object input)
    {
        var typedInput = input switch
        {
            string json => JsonSerializer.Deserialize<TInput>(json),
            { } obj => JsonSerializer.Deserialize<TInput>(
                JsonSerializer.Serialize(obj),
                new JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                }),
            _ => throw new ArgumentException("Invalid input format")
        } ?? throw new ArgumentException("Failed to deserialize input");

        if (_validator != null)
        {
            _validator.ValidateAndThrow(typedInput);
        }

        return typedInput;
    }
}