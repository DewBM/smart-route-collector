using System.ComponentModel.DataAnnotations;

namespace backend.DTOs;

public class SkipStopRequestDto
{
    [Required]
    [MaxLength(60)]
    public string Reason { get; set; } = string.Empty;

    [MaxLength(300)]
    public string? Note { get; set; }

    public DateTime? SkippedAt { get; set; }
}
