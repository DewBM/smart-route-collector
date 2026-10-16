using backend.Data;
using backend.DTOs;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace backend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class SuppliersController : ControllerBase
{
    private readonly AppDbContext _db;

    public SuppliersController(AppDbContext db)
    {
        _db = db;
    }

    /// <summary>Supplier profile with contact info and the last three collections.</summary>
    [HttpGet("{id:int}")]
    public async Task<IActionResult> Get(int id)
    {
        try
        {
            var supplier = await _db.Suppliers.FirstOrDefaultAsync(s => s.Id == id);
            if (supplier == null)
                return NotFound(new { error = "Supplier not found." });

            var collections = await _db.Collections
                .Where(c => c.TripStop.SupplierId == id)
                .OrderByDescending(c => c.CollectedAt)
                .Select(c => new
                {
                    Date = c.TripStop.Trip.TripDate,
                    c.ClearKg,
                    c.ColouredKg,
                    c.Condition
                })
                .ToListAsync();

            return Ok(new SupplierDetailDto
            {
                Id = supplier.Id,
                Name = supplier.Name,
                Address = supplier.Address,
                ContactName = supplier.ContactName,
                Phone = supplier.Phone,
                Notes = supplier.Notes,
                Latitude = supplier.Latitude,
                Longitude = supplier.Longitude,
                ExpectedClearKg = supplier.ExpectedClearKg,
                ExpectedColouredKg = supplier.ExpectedColouredKg,
                CollectionDays = supplier.CollectionDays,
                TotalCollections = collections.Count,
                AverageKgPerCollection = collections.Count == 0
                    ? 0
                    : collections.Average(c => c.ClearKg + c.ColouredKg),
                RecentCollections = collections.Take(3).Select(c => new SupplierCollectionDto
                {
                    TripDate = c.Date.ToString("yyyy-MM-dd"),
                    ClearKg = c.ClearKg,
                    ColouredKg = c.ColouredKg,
                    Condition = c.Condition,
                    BelowExpected = c.ClearKg < supplier.ExpectedClearKg ||
                                    c.ColouredKg < supplier.ExpectedColouredKg
                }).ToList()
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    /// <summary>Update contact details (address, phone, contact person, notes).</summary>
    [HttpPut("{id:int}/contact")]
    public async Task<IActionResult> UpdateContact(int id, [FromBody] UpdateSupplierContactDto request)
    {
        try
        {
            var supplier = await _db.Suppliers.FirstOrDefaultAsync(s => s.Id == id);
            if (supplier == null)
                return NotFound(new { error = "Supplier not found." });

            supplier.Address = request.Address;
            supplier.ContactName = request.ContactName;
            supplier.Phone = request.Phone;
            supplier.Notes = request.Notes;
            await _db.SaveChangesAsync();

            return Ok(new { message = "Supplier updated." });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }
}
