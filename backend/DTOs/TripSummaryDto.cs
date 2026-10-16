namespace backend.DTOs;

public class TripSummaryDto
{
    public int TripId { get; set; }
    public string TripDate { get; set; } = string.Empty;
    public int DurationMinutes { get; set; }
    public double TotalDistanceKm { get; set; }
    public TimeSpan TripDuration { get; set; }
    public double TotalClearKg { get; set; }
    public double TotalColouredKg { get; set; }
    public List<StopSummaryDto> Stops { get; set; } = new List<StopSummaryDto>();
}

public class StopSummaryDto
{
    public string SupplierName { get; set; } = string.Empty;
    public string? Condition { get; set; }
    public double CollectedClearKg { get; set; }
    public double CollectedColouredKg { get; set; }
    public double ExpectedClearKg { get; set; }
    public double ExpectedColouredKg { get; set; }
    public bool BelowExpected { get; set; }
    public bool Skipped { get; set; }
    public string Status { get; set; } = string.Empty;
    public string? PhotoUrl { get; set; }
    public string? SignatureUrl { get; set; }
    public string? SignedBy { get; set; }
    public string? SkipReason { get; set; }
}
