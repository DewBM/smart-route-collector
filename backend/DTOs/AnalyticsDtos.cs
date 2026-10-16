namespace backend.DTOs;

public class TripHistoryItemDto
{
    public int TripId { get; set; }
    public string TripDate { get; set; } = string.Empty;
    public double TotalDistanceKm { get; set; }
    public int StopCount { get; set; }
    public int CollectedCount { get; set; }
    public int SkippedCount { get; set; }
    public bool IsComplete { get; set; }
    public double TotalKg { get; set; }
    public int ShortfallCount { get; set; }
    public int DurationMinutes { get; set; }
}

public class InsightsDto
{
    public int Days { get; set; }
    public int TripCount { get; set; }
    public int StopCount { get; set; }
    public int SkippedCount { get; set; }
    public double TotalClearKg { get; set; }
    public double TotalColouredKg { get; set; }
    public double TotalDistanceKm { get; set; }
    public double AverageKgPerStop { get; set; }
    public double ShortfallRate { get; set; }
    public List<DailyTotalDto> Daily { get; set; } = new();
    public List<SupplierTotalDto> TopSuppliers { get; set; } = new();
}

public class DailyTotalDto
{
    public string Date { get; set; } = string.Empty;
    public double ClearKg { get; set; }
    public double ColouredKg { get; set; }
}

public class SupplierTotalDto
{
    public string Name { get; set; } = string.Empty;
    public double TotalKg { get; set; }
}
