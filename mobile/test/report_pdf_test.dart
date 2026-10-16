import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_route/models/trip_report.dart';
import 'package:smart_route/services/report_pdf_service.dart';

const _data = TripReportData(
  tripDate: '9/29/2026',
  distanceKm: 120.2,
  duration: Duration(hours: 2, minutes: 5),
  stops: [
    StopReport(
      supplierName: 'Kurunegala Waste Recycling',
      condition: 'Clean',
      collectedClearKg: 40,
      collectedColouredKg: 20,
      expectedClearKg: 40,
      expectedColouredKg: 20,
      signedBy: 'A. Perera',
    ),
    StopReport(
      supplierName: 'Short Supplier',
      condition: 'Broken',
      collectedClearKg: 10,
      collectedColouredKg: 5,
      expectedClearKg: 40,
      expectedColouredKg: 20,
    ),
    StopReport(
      supplierName: 'Closed Supplier',
      condition: null,
      collectedClearKg: 0,
      collectedColouredKg: 0,
      expectedClearKg: 30,
      expectedColouredKg: 10,
      skipped: true,
      skipReason: 'Supplier closed',
    ),
  ],
);

void main() {
  test('builds a valid PDF for ok, shortfall and skipped stops', () async {
    final bytes = await ReportPdfService().buildBytes(_data);
    expect(bytes.length, greaterThan(1000));
    expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
  });

  test('handles a long report across several pages', () async {
    final many = TripReportData(
      tripDate: '2026-09-29',
      distanceKm: 300,
      duration: null,
      stops: List.generate(80, (i) => _data.stops[i % 3]),
    );
    final bytes = await ReportPdfService().buildBytes(many);
    expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
  });

  test('file name is derived from the trip date', () {
    expect(
      ReportPdfService.fileName(_data),
      'glassline-trip-report-2026-09-29.pdf',
    );
    expect(
      ReportPdfService.fileName(
        const TripReportData(
          tripDate: null,
          distanceKm: 0,
          duration: null,
          stops: [],
        ),
      ),
      'glassline-trip-report.pdf',
    );
  });
}
