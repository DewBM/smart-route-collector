namespace backend.Models;

public class TripStop
{
    public int Id { get; set; }
    public int TripId { get; set; }
    public int SupplierId { get; set; }
    public int StopOrder { get; set; }
    public string Status { get; set; } = "Pending";
    public double DistanceFromPrevKm { get; set; }
    public string? SkipReason { get; set; }
    public string? SkipNote { get; set; }
    public DateTime? SkippedAt { get; set; }

    public Trip Trip { get; set; } = null!;
    public Supplier Supplier { get; set; } = null!;
    public Collection? Collection { get; set; }
}
