namespace backend.DTOs;

public class TripResponseDto
{
    public int TripId { get; set; }
    public string TripDate { get; set; } = string.Empty;
    public double TotalDistanceKm { get; set; }
    public List<StopDto> Stops { get; set; } = new List<StopDto>();
}
