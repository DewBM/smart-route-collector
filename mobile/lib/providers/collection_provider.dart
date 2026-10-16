import 'package:flutter/foundation.dart';
import '../models/collection_record.dart';
import '../db/database_helper.dart';
import 'sync_manager.dart';

class CollectionProvider with ChangeNotifier {
  CollectionProvider(this._sync);

  final SyncManager _sync;
  final DatabaseHelper _db = DatabaseHelper();

  bool _isSubmitting = false;
  String? _error;

  bool get isSubmitting => _isSubmitting;
  String? get error => _error;

  /// Saves the collection locally (the source of truth while offline) and
  /// queues it for upload. Returns as soon as it is safely stored; the upload
  /// happens in the background and never blocks the collector.
  Future<bool> submitCollection({
    required int tripId,
    required int supplierId,
    required double clearKg,
    required double colouredKg,
    required String condition,
    String? photoPath,
    String? signaturePath,
    String? signerName,
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
      photoPath: photoPath,
      signaturePath: signaturePath,
      signerName: signerName,
    );

    await _db.insertCollection(record);
    await _sync.refreshPending();

    // Fire and forget: the queue shows its own progress.
    _sync.flush();

    _isSubmitting = false;
    notifyListeners();
    return true;
  }
}
