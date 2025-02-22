using API.Services.Aws;
using API.Services.Aws.Interfaces;
using API.Services.CardProviders.Interfaces;
using API.Services.Processing;
using API.Services.Processing.Interfaces;
using Amazon.SimpleNotificationService;
using Amazon.SQS;
using Amazon.StepFunctions;
using FluentValidation;
using API.Services.Core.Validation;
using Microsoft.Extensions.Caching.Memory;
using API.Services.CardProviders;
using StackExchange.Redis;
using API.Services.Cache.Interfaces;
using API.Services.Cache;

namespace API.Services.Core.Configuration;

public static class ServiceConfiguration
{
    private static readonly TimeSpan DefaultTimeout = TimeSpan.FromSeconds(5);
    private static readonly int MaxConnections = 50;
    private static readonly TimeSpan ConnectionLifetime = TimeSpan.FromMinutes(5);

    public static IServiceCollection AddApplicationServices(this IServiceCollection services, IConfiguration configuration)
    {
        // Register configuration
        services.AddSingleton<IConfiguration>(configuration);

        // Configure logging
        services.AddLogging(logging =>
        {
            logging.ClearProviders();
            logging.AddConsole();
            logging.AddDebug();
            logging.SetMinimumLevel(Microsoft.Extensions.Logging.LogLevel.Information);
        });

        // AWS Services with optimized settings
        services.AddSingleton<IAmazonSimpleNotificationService, AmazonSimpleNotificationServiceClient>();
        services.AddSingleton<IAmazonSQS, AmazonSQSClient>();
        services.AddSingleton<IAmazonStepFunctions, AmazonStepFunctionsClient>();

        // Add AWS messaging service with caching
        services.AddSingleton<IAwsMessagingService, AwsMessagingService>();
        services.AddSingleton<IAwsStepFunctionsService, AwsStepFunctionsService>();
        services.AddSingleton<IMemoryCache, MemoryCache>();

        // Card Providers
        services.AddSingleton<ICardProviderFactory, CardProviderFactory>();
        services.AddTransient<CSCardsProvider>();
        services.AddTransient<ScoredCardsProvider>();
        services.AddHttpClient<ApiService>();

        // Configure HTTP client with optimized settings
        services.AddHttpClient<ApiService>(client =>
        {
            client.DefaultRequestHeaders.Add("Accept-Encoding", "gzip");
            client.DefaultRequestHeaders.Add("User-Agent", "ClearScore-Test/1.0");
        })
        .ConfigurePrimaryHttpMessageHandler(() => new SocketsHttpHandler
        {
            // PooledConnectionLifetime = ConnectionLifetime,
            AllowAutoRedirect = true,
            // MaxConnectionsPerServer = MaxConnections,
            EnableMultipleHttp2Connections = false,
            KeepAlivePingPolicy = HttpKeepAlivePingPolicy.WithActiveRequests,
            PooledConnectionLifetime = TimeSpan.FromMinutes(1),
            PooledConnectionIdleTimeout = TimeSpan.FromMinutes(30),
            MaxConnectionsPerServer = 10,
            UseCookies = false,
            MaxResponseDrainSize = 1024,
            AutomaticDecompression = System.Net.DecompressionMethods.GZip | System.Net.DecompressionMethods.Deflate
        });

        // Processors
        services.AddSingleton<IRequestProcessor, RequestProcessor>();
        services.AddSingleton<IResponseProcessor, Processing.ResponseProcessor>();

        // Validators
        services.AddValidatorsFromAssemblyContaining<CreditCardRequestValidator>();

        // Add Redis caching
        var redisConnection = configuration.GetValue<string>("Redis:ConnectionString");
        var redisHost = configuration.GetValue<string>("Redis:Host");
        var redisPassword = configuration.GetValue<string>("Redis:Password");

        if (!string.IsNullOrEmpty(redisHost))
        {
            var redisConfig = new ConfigurationOptions
            {
                EndPoints = { redisHost },
                Password = redisPassword,
                AbortOnConnectFail = false,  // Don't throw on connection failure
                ConnectRetry = 3,            // Retry connection attempts
                ConnectTimeout = 5000,       // 5 seconds
                SyncTimeout = 5000,
                AllowAdmin = false,
                ClientName = "API",
                ReconnectRetryPolicy = new ExponentialRetry(5000),
                KeepAlive = 60,
                DefaultDatabase = 0
            };

            services.AddSingleton<IConnectionMultiplexer>(sp =>
                ConnectionMultiplexer.Connect(redisConfig));

            services.AddSingleton<IRedisCacheService>(sp =>
            {
                var multiplexer = sp.GetService<IConnectionMultiplexer>();
                if (multiplexer != null)
                {
                    return new RedisCacheService(
                        multiplexer,
                        sp.GetRequiredService<ILogger<RedisCacheService>>()
                    );
                }
                return new NullRedisCacheService();
            });
        }
        else
        {
            services.AddSingleton<IRedisCacheService, NullRedisCacheService>();
        }

        return services;
    }

    // Add method to warm up services
    public static async Task WarmupServices(IServiceProvider services)
    {
        try
        {
            // Pre-initialize singletons
            var factory = services.GetRequiredService<ICardProviderFactory>();
            var messaging = services.GetRequiredService<IAwsMessagingService>();

            // Simple warmup ping
            var httpClient = services.GetRequiredService<HttpClient>();
            await httpClient.GetAsync("https://api.clearscore.com/health");
        }
        catch (Exception ex)
        {
            var loggerFactory = services.GetRequiredService<ILoggerFactory>();
            var logger = loggerFactory.CreateLogger("Startup");
            logger.LogWarning(ex, "Warmup failed but service can still start");
        }
    }

}
