using backend.Data;
using backend.DTOs;
using backend.Models;
using backend.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace backend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CollectionsController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly TripService _tripService;

    public CollectionsController(AppDbContext db, TripService tripService)
    {
        _db = db;
        _tripService = tripService;
    }

    [HttpPost]
    public async Task<IActionResult> PostCollection([FromBody] CollectionRequestDto request)
    {
        try
        {
            var result = await _tripService.RecordCollectionAsync(
                request.TripId, request.SupplierId, request.ClearKg,
                request.ColouredKg, request.Condition, request.CollectedAt);

            return result switch
            {
                TripService.RecordResult.Recorded => Ok(new { message = "Collection recorded." }),
                TripService.RecordResult.AlreadyRecorded => Ok(new { message = "Collection already recorded." }),
                TripService.RecordResult.StopSkipped => BadRequest(new { error = "This stop was skipped." }),
                _ => NotFound(new { error = "Trip stop not found." })
            };
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    /// <summary>Final confirmation push of every locally stored record. Idempotent.</summary>
    [HttpPost("sync")]
    public async Task<IActionResult> Sync([FromBody] SyncRequestDto request)
    {
        try
        {
            foreach (var item in request.Collections.OrderBy(c => c.CollectedAt))
            {
                await _tripService.RecordCollectionAsync(
                    request.TripId, item.SupplierId, item.ClearKg,
                    item.ColouredKg, item.Condition, item.CollectedAt);
            }

            return Ok(new { message = "Sync complete." });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    private const long MaxPhotoBytes = 3 * 1024 * 1024;
    private static readonly string[] AllowedPhotoTypes = ["image/jpeg", "image/png", "image/webp"];

    /// <summary>
    /// Attach a proof photo to an already-recorded collection. Replaces any
    /// existing photo, so retries are safe.
    /// </summary>
    [HttpPost("photo")]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(MaxPhotoBytes + 64 * 1024)]
    public async Task<IActionResult> UploadPhoto([FromForm] PhotoUploadDto request)
    {
        try
        {
            var file = request.File;

            if (file == null || file.Length == 0)
                return BadRequest(new { error = "No photo provided." });

            if (file.Length > MaxPhotoBytes)
                return BadRequest(new { error = "Photo is too large (max 3 MB)." });

            if (!AllowedPhotoTypes.Contains(file.ContentType))
                return BadRequest(new { error = "Photo must be a JPEG, PNG or WebP image." });

            var collection = await _db.Collections
                .FirstOrDefaultAsync(c => c.TripStop.TripId == request.TripId &&
                                          c.TripStop.SupplierId == request.SupplierId);

            if (collection == null)
                return NotFound(new { error = "Collection not found. Sync the collection first." });

            using var ms = new MemoryStream((int)file.Length);
            await file.CopyToAsync(ms);

            var photo = await _db.CollectionPhotos.FindAsync(collection.Id);
            if (photo == null)
            {
                photo = new CollectionPhoto { CollectionId = collection.Id };
                _db.CollectionPhotos.Add(photo);
            }

            photo.Data = ms.ToArray();
            photo.ContentType = file.ContentType;
            photo.UploadedAt = DateTime.UtcNow;
            collection.HasPhoto = true;

            await _db.SaveChangesAsync();
            return Ok(new { message = "Photo saved." });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    [HttpGet("photo/{tripId:int}/{supplierId:int}")]
    public async Task<IActionResult> GetPhoto(int tripId, int supplierId)
    {
        var photo = await _db.CollectionPhotos
            .Where(p => p.Collection.TripStop.TripId == tripId &&
                        p.Collection.TripStop.SupplierId == supplierId)
            .FirstOrDefaultAsync();

        if (photo == null)
            return NotFound();

        return File(photo.Data, photo.ContentType);
    }

    private const long MaxSignatureBytes = 512 * 1024;

    /// <summary>
    /// Attach the supplier's signature to an already-recorded collection.
    /// Replaces any existing signature, so retries are safe.
    /// </summary>
    [HttpPost("signature")]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(MaxSignatureBytes + 64 * 1024)]
    public async Task<IActionResult> UploadSignature([FromForm] SignatureUploadDto request)
    {
        try
        {
            var file = request.File;

            if (file == null || file.Length == 0)
                return BadRequest(new { error = "No signature provided." });

            if (file.Length > MaxSignatureBytes)
                return BadRequest(new { error = "Signature image is too large (max 512 KB)." });

            if (file.ContentType != "image/png")
                return BadRequest(new { error = "Signature must be a PNG image." });

            var collection = await _db.Collections
                .FirstOrDefaultAsync(c => c.TripStop.TripId == request.TripId &&
                                          c.TripStop.SupplierId == request.SupplierId);

            if (collection == null)
                return NotFound(new { error = "Collection not found. Sync the collection first." });

            using var ms = new MemoryStream((int)file.Length);
            await file.CopyToAsync(ms);

            var signer = string.IsNullOrWhiteSpace(request.SignerName)
                ? null
                : request.SignerName.Trim();
            if (signer is { Length: > 100 })
                signer = signer[..100];

            var signature = await _db.CollectionSignatures.FindAsync(collection.Id);
            if (signature == null)
            {
                signature = new CollectionSignature { CollectionId = collection.Id };
                _db.CollectionSignatures.Add(signature);
            }

            signature.Data = ms.ToArray();
            signature.ContentType = file.ContentType;
            signature.SignerName = signer;
            signature.UploadedAt = DateTime.UtcNow;
            collection.HasSignature = true;
            collection.SignedBy = signer;

            await _db.SaveChangesAsync();
            return Ok(new { message = "Signature saved." });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    [HttpGet("signature/{tripId:int}/{supplierId:int}")]
    public async Task<IActionResult> GetSignature(int tripId, int supplierId)
    {
        var signature = await _db.CollectionSignatures
            .Where(p => p.Collection.TripStop.TripId == tripId &&
                        p.Collection.TripStop.SupplierId == supplierId)
            .FirstOrDefaultAsync();

        if (signature == null)
            return NotFound();

        return File(signature.Data, signature.ContentType);
    }
}
