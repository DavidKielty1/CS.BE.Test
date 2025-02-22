using Microsoft.Extensions.Configuration;
using System.IO;

public static class ConfigurationLoader
{
    public static IConfiguration LoadConfiguration(string environment)
    {
        var builder = new ConfigurationBuilder()
            .SetBasePath(Directory.GetCurrentDirectory())
            .AddJsonFile("appsettings.json", optional: false)
            .AddJsonFile($"appsettings.{environment}.json", optional: true)
            .AddEnvironmentVariables();

        return builder.Build();
    }
}