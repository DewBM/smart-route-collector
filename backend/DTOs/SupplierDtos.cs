using System.ComponentModel.DataAnnotations;

namespace backend.DTOs;

public class SupplierDetailDto
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Address { get; set; }
    public string? ContactName { get; set; }
    public string? Phone { get; set; }
    public string? Notes { get; set; }
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public double ExpectedClearKg { get; set; }
    public double ExpectedColouredKg { get; set; }
    public string CollectionDays { get; set; } = string.Empty;
    public int TotalCollections { get; set; }
    public double AverageKgPerCollection { get; set; }
    public List<SupplierCollectionDto> RecentCollections { get; set; } = new();
}

public class SupplierCollectionDto
{
    public string TripDate { get; set; } = string.Empty;
    public double ClearKg { get; set; }
    public double ColouredKg { get; set; }
    public string Condition { get; set; } = string.Empty;
    public bool BelowExpected { get; set; }
}

public class UpdateSupplierContactDto
{
    [MaxLength(200)] public string? Address { get; set; }
    [MaxLength(100)] public string? ContactName { get; set; }
    [MaxLength(30)] public string? Phone { get; set; }
    [MaxLength(500)] public string? Notes { get; set; }
}
