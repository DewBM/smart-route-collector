using backend.Data;
using backend.DTOs;
using backend.Models;
using backend.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace backend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CollectionsController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly TripService _tripService;

    public CollectionsController(AppDbContext db, TripService tripService)
    {
        _db = db;
        _tripService = tripService;
    }

    [HttpPost]
    public async Task<IActionResult> PostCollection([FromBody] CollectionRequestDto request)
    {
        try
        {
            var stop = await _db.TripStops
                .FirstOrDefaultAsync(ts => ts.TripId == request.TripId &&
                                           ts.SupplierId == request.SupplierId);

            if (stop == null)
                return NotFound(new { error = "Trip stop not found." });

            if (stop.Status != "Next")
                return BadRequest(new { error = "This stop is not the current stop." });

            var existing = await _db.Collections
                .AnyAsync(c => c.TripStopId == stop.Id);

            if (existing)
                return Ok(new { message = "Collection already recorded." });

            var collection = new Collection
            {
                TripStopId = stop.Id,
                ClearKg = request.ClearKg,
                ColouredKg = request.ColouredKg,
                Condition = request.Condition,
                CollectedAt = request.CollectedAt,
                Synced = true
            };

            _db.Collections.Add(collection);
            await _db.SaveChangesAsync();

            await _tripService.AdvanceNextStopAsync(request.TripId, request.SupplierId);

            return Ok(new { message = "Collection recorded." });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    [HttpPost("sync")]
    public async Task<IActionResult> Sync([FromBody] SyncRequestDto request)
    {
        try
        {
            foreach (var item in request.Collections)
            {
                var stop = await _db.TripStops
                    .FirstOrDefaultAsync(ts => ts.TripId == request.TripId &&
                                               ts.SupplierId == item.SupplierId);

                if (stop == null) continue;

                var existing = await _db.Collections
                    .AnyAsync(c => c.TripStopId == stop.Id);

                if (existing) continue;

                var collection = new Collection
                {
                    TripStopId = stop.Id,
                    ClearKg = item.ClearKg,
                    ColouredKg = item.ColouredKg,
                    Condition = item.Condition,
                    CollectedAt = item.CollectedAt,
                    Synced = true
                };

                _db.Collections.Add(collection);
            }

            await _db.SaveChangesAsync();

            return Ok(new { message = "Sync complete." });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }
}
