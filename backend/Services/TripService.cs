using backend.Data;
using backend.Models;
using Microsoft.EntityFrameworkCore;

namespace backend.Services;

public class TripService
{
    private readonly AppDbContext _db;
    private readonly RouteService _routeService;

    public TripService(AppDbContext db, RouteService routeService)
    {
        _db = db;
        _routeService = routeService;
    }

    public async Task<Trip> GetOrCreateTodaysTripAsync()
    {
        var localTime = TimeZoneInfo.ConvertTimeBySystemTimeZoneId(DateTime.UtcNow, "Asia/Colombo");
        var today = DateOnly.FromDateTime(localTime);

        var existingTrip = await _db.Trips
            .Include(t => t.TripStops)
                .ThenInclude(ts => ts.Supplier)
            .FirstOrDefaultAsync(t => t.TripDate == today);

        if (existingTrip != null)
            return existingTrip;

        return await CreateTripAsync(today);
    }

    public async Task<Trip> CreateTripAsync(DateOnly date)
    {
        var depot = await _db.Depots.FirstOrDefaultAsync()
            ?? throw new Exception("No depot found in database.");

        var dayName = date.DayOfWeek.ToString();

        var suppliers = await _db.Suppliers
            .Where(s => s.CollectionDays.Contains(dayName))
            .ToListAsync();

        if (suppliers.Count == 0)
            throw new Exception($"No suppliers scheduled for {dayName}.");

        var nodes = new List<(int Id, double Lat, double Lon)>
        {
            (depot.Id * -1, depot.Latitude, depot.Longitude)
        };

        nodes.AddRange(suppliers.Select(s => (s.Id, s.Latitude, s.Longitude)));

        var orderedSupplierIds = _routeService.GetOptimalRoute(depot.Id * -1, nodes);

        var trip = new Trip
        {
            TripDate = date,
            DepotId = depot.Id,
            StartedAt = DateTime.UtcNow
        };

        _db.Trips.Add(trip);
        await _db.SaveChangesAsync();

        double totalDistance = 0;
        double prevLat = depot.Latitude;
        double prevLon = depot.Longitude;

        var stops = new List<TripStop>();

        for (int i = 0; i < orderedSupplierIds.Count; i++)
        {
            var supplierId = orderedSupplierIds[i];
            var supplier = suppliers.First(s => s.Id == supplierId);
            var distance = _routeService.Haversine(prevLat, prevLon, supplier.Latitude, supplier.Longitude);

            totalDistance += distance;

            stops.Add(new TripStop
            {
                TripId = trip.Id,
                SupplierId = supplierId,
                StopOrder = i + 1,
                Status = i == 0 ? "Next" : "Pending",
                DistanceFromPrevKm = distance
            });

            prevLat = supplier.Latitude;
            prevLon = supplier.Longitude;
        }

        _db.TripStops.AddRange(stops);

        trip.TotalDistanceKm = totalDistance;
        await _db.SaveChangesAsync();

        return await _db.Trips
            .Include(t => t.TripStops)
                .ThenInclude(ts => ts.Supplier)
            .FirstAsync(t => t.Id == trip.Id);
    }

    public enum RecordResult { Recorded, AlreadyRecorded, StopNotFound, StopSkipped }

    /// <summary>
    /// Records a collection for a stop and marks it Collected. Accepts any stop
    /// that is still to be visited, not only the server's current "Next": a
    /// collector working offline may legitimately visit stops in a different
    /// order than the server last computed. Idempotent, so offline retries are safe.
    /// </summary>
    public async Task<RecordResult> RecordCollectionAsync(
        int tripId, int supplierId, double clearKg, double colouredKg, string condition, DateTime collectedAt)
    {
        var stop = await _db.TripStops
            .FirstOrDefaultAsync(ts => ts.TripId == tripId && ts.SupplierId == supplierId);

        if (stop == null)
            return RecordResult.StopNotFound;

        if (await _db.Collections.AnyAsync(c => c.TripStopId == stop.Id))
            return RecordResult.AlreadyRecorded;

        if (stop.Status == "Skipped")
            return RecordResult.StopSkipped;

        _db.Collections.Add(new Collection
        {
            TripStopId = stop.Id,
            ClearKg = clearKg,
            ColouredKg = colouredKg,
            Condition = condition,
            CollectedAt = collectedAt,
            Synced = true
        });

        stop.Status = "Collected";
        await _db.SaveChangesAsync();
        await EnsureNextStopAsync(tripId);
        return RecordResult.Recorded;
    }

