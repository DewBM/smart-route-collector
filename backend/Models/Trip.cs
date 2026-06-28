namespace backend.Models;

public class Trip
{
    public int Id { get; set; }
    public DateOnly TripDate { get; set; }
    public int DepotId { get; set; }
    public double TotalDistanceKm { get; set; }
    public DateTime? StartedAt { get; set; }
    public DateTime? CompletedAt { get; set; }

    public Depot Depot { get; set; } = null!;
    public ICollection<TripStop> TripStops { get; set; } = new List<TripStop>();
}
