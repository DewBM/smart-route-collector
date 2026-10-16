import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../db/database_helper.dart';
import 'sync_manager.dart';

class SyncProvider with ChangeNotifier {
  SyncProvider(this._manager);

  final SyncManager _manager;
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

      if (unsynced.isNotEmpty) {
        final success = await _apiService.syncCollections(tripId, unsynced);

        if (!success) {
          _error = 'Sync failed. Please try again.';
          return;
        }

        for (final record in unsynced) {
          await _db.markCollectionSynced(record.supplierId);
        }
      }

      // Proof photos go up after their collections exist on the server.
      final photos = await _db.getPendingPhotos();
      var failed = 0;
      for (final record in photos) {
        final result = await _apiService.uploadPhoto(
          record.tripId,
          record.supplierId,
          record.photoPath!,
        );
        if (result != SendResult.retry) {
          await _db.markPhotoSynced(record.supplierId);
        } else {
          failed++;
        }
      }

      for (final record in await _db.getPendingSignatures()) {
        final result = await _apiService.uploadSignature(
          record.tripId,
          record.supplierId,
          record.signaturePath!,
          record.signerName,
        );
        if (result != SendResult.retry) {
          await _db.markSignatureSynced(record.supplierId);
        } else {
          failed++;
        }
      }

      if (failed > 0) {
        _error = failed == 1
            ? 'One attachment could not be uploaded.'
            : '$failed attachments could not be uploaded.';
        return;
      }

      _syncComplete = true;
      if (unsynced.isNotEmpty) {
        await _db.clearAll();
      }
    } catch (e) {
      _error = 'Sync failed: ${e.toString()}';
    } finally {
      _isSyncing = false;
      await _manager.refreshPending();
      notifyListeners();
    }
  }
}