    /// <summary>Makes sure exactly one unfinished stop is "Next" (if any remain).</summary>
    private async Task EnsureNextStopAsync(int tripId)
    {
        var open = await _db.TripStops
            .Where(ts => ts.TripId == tripId && (ts.Status == "Pending" || ts.Status == "Next"))
            .OrderBy(ts => ts.StopOrder)
            .ToListAsync();

        if (open.Count == 0)
            return;

        var next = open.FirstOrDefault(ts => ts.Status == "Next") ?? open[0];
        foreach (var ts in open)
            ts.Status = ts == next ? "Next" : "Pending";

        await _db.SaveChangesAsync();
    }

    /// <summary>
    /// Marks a stop as skipped and, when it was the current stop, re-runs the
    /// route optimisation (Dijkstra over Haversine distances) for the stops
    /// that are still to be visited, starting from the skipped stop's location.
    /// Idempotent: skipping an already skipped stop is a no-op.
    /// </summary>
    public async Task<Trip> SkipStopAsync(int tripId, int supplierId, string reason, string? note, DateTime? skippedAt)
    {
        var trip = await _db.Trips
            .Include(t => t.TripStops).ThenInclude(ts => ts.Supplier)
            .FirstOrDefaultAsync(t => t.Id == tripId)
            ?? throw new KeyNotFoundException("Trip not found.");

        var target = trip.TripStops.FirstOrDefault(ts => ts.SupplierId == supplierId)
            ?? throw new KeyNotFoundException("Trip stop not found.");

        if (target.Status == "Skipped")
            return trip;

        if (target.Status == "Collected")
            throw new InvalidOperationException("This stop has already been collected.");

        var wasNext = target.Status == "Next";
        target.Status = "Skipped";
        target.SkipReason = reason;
        target.SkipNote = note;
        target.SkippedAt = skippedAt ?? DateTime.UtcNow;

        // Finished stops keep their order; the skipped stop joins the end of them.
        var finished = trip.TripStops
            .Where(ts => ts != target && (ts.Status == "Collected" || ts.Status == "Skipped"))
            .OrderBy(ts => ts.StopOrder)
            .ToList();
        finished.Add(target);

        var remaining = trip.TripStops
            .Where(ts => ts.Status == "Pending" || ts.Status == "Next")
            .OrderBy(ts => ts.StopOrder)
            .ToList();

        if (remaining.Count > 0 && wasNext)
        {
            const int originId = -1;
            var nodes = new List<(int Id, double Lat, double Lon)>
            {
                (originId, target.Supplier.Latitude, target.Supplier.Longitude)
            };
            nodes.AddRange(remaining.Select(ts => (ts.SupplierId, ts.Supplier.Latitude, ts.Supplier.Longitude)));

            var order = _routeService.GetOptimalRoute(originId, nodes);
            remaining = order.Select(id => remaining.First(ts => ts.SupplierId == id)).ToList();

            var prevLat = target.Supplier.Latitude;
            var prevLon = target.Supplier.Longitude;
            foreach (var ts in remaining)
            {
                ts.DistanceFromPrevKm = _routeService.Haversine(
                    prevLat, prevLon, ts.Supplier.Latitude, ts.Supplier.Longitude);
                ts.Status = "Pending";
                prevLat = ts.Supplier.Latitude;
                prevLon = ts.Supplier.Longitude;
            }
        }

        // Ensure exactly one stop is "Next".
        if (remaining.Count > 0 && remaining.All(ts => ts.Status != "Next"))
            remaining[0].Status = "Next";

        var position = 1;
        foreach (var ts in finished.Concat(remaining))
            ts.StopOrder = position++;

        trip.TotalDistanceKm = trip.TripStops.Sum(ts => ts.DistanceFromPrevKm);
        await _db.SaveChangesAsync();
        return trip;
    }
}
