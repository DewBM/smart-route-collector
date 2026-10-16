import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/trip_report.dart';
import '../utils/format.dart';

/// Builds a shareable PDF of a trip report. Uses the PDF built-in Helvetica
/// font, so text is limited to Latin-1 (no emoji or special symbols).
class ReportPdfService {
  static const _indigo = PdfColor.fromInt(0xFF4F46E5);
  static const _violet = PdfColor.fromInt(0xFF7C3AED);
  static const _amber = PdfColor.fromInt(0xFFB45309);
  static const _amberBg = PdfColor.fromInt(0xFFFEF3C7);
  static const _green = PdfColor.fromInt(0xFF047857);
  static const _muted = PdfColor.fromInt(0xFF64748B);
  static const _line = PdfColor.fromInt(0xFFE2E8F0);

  /// File name such as glassline-trip-report-2026-09-29.pdf
  static String fileName(TripReportData data) {
    final d = data.tripDate == null ? null : _parseDate(data.tripDate!);
    if (d == null) return 'glassline-trip-report.pdf';
    final stamp =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return 'glassline-trip-report-$stamp.pdf';
  }

  static DateTime? _parseDate(String s) {
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(s);
    return m == null
        ? null
        : DateTime(int.parse(m[3]!), int.parse(m[1]!), int.parse(m[2]!));
  }

  /// Writes the PDF to the temp directory and returns the file.
  Future<File> save(TripReportData data) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${fileName(data)}');
    return file.writeAsBytes(await buildBytes(data));
  }

  Future<Uint8List> buildBytes(TripReportData data) async {
    final doc = pw.Document(
      title: 'Glassline trip report',
      author: 'Glassline',
    );

    final dateLabel = data.tripDate == null
        ? ''
        : formatTripDate(data.tripDate!);
    final total = data.totalClearKg + data.totalColouredKg;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            'Glassline  |  Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: _muted),
          ),
        ),
        build: (ctx) => [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: _indigo,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'TRIP REPORT${dateLabel.isEmpty ? '' : '  |  ${dateLabel.toUpperCase()}'}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  '${formatKg(double.parse(total.toStringAsFixed(1)))} kg collected',
                  style: pw.TextStyle(
                    fontSize: 26,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Row(
            children: [
              _stat('Distance', '${data.distanceKm.toStringAsFixed(1)} km'),
              _stat('Duration', formatDuration(data.duration)),
              _stat('Stops', '${data.stops.length}'),
              _stat(
                'Shortfalls',
                '${data.shortfalls}',
                color: data.shortfalls > 0 ? _amber : _green,
              ),
              if (data.skippedCount > 0)
                _stat('Skipped', '${data.skippedCount}', color: _amber),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Row(
            children: [
              _legend(
                _indigo,
                'Clear glass: ${formatKg(double.parse(data.totalClearKg.toStringAsFixed(1)))} kg',
              ),
              pw.SizedBox(width: 20),
              _legend(
                _violet,
                'Coloured glass: ${formatKg(double.parse(data.totalColouredKg.toStringAsFixed(1)))} kg',
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Stop breakdown',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          _table(data),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _stat(
    String label,
    String value, {
    PdfColor color = PdfColors.black,
  }) {
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.only(right: 8),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _line),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 9, color: _muted),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _legend(PdfColor color, String text) => pw.Row(
    children: [
      pw.Container(width: 9, height: 9, color: color),
      pw.SizedBox(width: 6),
      pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
    ],
  );

  pw.Widget _table(TripReportData data) {
    pw.Widget cell(
      String text, {
      bool bold = false,
      PdfColor? color,
      pw.Alignment? align,
    }) => pw.Container(
      alignment: align ?? pw.Alignment.centerLeft,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );

    String qty(double got, double exp) => '${formatKg(got)} / ${formatKg(exp)}';

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
        children: [
          cell('Supplier', bold: true),
          cell('Clear (kg)', bold: true),
          cell('Coloured (kg)', bold: true),
          cell('Condition', bold: true),
          cell('Status', bold: true),
        ],
      ),
      for (final s in data.stops)
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: s.belowExpected || s.skipped ? _amberBg : null,
            border: const pw.Border(bottom: pw.BorderSide(color: _line)),
          ),
          children: (s.skipped || s.pending)
              ? [
                  cell(s.supplierName),
                  cell('-'),
                  cell('-'),
                  cell(s.skipped ? (s.skipReason ?? '-') : 'Not visited'),
                  s.skipped
                      ? cell('Skipped', bold: true, color: _amber)
                      : cell('Pending', bold: true, color: _muted),
                ]
              : [
                  cell(
                    s.signedBy == null
                        ? s.supplierName
                        : '${s.supplierName}\nSigned by ${s.signedBy}',
                  ),
                  cell(
                    qty(s.collectedClearKg, s.expectedClearKg),
                    color: s.collectedClearKg < s.expectedClearKg
                        ? _amber
                        : null,
                  ),
                  cell(
                    qty(s.collectedColouredKg, s.expectedColouredKg),
                    color: s.collectedColouredKg < s.expectedColouredKg
                        ? _amber
                        : null,
                  ),
                  cell(s.condition ?? '-'),
                  s.belowExpected
                      ? cell('Shortfall', bold: true, color: _amber)
                      : cell('On target', bold: true, color: _green),
                ],
        ),
    ];

    return pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(2.2),
        3: pw.FlexColumnWidth(2),
        4: pw.FlexColumnWidth(1.6),
      },
      children: rows,
    );
  }
}
