using backend.Data;
using backend.Services;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddOpenApi();

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.AddScoped<TripService>();
builder.Services.AddScoped<RouteService>();
builder.Services.AddScoped<SeedService>();

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

if (app.Configuration.GetValue<bool>("Database:AutoMigrate"))
{
    using var scope = app.Services.CreateScope();
    await scope.ServiceProvider.GetRequiredService<AppDbContext>().Database.MigrateAsync();
}

if (app.Configuration.GetValue<bool>("Seed:Suppliers"))
{
    using var scope = app.Services.CreateScope();
    await scope.ServiceProvider.GetRequiredService<SeedService>().SeedSuppliersAsync();
}

if (app.Configuration.GetValue<bool>("Seed:ResetToday"))
{
    using var scope = app.Services.CreateScope();
    await scope.ServiceProvider.GetRequiredService<SeedService>().ResetTodayAsync();
}

if (app.Configuration.GetValue<bool>("Seed:History"))
{
    using var scope = app.Services.CreateScope();
    await scope.ServiceProvider.GetRequiredService<SeedService>().SeedHistoryAsync();
}

if (app.Configuration.GetValue<bool>("Seed:SupplierDetails"))
{
    using var scope = app.Services.CreateScope();
    await scope.ServiceProvider.GetRequiredService<SeedService>().SeedSupplierDetailsAsync();
}

app.UseCors("AllowAll");
app.UseHttpsRedirection();
app.MapControllers();
app.Run();
