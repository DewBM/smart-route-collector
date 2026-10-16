import 'package:flutter_test/flutter_test.dart';
import 'package:smart_route/models/trip_report.dart';
import 'package:smart_route/services/report_pdf_service.dart';

Map<String, dynamic> _stop(
  String name,
  String status, {
  double clear = 0,
  double coloured = 0,
  bool skipped = false,
}) => {
  'supplierName': name,
  'condition': null,
  'collectedClearKg': clear,
  'collectedColouredKg': coloured,
  'expectedClearKg': 45,
  'expectedColouredKg': 18,
  'skipped': skipped,
  'status': status,
  'belowExpected': false,
};

void main() {
  test('stops that were not visited are never counted as shortfalls', () {
    final data = TripReportData.fromSummaryJson({
      'tripDate': '2026-09-29',
      'totalDistanceKm': 120.2,
      'durationMinutes': 0,
      'stops': [
        _stop('Not visited', 'Pending'),
        _stop('Current stop', 'Next'),
        _stop('Skipped', 'Skipped', skipped: true),
        _stop('Short', 'Collected', clear: 10, coloured: 5),
        _stop('On target', 'Collected', clear: 45, coloured: 18),
      ],
    });

    expect(data.shortfalls, 1); // only "Short"
    expect(data.pendingCount, 2);
    expect(data.skippedCount, 1);
    expect(data.stops[0].belowExpected, isFalse);
    expect(data.stops[1].belowExpected, isFalse);
    expect(data.stops[2].belowExpected, isFalse);
    expect(data.stops[3].belowExpected, isTrue);
    expect(data.stops[4].belowExpected, isFalse);
  });

  test('an in-progress trip with nothing collected has zero shortfalls', () {
    final data = TripReportData.fromSummaryJson({
      'totalDistanceKm': 120.2,
      'durationMinutes': 0,
      'stops': [_stop('A', 'Next'), _stop('B', 'Pending')],
    });

    expect(data.shortfalls, 0);
    expect(data.totalClearKg, 0);
    expect(data.duration, isNull);
  });

  test('PDF renders pending stops', () async {
    final data = TripReportData.fromSummaryJson({
      'totalDistanceKm': 10,
      'durationMinutes': 0,
      'stops': [_stop('A', 'Next'), _stop('B', 'Pending')],
    });
    final bytes = await ReportPdfService().buildBytes(data);
    expect(bytes.length, greaterThan(1000));
  });
}
