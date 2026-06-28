namespace backend.DTOs;

public class SyncRequestDto
{
    public int TripId { get; set; }
    public List<CollectionRequestDto> Collections { get; set; } = new List<CollectionRequestDto>();
}
