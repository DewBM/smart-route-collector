class StopReport {
  final String supplierName;
  final String? condition;
  final double collectedClearKg;
  final double collectedColouredKg;
  final double expectedClearKg;
  final double expectedColouredKg;
  final bool skipped;

  /// Not visited yet (Pending or Next): nothing collected, and not a shortfall.
  final bool pending;
  final String? skipReason;
  final String? photoPath; // local file (today's trip)
  final String? photoUrl; // server path (history)
  final String? signaturePath; // local file (today's trip)
  final String? signatureUrl; // server path (history)
  final String? signedBy;

  const StopReport({
    required this.supplierName,
    required this.condition,
    required this.collectedClearKg,
    required this.collectedColouredKg,
    required this.expectedClearKg,
    required this.expectedColouredKg,
    this.skipped = false,
    this.pending = false,
    this.skipReason,
    this.photoPath,
    this.photoUrl,
    this.signaturePath,
    this.signatureUrl,
    this.signedBy,
  });

  bool get belowExpected =>
      !skipped &&
      !pending &&
      (collectedClearKg < expectedClearKg ||
          collectedColouredKg < expectedColouredKg);

  factory StopReport.fromJson(Map<String, dynamic> json) => StopReport(
    supplierName: json['supplierName'] as String,
    condition: json['condition'] as String?,
    collectedClearKg: (json['collectedClearKg'] as num).toDouble(),
    collectedColouredKg: (json['collectedColouredKg'] as num).toDouble(),
    expectedClearKg: (json['expectedClearKg'] as num).toDouble(),
    expectedColouredKg: (json['expectedColouredKg'] as num).toDouble(),
    skipped: json['skipped'] as bool? ?? false,
    pending: json['status'] == 'Pending' || json['status'] == 'Next',
    skipReason: json['skipReason'] as String?,
    photoUrl: json['photoUrl'] as String?,
    signatureUrl: json['signatureUrl'] as String?,
    signedBy: json['signedBy'] as String?,
  );
}

/// Everything the trip report screen needs to render, whether it was built
/// from the local database (today's trip) or fetched from the server (history).
class TripReportData {
  final String? tripDate;
  final double distanceKm;
  final Duration? duration;
  final List<StopReport> stops;

  const TripReportData({
    required this.tripDate,
    required this.distanceKm,
    required this.duration,
    required this.stops,
  });

  double get totalClearKg =>
      stops.fold(0, (sum, s) => sum + s.collectedClearKg);
  double get totalColouredKg =>
      stops.fold(0, (sum, s) => sum + s.collectedColouredKg);
  int get shortfalls => stops.where((s) => s.belowExpected).length;
  int get skippedCount => stops.where((s) => s.skipped).length;
  int get pendingCount => stops.where((s) => s.pending).length;

  factory TripReportData.fromSummaryJson(Map<String, dynamic> json) {
    final minutes = json['durationMinutes'] as int? ?? 0;
    return TripReportData(
      tripDate: json['tripDate'] as String?,
      distanceKm: (json['totalDistanceKm'] as num).toDouble(),
      duration: minutes > 0 ? Duration(minutes: minutes) : null,
      stops: (json['stops'] as List)
          .map((s) => StopReport.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}
