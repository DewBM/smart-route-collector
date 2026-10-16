namespace backend.Models;

/// <summary>
/// The supplier's on-screen signature confirming the handover. Own table for
/// the same reason as <see cref="CollectionPhoto"/>: keep image bytes out of
/// ordinary collection queries.
/// </summary>
public class CollectionSignature
{
    public int CollectionId { get; set; }
    public byte[] Data { get; set; } = Array.Empty<byte>();
    public string ContentType { get; set; } = "image/png";
    public string? SignerName { get; set; }
    public DateTime UploadedAt { get; set; }
    public Collection Collection { get; set; } = null!;
}
