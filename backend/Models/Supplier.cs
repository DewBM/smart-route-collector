namespace backend.Models;

public class Supplier
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public string BarcodeRef { get; set; } = string.Empty;
    public double ExpectedClearKg { get; set; }
    public double ExpectedColouredKg { get; set; }
    public string CollectionDays { get; set; } = string.Empty;

    public ICollection<TripStop> TripStops { get; set; } = new List<TripStop>();
}
