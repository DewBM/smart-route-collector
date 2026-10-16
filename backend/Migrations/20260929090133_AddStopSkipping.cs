using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace backend.Migrations
{
    /// <inheritdoc />
    public partial class AddStopSkipping : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "SkipNote",
                table: "TripStops",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "SkipReason",
                table: "TripStops",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "SkippedAt",
                table: "TripStops",
                type: "timestamp with time zone",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "SkipNote",
                table: "TripStops");

            migrationBuilder.DropColumn(
                name: "SkipReason",
                table: "TripStops");

            migrationBuilder.DropColumn(
                name: "SkippedAt",
                table: "TripStops");
        }
    }
}
