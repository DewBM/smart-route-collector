using backend.Data;
using backend.DTOs;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace backend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class InsightsController : ControllerBase
{
    private readonly AppDbContext _db;

    public InsightsController(AppDbContext db)
    {
        _db = db;
    }

    /// <summary>Aggregated collection stats for the last <paramref name="days"/> days.</summary>
    [HttpGet]
    public async Task<IActionResult> Get([FromQuery] int days = 7)
    {
        try
        {
            days = Math.Clamp(days, 1, 90);
            var today = DateOnly.FromDateTime(
                TimeZoneInfo.ConvertTimeBySystemTimeZoneId(DateTime.UtcNow, "Asia/Colombo"));
            var from = today.AddDays(-(days - 1));

            var trips = await _db.Trips
                .Where(t => t.TripDate >= from && t.TripDate <= today)
                .Include(t => t.TripStops).ThenInclude(ts => ts.Supplier)
                .Include(t => t.TripStops).ThenInclude(ts => ts.Collection)
                .ToListAsync();

            var collected = trips
                .SelectMany(t => t.TripStops.Select(ts => new { Trip = t, Stop = ts }))
                .Where(x => x.Stop.Collection != null)
                .ToList();

            var shortfalls = collected.Count(x =>
                x.Stop.Collection!.ClearKg < x.Stop.Supplier.ExpectedClearKg ||
                x.Stop.Collection!.ColouredKg < x.Stop.Supplier.ExpectedColouredKg);

            var totalClear = collected.Sum(x => x.Stop.Collection!.ClearKg);
            var totalColoured = collected.Sum(x => x.Stop.Collection!.ColouredKg);

            // One entry per calendar day in the window, including empty days.
            var daily = Enumerable.Range(0, days)
                .Select(i => from.AddDays(i))
                .Select(d => new DailyTotalDto
                {
                    Date = d.ToString("yyyy-MM-dd"),
                    ClearKg = collected.Where(x => x.Trip.TripDate == d)
                        .Sum(x => x.Stop.Collection!.ClearKg),
                    ColouredKg = collected.Where(x => x.Trip.TripDate == d)
                        .Sum(x => x.Stop.Collection!.ColouredKg)
                })
                .ToList();

            var top = collected
                .GroupBy(x => x.Stop.Supplier.Name)
                .Select(g => new SupplierTotalDto
                {
                    Name = g.Key,
                    TotalKg = g.Sum(x => x.Stop.Collection!.ClearKg + x.Stop.Collection!.ColouredKg)
                })
                .OrderByDescending(s => s.TotalKg)
                .Take(5)
                .ToList();

            return Ok(new InsightsDto
            {
                Days = days,
                TripCount = trips.Count,
                StopCount = collected.Count,
                SkippedCount = trips.Sum(t => t.TripStops.Count(ts => ts.Status == "Skipped")),
                TotalClearKg = totalClear,
                TotalColouredKg = totalColoured,
                TotalDistanceKm = trips.Sum(t => t.TotalDistanceKm),
                AverageKgPerStop = collected.Count == 0
                    ? 0
                    : (totalClear + totalColoured) / collected.Count,
                ShortfallRate = collected.Count == 0 ? 0 : (double)shortfalls / collected.Count,
                Daily = daily,
                TopSuppliers = top
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }
}
