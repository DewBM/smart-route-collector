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

            var response = new TripResponseDto
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
                        DistanceFromPrevKm = ts.DistanceFromPrevKm
                    }).ToList()
            };

            return Ok(response);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    [HttpGet("today/summary")]
    public async Task<IActionResult> GetSummary()
    {
        try
        {
            var today = DateOnly.FromDateTime(DateTime.UtcNow);

            var trip = await _db.Trips
                .Include(t => t.TripStops)
                    .ThenInclude(ts => ts.Supplier)
                .Include(t => t.TripStops)
                    .ThenInclude(ts => ts.Collection)
                .FirstOrDefaultAsync(t => t.TripDate == today);

            if (trip == null)
                return NotFound(new { error = "No trip found for today." });

            var stops = trip.TripStops.OrderBy(ts => ts.StopOrder).ToList();

            var stopSummaries = stops.Select(ts => new StopSummaryDto
            {
                SupplierName = ts.Supplier.Name,
                CollectedClearKg = ts.Collection?.ClearKg ?? 0,
                CollectedColouredKg = ts.Collection?.ColouredKg ?? 0,
                ExpectedClearKg = ts.Supplier.ExpectedClearKg,
                ExpectedColouredKg = ts.Supplier.ExpectedColouredKg,
                BelowExpected = (ts.Collection?.ClearKg ?? 0) < ts.Supplier.ExpectedClearKg ||
                                (ts.Collection?.ColouredKg ?? 0) < ts.Supplier.ExpectedColouredKg
            }).ToList();

            var firstCollection = stops
                .Where(ts => ts.Collection != null)
                .OrderBy(ts => ts.Collection!.CollectedAt)
                .FirstOrDefault()?.Collection?.CollectedAt;

            var lastCollection = stops
                .Where(ts => ts.Collection != null)
                .OrderByDescending(ts => ts.Collection!.CollectedAt)
                .FirstOrDefault()?.Collection?.CollectedAt;

            var duration = (firstCollection != null && lastCollection != null)
                ? lastCollection.Value - firstCollection.Value
                : TimeSpan.Zero;

            var summary = new TripSummaryDto
            {
                TripId = trip.Id,
                TotalDistanceKm = trip.TotalDistanceKm,
                TripDuration = duration,
                TotalClearKg = stopSummaries.Sum(s => s.CollectedClearKg),
                TotalColouredKg = stopSummaries.Sum(s => s.CollectedColouredKg),
                Stops = stopSummaries
            };

            return Ok(summary);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }
}
