using backend.Data;
using backend.Models;
using Microsoft.EntityFrameworkCore;

namespace backend.Services;

/// <summary>
/// Generates a few days of realistic past trips so History and Insights have
/// something to show. Idempotent: days that already have a trip are skipped.
/// Enabled with the config flag Seed:History=true (env var Seed__History).
/// </summary>
public class SeedService
{
    private readonly AppDbContext _db;
    private readonly TripService _tripService;

    public SeedService(AppDbContext db, TripService tripService)
    {
        _db = db;
        _tripService = tripService;
    }

    public async Task SeedHistoryAsync(int days = 10)
    {
        var colombo = TimeZoneInfo.FindSystemTimeZoneById("Asia/Colombo");
        var today = DateOnly.FromDateTime(TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, colombo));

        for (var back = days; back >= 1; back--)
        {
            var date = today.AddDays(-back);

            if (await _db.Trips.AnyAsync(t => t.TripDate == date))
                continue;

            Trip trip;
            try
            {
                trip = await _tripService.CreateTripAsync(date);
            }
            catch (Exception)
            {
                continue; // no suppliers scheduled that weekday
            }

            // Deterministic per date, so re-seeding produces the same data.
            var rng = new Random(date.DayNumber);
            var start = new DateTime(date.Year, date.Month, date.Day, 8, 0, 0);
            var clock = TimeZoneInfo.ConvertTimeToUtc(start, colombo);

            var stops = await _db.TripStops
                .Where(ts => ts.TripId == trip.Id)
                .Include(ts => ts.Supplier)
                .OrderBy(ts => ts.StopOrder)
                .ToListAsync();

            trip.StartedAt = clock;

            foreach (var stop in stops)
            {
                clock = clock.AddMinutes(20 + rng.Next(0, 26));

                // ~70% of stops meet expectations, the rest fall short.
                var short_ = rng.NextDouble() < 0.3;
                double Factor() => short_ ? 0.55 + rng.NextDouble() * 0.4 : 1.0 + rng.NextDouble() * 0.12;

                var conditions = new[] { "Clean", "Clean", "Contaminated", "Broken" };

                _db.Collections.Add(new Collection
                {
                    TripStopId = stop.Id,
                    ClearKg = Math.Round(stop.Supplier.ExpectedClearKg * Factor(), 1),
                    ColouredKg = Math.Round(stop.Supplier.ExpectedColouredKg * Factor(), 1),
                    Condition = conditions[rng.Next(conditions.Length)],
                    CollectedAt = clock,
                    Synced = true
                });

                stop.Status = "Collected";
            }

            trip.CompletedAt = clock;
            await _db.SaveChangesAsync();
        }
    }

    /// <summary>
    /// Fills empty supplier contact fields with obviously fake demo values so the
    /// supplier sheet has something to show. Never overwrites real data.
    /// Enabled with Seed:SupplierDetails=true.
    /// </summary>
    public async Task SeedSupplierDetailsAsync()
    {
        var notes = new[]
        {
            "Loading bay is at the rear. Ask for the yard supervisor.",
            "Bins are stored by the side gate. Call ahead if the gate is locked.",
            "Glass is sorted into clear and coloured crates. Check for contamination.",
            "Collection window 9am to 4pm. Heavy crates: bring the trolley.",
            "Reception is at the main entrance. Sign the visitor book on arrival."
        };

        var suppliers = await _db.Suppliers.OrderBy(s => s.Id).ToListAsync();
        for (var i = 0; i < suppliers.Count; i++)
        {
            var s = suppliers[i];
            s.Address ??= $"{s.Name}, main entrance";
            s.ContactName ??= $"Site contact {i + 1}";
            s.Phone ??= $"+94 77 555 {i + 1:D4}"; // 555 numbers are reserved for fiction
            s.Notes ??= notes[i % notes.Length];
        }

        await _db.SaveChangesAsync();
    }

    private record SeedSupplier(
        string Barcode, string Name, double Lat, double Lon,
        double Clear, double Coloured, string Days,
        string Address, string Contact, string Phone, string Notes);

    private const string Daily = "Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday";
    private const string MonWedFri = "Monday,Wednesday,Friday";
    private const string TueThuSat = "Tuesday,Thursday,Saturday";

    // Fictional businesses placed near real North Western Province towns
    // (coordinates are approximate). Phone numbers use the reserved 555 range.
    // Every weekday has at least 7 stops, so a trip can be generated any day.
    private static readonly SeedSupplier[] DemoSuppliers =
    [
        new("GL-SUP-001", "Kurunegala Glass Traders", 7.4863, 80.3647, 120, 80, Daily,
            "12 Colombo Road, Kurunegala", "Nimal Perera", "+94 77 555 0001",
            "Loading bay at the rear. Ask for the yard supervisor."),
        new("GL-SUP-002", "Kuliyapitiya Bottle Depot", 7.4694, 80.0410, 90, 60, Daily,
            "45 Hettipola Road, Kuliyapitiya", "Kamala Silva", "+94 77 555 0002",
            "Crates are stacked by the side gate. Call ahead if it is locked."),
        new("GL-SUP-003", "Narammala Hotel & Bar", 7.4300, 80.2160, 60, 110, Daily,
            "3 Main Street, Narammala", "Ruwan Fernando", "+94 77 555 0003",
            "Mostly coloured glass. Check for contamination with food waste."),
        new("GL-SUP-004", "Polgahawela Supermarket", 7.3333, 80.2989, 150, 40, Daily,
            "88 Railway Avenue, Polgahawela", "Dilani Jayasuriya", "+94 77 555 0004",
            "Collection window 9am to 4pm. Bring the trolley for heavy crates."),
        new("GL-SUP-005", "Mawathagama Beverages", 7.4650, 80.4340, 80, 50, MonWedFri,
            "21 Temple Road, Mawathagama", "Saman Kumara", "+94 77 555 0005",
            "Reception is at the main entrance. Sign the visitor book on arrival."),
        new("GL-SUP-006", "Alawwa Restaurant Group", 7.2960, 80.2410, 45, 95, MonWedFri,
            "7 Market Square, Alawwa", "Priya Wickramasinghe", "+94 77 555 0006",
            "Back kitchen entrance only. Glass is sorted into blue bins."),
        new("GL-SUP-007", "Pannala Bottling Works", 7.3318, 80.0176, 200, 70, MonWedFri,
            "Factory Lane, Pannala", "Chaminda Rathnayake", "+94 77 555 0007",
            "Large volume. Gate pass required, ask security for the visitor tag."),
        new("GL-SUP-008", "Wariyapola Wholesale", 7.6310, 80.2380, 110, 65, TueThuSat,
            "150 Kurunegala Road, Wariyapola", "Nadeesha Gunawardena", "+94 77 555 0008",
            "Warehouse 2. The forklift driver will help with pallets."),
        new("GL-SUP-009", "Nikaweratiya Canteen", 7.7500, 80.1170, 35, 55, TueThuSat,
            "Bus Stand Road, Nikaweratiya", "Lakshman Bandara", "+94 77 555 0009",
            "Small pickup. Bins are behind the canteen near the water tank."),
        new("GL-SUP-010", "Galgamuwa Liquor Store", 8.0000, 80.2830, 70, 130, TueThuSat,
            "Town Centre, Galgamuwa", "Isuru Senanayake", "+94 77 555 0010",
            "Mostly coloured glass. Often closes early on Saturdays."),
    ];

    /// <summary>
    /// Creates a depot and ten demo suppliers (idempotent, matched by barcode).
    /// Never modifies or removes existing rows. Enabled with Seed:Suppliers=true.
    /// </summary>
    public async Task SeedSuppliersAsync()
    {
        if (!await _db.Depots.AnyAsync())
        {
            _db.Depots.Add(new Depot
            {
                Name = "Glassline Depot, Kurunegala",
                Latitude = 7.4818,
                Longitude = 80.3609
            });
        }

        var existing = (await _db.Suppliers.Select(s => s.BarcodeRef).ToListAsync()).ToHashSet();

        foreach (var d in DemoSuppliers.Where(d => !existing.Contains(d.Barcode)))
        {
            _db.Suppliers.Add(new Supplier
            {
                BarcodeRef = d.Barcode,
                Name = d.Name,
                Latitude = d.Lat,
                Longitude = d.Lon,
                ExpectedClearKg = d.Clear,
                ExpectedColouredKg = d.Coloured,
                CollectionDays = d.Days,
                Address = d.Address,
                ContactName = d.Contact,
                Phone = d.Phone,
                Notes = d.Notes
            });
        }

        await _db.SaveChangesAsync();
    }

    /// <summary>
    /// Deletes today's trip (with its stops, collections, photos and signatures)
    /// so the next request generates a fresh one. DESTRUCTIVE: for testing only.
    /// Enabled with Seed:ResetToday=true, and runs on every start while set.
    /// </summary>
    public async Task ResetTodayAsync()
    {
        var colombo = TimeZoneInfo.FindSystemTimeZoneById("Asia/Colombo");
        var today = DateOnly.FromDateTime(TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, colombo));

        var trips = await _db.Trips.Where(t => t.TripDate == today).ToListAsync();
        _db.Trips.RemoveRange(trips);
        await _db.SaveChangesAsync();
    }
}
