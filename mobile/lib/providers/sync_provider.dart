import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../db/database_helper.dart';

class SyncProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final DatabaseHelper _db = DatabaseHelper();

  bool _isSyncing = false;
  bool _syncComplete = false;
  String? _error;

  bool get isSyncing => _isSyncing;
  bool get syncComplete => _syncComplete;
  String? get error => _error;

  Future<void> sync(int tripId) async {
    _isSyncing = true;
    _syncComplete = false;
    _error = null;
    notifyListeners();

    try {
      final unsynced = await _db.getUnsyncedCollections();

      if (unsynced.isEmpty) {
        _syncComplete = true;
        _isSyncing = false;
        notifyListeners();
        return;
      }

      final success = await _apiService.syncCollections(tripId, unsynced);

      if (success) {
        for (final record in unsynced) {
          await _db.markCollectionSynced(record.supplierId);
        }
        _syncComplete = true;
        await _db.clearAll();
      } else {
        _error = 'Sync failed. Please try again.';
      }
    } catch (e) {
      _error = 'Sync failed: ${e.toString()}';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
