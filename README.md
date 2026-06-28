# Smart Route Collector

A full-stack mobile system for field operatives to optimise waste glass collection routes, scan supplier locations via barcode, record collections offline, and sync to a hosted backend.

**Flutter (Android)** · **.NET 10 REST API** · **PostgreSQL (Supabase)**

---

## Prerequisites

- .NET 10 SDK
- `dotnet-ef` CLI — `dotnet tool install --global dotnet-ef`
- Flutter SDK (stable channel) + Android SDK
- Supabase project (free tier)

---

## Backend Setup

```bash
cd backend
```

Create `appsettings.json` with your Supabase connection string:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "YOUR_SUPABASE_CONNECTION_STRING"
  }
}
```

Install dependencies and run migrations:

```bash
dotnet restore
dotnet ef database update
```

Seed the database via Supabase SQL Editor:

```sql
INSERT INTO "Depots" ("Name", "Latitude", "Longitude")
VALUES ('Colombo Depot', 6.9271, 79.8612);

INSERT INTO "Suppliers" ("Name", "Latitude", "Longitude", "BarcodeRef", "ExpectedClearKg", "ExpectedColouredKg", "CollectionDays")
VALUES
  ('Kandy Glass Co',       7.2906, 80.6337, 'SUP-001', 50.0, 20.0, 'Sunday,Tuesday,Thursday'),
  ('Galle Recyclers',      6.0535, 80.2210, 'SUP-002', 40.0, 15.0, 'Sunday,Wednesday'),
  ('Negombo Collectibles', 7.2088, 79.8358, 'SUP-003', 60.0, 25.0, 'Sunday,Monday,Friday'),
  ('Matara Glass',         5.9549, 80.5550, 'SUP-004', 35.0, 10.0, 'Monday,Wednesday,Friday'),
  ('Kurunegala Waste',     7.4863, 80.3647, 'SUP-005', 45.0, 18.0, 'Tuesday,Thursday,Saturday');
```

Run locally:

```bash
dotnet run
```

---

## Mobile Setup

```bash
cd mobile
flutter pub get
```

Set your backend URL in `lib/services/api_service.dart`:

```dart
// Emulator
static const String baseUrl = 'http://10.0.2.2:5081';

// Physical device (use your machine's local IP)
static const String baseUrl = 'http://192.168.1.x:5081';

// Hosted
static const String baseUrl = 'https://your-hosted-url';
```

Run on device:

```bash
flutter run
```

Build release APK:

```bash
flutter build apk --release
```

Install on device:

```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## Barcode Testing

Generate **Code 128** barcodes at [barcode.tec-it.com](https://barcode.tec-it.com/en/Code128) using these values:

| Supplier | Barcode | Scheduled Days |
|----------|---------|----------------|
| Kandy Glass Co | `SUP-001` | Sunday, Tuesday, Thursday |
| Galle Recyclers | `SUP-002` | Sunday, Wednesday |
| Negombo Collectibles | `SUP-003` | Sunday, Monday, Friday |
| Matara Glass | `SUP-004` | Monday, Wednesday, Friday |
| Kurunegala Waste | `SUP-005` | Tuesday, Thursday, Saturday |

Display each barcode on a second device and scan with the app on Screen 2 to unlock the collection form.
