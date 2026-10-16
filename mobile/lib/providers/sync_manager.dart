import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../db/database_helper.dart';
import '../models/collection_record.dart';
import '../models/skip_record.dart';
import '../models/trip.dart';
import '../services/api_service.dart';

class FlushResult {
  /// True if everything queued reached the server.
  final bool allSynced;

  /// The most recent trip returned by the server (after a skip), if any.
  final Trip? latestTrip;

  const FlushResult({required this.allSynced, this.latestTrip});
}

/// The offline queue. Collections, skips and proof photos are always written to
/// SQLite first; this class pushes them to the server in the order they
/// happened, whenever the network allows, and exposes their state to the UI.
class SyncManager with ChangeNotifier {
  SyncManager({ApiService? api, DatabaseHelper? db, Connectivity? connectivity})
    : _api = api ?? ApiService(),
      _db = db ?? DatabaseHelper(),
      _connectivity = connectivity ?? Connectivity() {
    _init();
  }

  final ApiService _api;
  final DatabaseHelper _db;
  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _retryTimer;
  Timer? _flashTimer;
  Future<FlushResult>? _running;

  bool _isOnline = true;
  bool _isSyncing = false;
  bool _justSynced = false;
  bool _lastAttemptFailed = false;
  int _pendingCount = 0;

  /// Called after a background flush that changed server state, so the route
  /// can be refreshed. Set by [TripProvider].
  VoidCallback? onSynced;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;

  /// Briefly true after the queue empties, for a "synced" confirmation.
  bool get justSynced => _justSynced;

  /// True if the last flush attempt could not reach the server.
  bool get lastAttemptFailed => _lastAttemptFailed;

  /// Collections + skips + photos not yet confirmed by the server.
  int get pendingCount => _pendingCount;

  Future<void> _init() async {
    await refreshPending();

    final initial = await _connectivity.checkConnectivity();
    _isOnline = _online(initial);
    notifyListeners();

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = _online(results);
      notifyListeners();
      if (_isOnline && !wasOnline && _pendingCount > 0) {
        // Give the connection a moment to settle before hitting the server.
        Future.delayed(const Duration(seconds: 1), flush);
      }
    });

    // Safety net: retries when the network is "up" but the server was not
    // reachable, or the connectivity event was missed.
    _retryTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (_isOnline && _pendingCount > 0 && !_isSyncing) flush();
    });

    if (_pendingCount > 0 && _isOnline) flush();
  }

  static bool _online(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  /// Recounts what is waiting. Call after any local write.
  Future<void> refreshPending() async {
    final skips = (await _db.getPendingSkips()).length;
    final collections = (await _db.getUnsyncedCollections()).length;
    final photos = (await _db.getPendingPhotos()).length;
    final signatures = (await _db.getPendingSignatures()).length;
    _pendingCount = skips + collections + photos + signatures;
    notifyListeners();
  }

  /// Pushes everything queued. Concurrent calls share one run. Set
  /// [notifyTrip] to false when the caller refreshes the route itself.
  Future<FlushResult> flush({bool notifyTrip = true}) {
    return _running ??= _flush(notifyTrip).whenComplete(() => _running = null);
  }

  Future<FlushResult> _flush(bool notifyTrip) async {
    await refreshPending();
    if (_pendingCount == 0) {
      return const FlushResult(allSynced: true);
    }

    _isSyncing = true;
    notifyListeners();

    var failed = false;
    Trip? latestTrip;

    try {
      // Skips and collections replay in the order they happened: a skip
      // re-optimises the route, so the sequence matters to the server.
      final events = <_Event>[
        for (final s in await _db.getPendingSkips())
          _Event(DateTime.parse(s.skippedAt), skip: s),
        for (final c in await _db.getUnsyncedCollections())
          _Event(DateTime.parse(c.collectedAt), collection: c),
      ]..sort((a, b) => a.at.compareTo(b.at));

      for (final e in events) {
        if (e.skip != null) {
          final (result, trip) = await _api.postSkip(e.skip!);
          if (result == SendResult.retry) {
            failed = true;
            break;
          }
          // A rejected skip can never succeed; drop it so it can't block the queue.
          await _db.markSkipSynced(e.skip!.id!);
          latestTrip = trip ?? latestTrip;
        } else {
          final c = e.collection!;
          final result = await _api.postCollection(c, c.tripId);
          if (result == SendResult.retry) {
            failed = true;
            break;
          }
          await _db.markCollectionSynced(c.supplierId);
        }
      }

      // Photos need their collection to exist on the server first.
      if (!failed) {
        for (final c in await _db.getPendingPhotos()) {
          final result = await _api.uploadPhoto(
            c.tripId,
            c.supplierId,
            c.photoPath!,
          );
          if (result == SendResult.retry) {
            failed = true;
            break;
          }
          await _db.markPhotoSynced(c.supplierId);
        }
      }

      // Signatures follow the same rule as photos.
      if (!failed) {
        for (final c in await _db.getPendingSignatures()) {
          final result = await _api.uploadSignature(
            c.tripId,
            c.supplierId,
            c.signaturePath!,
            c.signerName,
          );
          if (result == SendResult.retry) {
            failed = true;
            break;
          }
          await _db.markSignatureSynced(c.supplierId);
        }
      }
    } catch (_) {
      failed = true;
    }

    _lastAttemptFailed = failed;
    _isSyncing = false;
    await refreshPending();

    if (!failed && _pendingCount == 0) {
      _flash();
      if (notifyTrip) onSynced?.call();
    }

    return FlushResult(allSynced: !failed, latestTrip: latestTrip);
  }

  void _flash() {
    _justSynced = true;
    notifyListeners();
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 2500), () {
      _justSynced = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _retryTimer?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }
}

class _Event {
  _Event(this.at, {this.skip, this.collection});

  final DateTime at;
  final SkipRecord? skip;
  final CollectionRecord? collection;
}
