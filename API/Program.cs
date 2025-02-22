using API;
using API.Services.Core.Handlers;

var builder = WebApplication.CreateBuilder(args);

Console.WriteLine("Starting application initialization...");

// Configure logging first
builder.Logging.ClearProviders();
builder.Logging.AddConsole();
builder.Logging.SetMinimumLevel(LogLevel.Debug);

var logger = LoggerFactory.Create(config =>
{
    config.AddConsole();
    config.SetMinimumLevel(LogLevel.Debug);
}).CreateLogger("Startup");

logger.LogInformation("Configuring services...");

// Configure services
builder.ConfigureServices();

logger.LogInformation("Building application...");
var app = builder.Build();

logger.LogInformation("Initializing Lambda handler...");
var serviceProvider = app.Services;
await LambdaInitializer.Initialize(serviceProvider);

logger.LogInformation("Configuring pipeline...");
app.ConfigurePipeline();

logger.LogInformation("Starting web server...");
app.Run();
