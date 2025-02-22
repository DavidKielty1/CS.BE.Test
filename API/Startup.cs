using API.Services.Core.Configuration;
using FluentValidation;

namespace API;

public static class Startup
{
    public static WebApplicationBuilder ConfigureServices(this WebApplicationBuilder builder)
    {
        // Add controllers and API features
        builder.Services
            .AddControllers()
            .AddNewtonsoftJson();

        // Add Swagger/OpenAPI
        builder.Services.AddEndpointsApiExplorer();
        builder.Services.AddSwaggerGen();

        // Add AWS services
        builder.Services.AddAWSService<Amazon.SimpleNotificationService.IAmazonSimpleNotificationService>();
        builder.Services.AddAWSService<Amazon.SQS.IAmazonSQS>();
        builder.Services.AddAWSService<Amazon.StepFunctions.IAmazonStepFunctions>();

        // Add application services
        builder.Services.AddApplicationServices(builder.Configuration);

        // Add HTTP client
        builder.Services.AddHttpClient();

        // Add validators
        builder.Services.AddValidatorsFromAssembly(typeof(Startup).Assembly);

        // Add CORS
        builder.Services.AddCors(options =>
        {
            options.AddPolicy("AllowAll", policy =>
            {
                policy.AllowAnyOrigin()
                      .AllowAnyMethod()
                      .AllowAnyHeader();
            });
        });

        return builder;
    }

    public static WebApplication ConfigurePipeline(this WebApplication app)
    {
        if (app.Environment.IsDevelopment())
        {
            app.UseSwagger();
            app.UseSwaggerUI();
            app.UseDeveloperExceptionPage();
        }
        else
        {
            app.UseExceptionHandler("/error");
            app.UseHsts();
        }

        app.UseHttpsRedirection();
        app.UseCors("AllowAll");
        app.UseAuthentication();
        app.UseAuthorization();
        app.MapControllers();

        return app;
    }
}