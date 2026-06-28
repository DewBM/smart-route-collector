namespace backend.Models;

public class Collection
{
    public int Id { get; set; }
    public int TripStopId { get; set; }
    public double ClearKg { get; set; }
    public double ColouredKg { get; set; }
    public string Condition { get; set; } = string.Empty;
    public DateTime CollectedAt { get; set; }
    public bool Synced { get; set; } = false;

    public TripStop TripStop { get; set; } = null!;
}
