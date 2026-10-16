namespace backend.DTOs;

public class PhotoUploadDto
{
    public int TripId { get; set; }
    public int SupplierId { get; set; }
    public IFormFile? File { get; set; }
}
