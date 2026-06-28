import 'package:flutter/foundation.dart';
import '../models/trip.dart';
import '../models/trip_stop.dart';
import '../services/api_service.dart';
import '../db/database_helper.dart';

class TripProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final DatabaseHelper _db = DatabaseHelper();

  Trip? _trip;
  List<TripStop> _stops = [];
  bool _isLoading = false;
  String? _error;

  Trip? get trip => _trip;
  List<TripStop> get stops => _stops;
  bool get isLoading => _isLoading;
  String? get error => _error;

  TripStop? get currentStop =>
      _stops.isEmpty ? null : _stops.firstWhere(
        (s) => s.status == 'Next',
        orElse: () => _stops.last,
      );

  bool get isTripComplete =>
      _stops.isNotEmpty && _stops.every((s) => s.status == 'Collected');

  int get remainingStops =>
      _stops.where((s) => s.status == 'Pending' || s.status == 'Next').length;

  Future<void> loadTrip() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final trip = await _apiService.fetchTodaysTrip();

      await _db.cacheTripStops(
        trip.tripId,
        trip.tripDate,
        trip.totalDistanceKm,
        trip.stops,
      );

      _trip = trip;
      _stops = trip.stops;
    } catch (e) {
      final cachedStops = await _db.getCachedStops();
      final cachedMeta = await _db.getCachedTripMeta();

      if (cachedStops.isNotEmpty && cachedMeta != null) {
        _stops = cachedStops;
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

  Future<void> advanceStop(int completedSupplierId) async {
    await _db.updateStopStatus(completedSupplierId, 'Collected');

    final completedIndex = _stops.indexWhere(
      (s) => s.supplierId == completedSupplierId,
    );

    if (completedIndex != -1) {
      _stops[completedIndex].status = 'Collected';
    }

    final nextStop = _stops.firstWhere(
      (s) => s.status == 'Pending',
      orElse: () => _stops.last,
    );

    if (nextStop.status == 'Pending') {
      await _db.updateStopStatus(nextStop.supplierId, 'Next');
      nextStop.status = 'Next';
    }

    notifyListeners();
  }
}
