namespace backend.Models;

/// <summary>
/// Proof-of-collection photo. Kept in its own table so that queries that only
/// need collection data never load image bytes. Stored in the database (not on
/// disk) because free hosting tiers have an ephemeral filesystem.
/// </summary>
public class CollectionPhoto
{
    public int CollectionId { get; set; }
    public byte[] Data { get; set; } = Array.Empty<byte>();
    public string ContentType { get; set; } = "image/jpeg";
    public DateTime UploadedAt { get; set; }
    public Collection Collection { get; set; } = null!;
}
