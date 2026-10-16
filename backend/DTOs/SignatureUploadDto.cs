namespace backend.DTOs;

public class SignatureUploadDto
{
    public int TripId { get; set; }
    public int SupplierId { get; set; }
    public string? SignerName { get; set; }
    public IFormFile? File { get; set; }
}
