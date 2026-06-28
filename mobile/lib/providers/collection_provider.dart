import 'package:flutter/foundation.dart';
import '../models/collection_record.dart';
import '../services/api_service.dart';
import '../db/database_helper.dart';

class CollectionProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final DatabaseHelper _db = DatabaseHelper();

  bool _isSubmitting = false;
  String? _error;

  bool get isSubmitting => _isSubmitting;
  String? get error => _error;

  Future<bool> submitCollection({
    required int tripId,
    required int supplierId,
    required double clearKg,
    required double colouredKg,
    required String condition,
  }) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();

    final record = CollectionRecord(
      tripId: tripId,
      supplierId: supplierId,
      clearKg: clearKg,
      colouredKg: colouredKg,
      condition: condition,
      collectedAt: DateTime.now().toUtc().toIso8601String(),
    );

    await _db.insertCollection(record);

    final success = await _apiService.postCollection(record, tripId);

    if (success) {
      await _db.markCollectionSynced(supplierId);
    }

    _isSubmitting = false;
    notifyListeners();

    return true;
  }
}
