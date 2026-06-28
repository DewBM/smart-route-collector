namespace backend.DTOs;

public class StopDto
{
    public int SupplierId { get; set; }
    public string SupplierName { get; set; } = string.Empty;
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public string BarcodeRef { get; set; } = string.Empty;
    public double ExpectedClearKg { get; set; }
    public double ExpectedColouredKg { get; set; }
    public string Status { get; set; } = string.Empty;
    public int StopOrder { get; set; }
    public double DistanceFromPrevKm { get; set; }
}
