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
    public DbSet<CollectionPhoto> CollectionPhotos { get; set; }
    public DbSet<CollectionSignature> CollectionSignatures { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<TripStop>()
            .HasOne(ts => ts.Collection)
            .WithOne(c => c.TripStop)
            .HasForeignKey<Collection>(c => c.TripStopId);

        modelBuilder.Entity<CollectionPhoto>(e =>
        {
            e.HasKey(p => p.CollectionId);
            e.HasOne(p => p.Collection)
                .WithOne()
                .HasForeignKey<CollectionPhoto>(p => p.CollectionId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<CollectionSignature>(e =>
        {
            e.HasKey(p => p.CollectionId);
            e.HasOne(p => p.Collection)
                .WithOne()
                .HasForeignKey<CollectionSignature>(p => p.CollectionId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<TripStop>()
            .Property(ts => ts.Status)
            .HasDefaultValue("Pending");
    }
}
