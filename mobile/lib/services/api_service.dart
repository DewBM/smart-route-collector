import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import '../models/trip.dart';
import '../models/collection_record.dart';

class ApiService {
  static const String baseUrl =
      'https://smart-route-backend-production.up.railway.app';

  Future<Trip> fetchTodaysTrip() async {
    final response = await http.get(Uri.parse('$baseUrl/api/trips/today'));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Trip.fromJson(json);
    }

    throw Exception('Failed to fetch trip: ${response.statusCode}');
  }

  Future<bool> postCollection(CollectionRecord record, int tripId) async {
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
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (_) {
      return false;
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
}
