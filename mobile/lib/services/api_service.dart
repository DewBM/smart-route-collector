import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/skip_record.dart';
import '../models/supplier_detail.dart';
import '../models/trip.dart';
import '../models/analytics.dart';
import '../models/collection_record.dart';
import '../models/trip_report.dart';

/// Outcome of pushing one queued record.
/// - [ok]: the server has it.
/// - [retry]: network or server problem; keep it queued and try again later.
/// - [rejected]: the server refused it permanently (4xx); retrying can't help.
enum SendResult { ok, retry, rejected }

SendResult _resultFor(int status) {
  if (status >= 200 && status < 300) return SendResult.ok;
  if (status >= 400 && status < 500 && status != 408 && status != 429) {
    return SendResult.rejected;
  }
  return SendResult.retry;
}

class ApiService {
  /// Defaults to the hosted backend. Override for local development, e.g.
  /// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5082`
  /// (10.0.2.2 is the host machine as seen from the Android emulator).
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://smart-route-backend-production.up.railway.app',
  );

  Future<Trip> fetchTodaysTrip() async {
    final response = await http.get(Uri.parse('$baseUrl/api/trips/today'));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Trip.fromJson(json);
    }

    throw Exception('Failed to fetch trip: ${response.statusCode}');
  }

  Future<SendResult> postCollection(CollectionRecord record, int tripId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/collections'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'tripId': tripId,
              'supplierId': record.supplierId,
              'clearKg': record.clearKg,
              'colouredKg': record.colouredKg,
              'condition': record.condition,
              'collectedAt': record.collectedAt,
            }),
          )
          .timeout(const Duration(seconds: 8));

      return _resultFor(response.statusCode);
    } catch (_) {
      return SendResult.retry;
    }
  }

  Future<bool> syncCollections(
    int tripId,
    List<CollectionRecord> records,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/collections/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tripId': tripId,
          'collections': records
              .map(
                (r) => {
                  'tripId': tripId,
                  'supplierId': r.supplierId,
                  'clearKg': r.clearKg,
                  'colouredKg': r.colouredKg,
                  'condition': r.condition,
                  'collectedAt': r.collectedAt,
                },
              )
              .toList(),
        }),
      );

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Full URL for a server-relative path such as a photo URL.
  static String absoluteUrl(String path) => '$baseUrl$path';

  /// Uploads the proof photo for an already-recorded collection.
  Future<SendResult> uploadPhoto(
    int tripId,
    int supplierId,
    String filePath,
  ) async {
    try {
      final request =
          http.MultipartRequest(
              'POST',
              Uri.parse('$baseUrl/api/collections/photo'),
            )
            ..fields['tripId'] = '$tripId'
            ..fields['supplierId'] = '$supplierId'
            ..files.add(
              await http.MultipartFile.fromPath(
                'file',
                filePath,
                contentType: MediaType('image', 'jpeg'),
              ),
            );

      final response = await request.send().timeout(
        const Duration(seconds: 30),
      );
      return _resultFor(response.statusCode);
    } catch (_) {
      return SendResult.retry;
    }
  }

  /// Uploads the supplier's signature PNG for an already-recorded collection.
  Future<SendResult> uploadSignature(
    int tripId,
    int supplierId,
    String filePath,
    String? signerName,
  ) async {
    try {
      final request =
          http.MultipartRequest(
              'POST',
              Uri.parse('$baseUrl/api/collections/signature'),
            )
            ..fields['tripId'] = '$tripId'
            ..fields['supplierId'] = '$supplierId'
            ..files.add(
              await http.MultipartFile.fromPath(
                'file',
                filePath,
                contentType: MediaType('image', 'png'),
              ),
            );
      if (signerName != null) request.fields['signerName'] = signerName;

      final response = await request.send().timeout(
        const Duration(seconds: 30),
      );
      return _resultFor(response.statusCode);
    } catch (_) {
      return SendResult.retry;
    }
  }

  /// Reports a skipped stop. On success the server has re-optimised the
  /// remaining route and returns the updated trip.
  Future<(SendResult, Trip?)> postSkip(SkipRecord skip) async {
    try {
      final response = await http
          .post(
            Uri.parse(
              '$baseUrl/api/trips/${skip.tripId}/stops/${skip.supplierId}/skip',
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'reason': skip.reason,
              'note': skip.note,
              'skippedAt': skip.skippedAt,
            }),
          )
          .timeout(const Duration(seconds: 8));

      final result = _resultFor(response.statusCode);
      if (result != SendResult.ok) return (result, null);
      return (
        result,
        Trip.fromJson(jsonDecode(response.body) as Map<String, dynamic>),
      );
    } catch (_) {
      return (SendResult.retry, null);
    }
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final response = await http
        .get(Uri.parse('$baseUrl$path'))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return {'data': jsonDecode(response.body)};
    }
    throw Exception('Request failed (${response.statusCode})');
  }

  Future<List<TripHistoryItem>> fetchHistory() async {
    final res = await _getJson('/api/trips/history');
    return (res['data'] as List)
        .map((j) => TripHistoryItem.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<TripReportData> fetchTripReport(int tripId) async {
    final res = await _getJson('/api/trips/$tripId/summary');
    return TripReportData.fromSummaryJson(res['data'] as Map<String, dynamic>);
  }

  Future<Insights> fetchInsights(int days) async {
    final res = await _getJson('/api/insights?days=$days');
    return Insights.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<SupplierHistory> fetchSupplierHistory(int supplierId) async {
    final res = await _getJson('/api/suppliers/$supplierId');
    return SupplierHistory.fromJson(res['data'] as Map<String, dynamic>);
  }
}
