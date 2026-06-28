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

    private async Task<Trip> CreateTripAsync(DateOnly date)
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

    public async Task AdvanceNextStopAsync(int tripId, int completedSupplierId)
    {
        var completedStop = await _db.TripStops
            .FirstOrDefaultAsync(ts => ts.TripId == tripId && ts.SupplierId == completedSupplierId)
            ?? throw new Exception("Stop not found.");

        completedStop.Status = "Collected";

        var nextStop = await _db.TripStops
            .Where(ts => ts.TripId == tripId && ts.Status == "Pending")
            .OrderBy(ts => ts.StopOrder)
            .FirstOrDefaultAsync();

        if (nextStop != null)
            nextStop.Status = "Next";

        await _db.SaveChangesAsync();
    }
}
