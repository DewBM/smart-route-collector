using Microsoft.EntityFrameworkCore;
using backend.Models;

namespace backend.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<Depot> Depots { get; set; }
    public DbSet<Supplier> Suppliers { get; set; }
    public DbSet<Trip> Trips { get; set; }
    public DbSet<TripStop> TripStops { get; set; }
    public DbSet<Collection> Collections { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<TripStop>()
            .HasOne(ts => ts.Collection)
            .WithOne(c => c.TripStop)
            .HasForeignKey<Collection>(c => c.TripStopId);

        modelBuilder.Entity<TripStop>()
            .Property(ts => ts.Status)
            .HasDefaultValue("Pending");
    }
}
