import 'package:flutter/foundation.dart';
import '../models/skip_record.dart';
import '../models/trip.dart';
import '../models/trip_stop.dart';
import '../services/api_service.dart';
import '../db/database_helper.dart';
import 'sync_manager.dart';

class TripProvider with ChangeNotifier {
  TripProvider(this._sync) {
    // After a background sync, pull the server's (possibly re-optimised) route.
    _sync.onSynced = loadTrip;
  }

  final SyncManager _sync;
  final ApiService _apiService = ApiService();
  final DatabaseHelper _db = DatabaseHelper();

  Trip? _trip;
  List<TripStop> _stops = [];
  bool _isLoading = false;
  String? _error;
  bool _fromCache = false;

  Trip? get trip => _trip;
  List<TripStop> get stops => _stops;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// True when the trip shown was loaded from the local cache (offline).
  bool get fromCache => _fromCache;

  TripStop? get currentStop => _stops.isEmpty
      ? null
      : _stops.firstWhere((s) => s.status == 'Next', orElse: () => _stops.last);

  /// A stop is finished once it is collected or skipped.
  static bool _isFinished(TripStop s) =>
      s.status == 'Collected' || s.status == 'Skipped';

  bool get isTripComplete => _stops.isNotEmpty && _stops.every(_isFinished);

  int get finishedStops => _stops.where(_isFinished).length;

  int get skippedStops => _stops.where((s) => s.status == 'Skipped').length;

  int get remainingStops =>
      _stops.where((s) => s.status == 'Pending' || s.status == 'Next').length;

  Future<void> loadTrip() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Anything recorded offline must reach the server first, or it would
      // still report those stops as pending.
      await _sync.flush(notifyTrip: false);

      final trip = await _apiService.fetchTodaysTrip();
      await _overlayUnsynced(trip.stops);
      await _applyTrip(trip);
    } catch (e) {
      final cachedStops = await _db.getCachedStops();
      final cachedMeta = await _db.getCachedTripMeta();

      if (cachedStops.isNotEmpty && cachedMeta != null) {
        _stops = cachedStops;
        _fromCache = true;
        _trip = Trip(
          tripId: cachedMeta['tripId'] as int,
          tripDate: cachedMeta['tripDate'] as String,
          totalDistanceKm: cachedMeta['totalDistanceKm'] as double,
          stops: cachedStops,
        );
      } else {
        _error = 'No internet connection and no cached trip available.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _applyTrip(Trip trip) async {
    await _db.cacheTripStops(
      trip.tripId,
      trip.tripDate,
      trip.totalDistanceKm,
      trip.stops,
    );
    _trip = trip;
    _stops = trip.stops;
    _fromCache = false;
  }

  /// If some local changes could not be uploaded, the server's copy is behind.
  /// Re-apply them on top so the collector never sees a stop they already
  /// handled come back as pending.
  Future<void> _overlayUnsynced(List<TripStop> stops) async {
    final collected = (await _db.getUnsyncedCollections()).map(
      (c) => c.supplierId,
    );
    final skipped = {
      for (final s in await _db.getPendingSkips()) s.supplierId: s.reason,
    };

    for (final stop in stops) {
      if (collected.contains(stop.supplierId)) {
        stop.status = 'Collected';
      } else if (skipped.containsKey(stop.supplierId)) {
        stop
          ..status = 'Skipped'
          ..skipReason = skipped[stop.supplierId];
      }
    }

    // The server's "Next" may be a stop we already finished; make sure one
    // unfinished stop is Next.
    final hasNext = stops.any((s) => s.status == 'Next');
    if (!hasNext) {
      final firstPending = stops
          .where((s) => s.status == 'Pending')
          .firstOrNull;
      firstPending?.status = 'Next';
    }
  }

  Future<void> advanceStop(int completedSupplierId) async {
    await _db.updateStopStatus(completedSupplierId, 'Collected');

    final completedIndex = _stops.indexWhere(
      (s) => s.supplierId == completedSupplierId,
    );

    if (completedIndex != -1) {
      _stops[completedIndex].status = 'Collected';
    }

    await _promoteNextPending();
    notifyListeners();
  }

  /// Skips a stop. Saved locally first so it works offline; the server
  /// re-optimises the remaining route when it can be reached. Returns true if
  /// the server confirmed (and the route may have been re-ordered).
  Future<bool> skipStop({
    required int supplierId,
    required String reason,
    String? note,
  }) async {
    final record = SkipRecord(
      tripId: _trip!.tripId,
      supplierId: supplierId,
      reason: reason,
      note: note,
      skippedAt: DateTime.now().toUtc().toIso8601String(),
    );

    // Queue it locally and show the stop as skipped straight away.
    await _db.insertSkip(record);
    await _db.markStopSkipped(supplierId, reason);
    final index = _stops.indexWhere((s) => s.supplierId == supplierId);
    if (index != -1) {
      _stops[index]
        ..status = 'Skipped'
        ..skipReason = reason;
    }
    await _promoteNextPending();
    notifyListeners();

    await _sync.refreshPending();

    // Try to reach the server now so the route is re-optimised straight away.
    var result = await _sync.flush(notifyTrip: false);
    if (result.latestTrip == null &&
        result.allSynced &&
        (await _db.getPendingSkips()).isNotEmpty) {
      // A flush that started before this skip was queued has just finished.
      result = await _sync.flush(notifyTrip: false);
    }
    final updated = result.latestTrip;
    if (updated == null) return false;

    await _overlayUnsynced(updated.stops);
    await _applyTrip(updated);
    notifyListeners();
    return true;
  }

  Future<void> _promoteNextPending() async {
    if (_stops.any((s) => s.status == 'Next')) return;
    final next = _stops.where((s) => s.status == 'Pending').firstOrNull;
    if (next == null) return;
    await _db.updateStopStatus(next.supplierId, 'Next');
    next.status = 'Next';
  }
}
