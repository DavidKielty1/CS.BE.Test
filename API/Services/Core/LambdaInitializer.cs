using Microsoft.Extensions.DependencyInjection;
using API.Services.Core.Configuration;
using Microsoft.Extensions.Logging;
using Amazon.Lambda.Logging.AspNetCore;

namespace API.Services.Core.Handlers;

public static class LambdaInitializer
{
    private static IServiceProvider? _serviceProvider;
    private static readonly SemaphoreSlim _initLock = new(1, 1);

    public static Task Initialize(IServiceProvider serviceProvider)
    {
        if (_serviceProvider != null) return Task.CompletedTask;

        _serviceProvider = serviceProvider;
        return Task.CompletedTask;
    }

    public static async Task<IServiceProvider> GetServiceProvider()
    {
        if (_serviceProvider != null) return _serviceProvider;

        await _initLock.WaitAsync();
        try
        {
            if (_serviceProvider != null) return _serviceProvider;

            var services = new ServiceCollection();
            var configuration = new ConfigurationBuilder()
                .SetBasePath(Directory.GetCurrentDirectory())
                .AddJsonFile("appsettings.json", optional: true)
                .AddEnvironmentVariables()
                .Build();

            // Configure logging for Lambda
            services.AddLogging(logging =>
            {
                logging.ClearProviders();
                logging.AddLambdaLogger(new LambdaLoggerOptions
                {
                    IncludeCategory = true,
                    IncludeLogLevel = true,
                    IncludeNewline = true,
                    IncludeEventId = true,
                    IncludeException = true
                });
                logging.SetMinimumLevel(LogLevel.Debug);
            });

            services.AddApplicationServices(configuration);
            _serviceProvider = services.BuildServiceProvider();

            return _serviceProvider;
        }
        finally
        {
            _initLock.Release();
        }
    }

    public static T GetAwsClient<T>() where T : class
    {
        return _serviceProvider?.GetRequiredService<T>()
            ?? throw new InvalidOperationException($"AWS client {typeof(T).Name} not initialized");
    }
}