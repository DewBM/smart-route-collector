using backend.Data;
using backend.DTOs;
using backend.Models;
using backend.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace backend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class TripsController : ControllerBase
{
    private readonly TripService _tripService;
    private readonly AppDbContext _db;

    public TripsController(TripService tripService, AppDbContext db)
    {
        _tripService = tripService;
        _db = db;
    }

    [HttpGet("today")]
    public async Task<IActionResult> GetToday()
    {
        try
        {
            var trip = await _tripService.GetOrCreateTodaysTripAsync();

            var response = BuildTripResponse(trip);

            return Ok(response);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    /// <summary>
    /// Skip a stop (closed, no access, nothing to collect). The remaining route
    /// is re-optimised. Returns the updated trip.
    /// </summary>
    [HttpPost("{tripId:int}/stops/{supplierId:int}/skip")]
    public async Task<IActionResult> SkipStop(int tripId, int supplierId, [FromBody] SkipStopRequestDto request)
    {
        try
        {
            var trip = await _tripService.SkipStopAsync(
                tripId, supplierId, request.Reason.Trim(), request.Note?.Trim(), request.SkippedAt);
            return Ok(BuildTripResponse(trip));
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { error = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { error = ex.Message });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    private static TripResponseDto BuildTripResponse(Trip trip) => new()
    {
        TripId = trip.Id,
        TripDate = trip.TripDate.ToString(),
        TotalDistanceKm = trip.TotalDistanceKm,
        Stops = trip.TripStops
            .OrderBy(ts => ts.StopOrder)
            .Select(ts => new StopDto
            {
                SupplierId = ts.SupplierId,
                SupplierName = ts.Supplier.Name,
                Latitude = ts.Supplier.Latitude,
                Longitude = ts.Supplier.Longitude,
                BarcodeRef = ts.Supplier.BarcodeRef,
                ExpectedClearKg = ts.Supplier.ExpectedClearKg,
                ExpectedColouredKg = ts.Supplier.ExpectedColouredKg,
                Status = ts.Status,
                StopOrder = ts.StopOrder,
                DistanceFromPrevKm = ts.DistanceFromPrevKm,
                SkipReason = ts.SkipReason,
                Address = ts.Supplier.Address,
                ContactName = ts.Supplier.ContactName,
                Phone = ts.Supplier.Phone,
                Notes = ts.Supplier.Notes
            }).ToList()
    };

    [HttpGet("today/summary")]
    public async Task<IActionResult> GetSummary()
    {
        try
        {
            var today = DateOnly.FromDateTime(DateTime.UtcNow);
            var trip = await LoadTripAsync(t => t.TripDate == today);

            if (trip == null)
                return NotFound(new { error = "No trip found for today." });

            return Ok(BuildSummary(trip));
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    [HttpGet("{id:int}/summary")]
    public async Task<IActionResult> GetSummaryById(int id)
    {
        try
        {
            var trip = await LoadTripAsync(t => t.Id == id);

            if (trip == null)
                return NotFound(new { error = "Trip not found." });

            return Ok(BuildSummary(trip));
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    [HttpGet("history")]
    public async Task<IActionResult> GetHistory([FromQuery] int limit = 30)
    {
        try
        {
            limit = Math.Clamp(limit, 1, 100);

            var trips = await _db.Trips
                .Include(t => t.TripStops).ThenInclude(ts => ts.Supplier)
                .Include(t => t.TripStops).ThenInclude(ts => ts.Collection)
                .OrderByDescending(t => t.TripDate)
                .Take(limit)
                .ToListAsync();

            var items = trips.Select(t =>
            {
                var summary = BuildSummary(t);
                return new TripHistoryItemDto
                {
                    TripId = t.Id,
                    TripDate = t.TripDate.ToString("yyyy-MM-dd"),
                    TotalDistanceKm = t.TotalDistanceKm,
                    StopCount = t.TripStops.Count,
                    CollectedCount = t.TripStops.Count(ts => ts.Status == "Collected"),
                    SkippedCount = t.TripStops.Count(ts => ts.Status == "Skipped"),
                    IsComplete = t.TripStops.Count > 0 &&
                                 t.TripStops.All(ts => ts.Status == "Collected" || ts.Status == "Skipped"),
                    TotalKg = summary.TotalClearKg + summary.TotalColouredKg,
                    ShortfallCount = summary.Stops.Count(s => s.BelowExpected),
                    DurationMinutes = summary.DurationMinutes
                };
            }).ToList();

            return Ok(items);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    private Task<Trip?> LoadTripAsync(System.Linq.Expressions.Expression<Func<Trip, bool>> predicate) =>
        _db.Trips
            .Include(t => t.TripStops).ThenInclude(ts => ts.Supplier)
            .Include(t => t.TripStops).ThenInclude(ts => ts.Collection)
            .FirstOrDefaultAsync(predicate);

    internal static TripSummaryDto BuildSummary(Trip trip)
    {
        var stops = trip.TripStops.OrderBy(ts => ts.StopOrder).ToList();

        var stopSummaries = stops.Select(ts => new StopSummaryDto
        {
            SupplierName = ts.Supplier.Name,
            Condition = ts.Collection?.Condition,
            CollectedClearKg = ts.Collection?.ClearKg ?? 0,
            CollectedColouredKg = ts.Collection?.ColouredKg ?? 0,
            ExpectedClearKg = ts.Supplier.ExpectedClearKg,
            ExpectedColouredKg = ts.Supplier.ExpectedColouredKg,
            Skipped = ts.Status == "Skipped",
            PhotoUrl = ts.Collection is { HasPhoto: true }
                ? $"/api/collections/photo/{trip.Id}/{ts.SupplierId}"
                : null,
            SignatureUrl = ts.Collection is { HasSignature: true }
                ? $"/api/collections/signature/{trip.Id}/{ts.SupplierId}"
                : null,
            SignedBy = ts.Collection?.SignedBy,
            SkipReason = ts.SkipReason,
            Status = ts.Status,
            // Only a stop that was actually collected can fall short. Skipped
            // and not-yet-visited stops are neither on target nor a shortfall.
            BelowExpected = ts.Collection != null &&
                            (ts.Collection.ClearKg < ts.Supplier.ExpectedClearKg ||
                             ts.Collection.ColouredKg < ts.Supplier.ExpectedColouredKg)
        }).ToList();

        var times = stops
            .Where(ts => ts.Collection != null)
            .Select(ts => ts.Collection!.CollectedAt)
            .ToList();

        var duration = times.Count > 1 ? times.Max() - times.Min() : TimeSpan.Zero;

        return new TripSummaryDto
        {
            TripId = trip.Id,
            TripDate = trip.TripDate.ToString("yyyy-MM-dd"),
            TotalDistanceKm = trip.TotalDistanceKm,
            TripDuration = duration,
            DurationMinutes = (int)duration.TotalMinutes,
            TotalClearKg = stopSummaries.Sum(s => s.CollectedClearKg),
            TotalColouredKg = stopSummaries.Sum(s => s.CollectedColouredKg),
            Stops = stopSummaries
        };
    }
}
