class TripHistoryItem {
  final int tripId;
  final String tripDate;
  final double totalDistanceKm;
  final int stopCount;
  final int collectedCount;
  final int skippedCount;
  final bool isComplete;
  final double totalKg;
  final int shortfallCount;
  final int durationMinutes;

  const TripHistoryItem({
    required this.tripId,
    required this.tripDate,
    required this.totalDistanceKm,
    required this.stopCount,
    required this.collectedCount,
    required this.skippedCount,
    required this.isComplete,
    required this.totalKg,
    required this.shortfallCount,
    required this.durationMinutes,
  });

  factory TripHistoryItem.fromJson(Map<String, dynamic> json) =>
      TripHistoryItem(
        tripId: json['tripId'] as int,
        tripDate: json['tripDate'] as String,
        totalDistanceKm: (json['totalDistanceKm'] as num).toDouble(),
        stopCount: json['stopCount'] as int,
        collectedCount: json['collectedCount'] as int,
        skippedCount: json['skippedCount'] as int? ?? 0,
        isComplete: json['isComplete'] as bool,
        totalKg: (json['totalKg'] as num).toDouble(),
        shortfallCount: json['shortfallCount'] as int,
        durationMinutes: json['durationMinutes'] as int,
      );
}

class DailyTotal {
  final DateTime date;
  final double clearKg;
  final double colouredKg;

  const DailyTotal(this.date, this.clearKg, this.colouredKg);
  double get totalKg => clearKg + colouredKg;
}

class SupplierTotal {
  final String name;
  final double totalKg;

  const SupplierTotal(this.name, this.totalKg);
}

class Insights {
  final int days;
  final int tripCount;
  final int stopCount;
  final double totalClearKg;
  final double totalColouredKg;
  final double totalDistanceKm;
  final double averageKgPerStop;
  final double shortfallRate;
  final List<DailyTotal> daily;
  final List<SupplierTotal> topSuppliers;

  const Insights({
    required this.days,
    required this.tripCount,
    required this.stopCount,
    required this.totalClearKg,
    required this.totalColouredKg,
    required this.totalDistanceKm,
    required this.averageKgPerStop,
    required this.shortfallRate,
    required this.daily,
    required this.topSuppliers,
  });

  double get totalKg => totalClearKg + totalColouredKg;

  factory Insights.fromJson(Map<String, dynamic> json) => Insights(
    days: json['days'] as int,
    tripCount: json['tripCount'] as int,
    stopCount: json['stopCount'] as int,
    totalClearKg: (json['totalClearKg'] as num).toDouble(),
    totalColouredKg: (json['totalColouredKg'] as num).toDouble(),
    totalDistanceKm: (json['totalDistanceKm'] as num).toDouble(),
    averageKgPerStop: (json['averageKgPerStop'] as num).toDouble(),
    shortfallRate: (json['shortfallRate'] as num).toDouble(),
    daily: (json['daily'] as List)
        .map(
          (d) => DailyTotal(
            DateTime.parse(d['date'] as String),
            (d['clearKg'] as num).toDouble(),
            (d['colouredKg'] as num).toDouble(),
          ),
        )
        .toList(),
    topSuppliers: (json['topSuppliers'] as List)
        .map(
          (s) => SupplierTotal(
            s['name'] as String,
            (s['totalKg'] as num).toDouble(),
          ),
        )
        .toList(),
  );
}
