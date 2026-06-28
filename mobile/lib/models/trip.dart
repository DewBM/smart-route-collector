import 'package:smart_route/models/trip_stop.dart';

class Trip {
  final int tripId;
  final String tripDate;
  double totalDistanceKm;
  final List<TripStop> stops;

  Trip({
    required this.tripId,
    required this.tripDate,
    required this.totalDistanceKm,
    required this.stops,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      tripId: json['tripId'] as int,
      tripDate: json['tripDate'] as String,
      totalDistanceKm: (json['totalDistanceKm'] as num).toDouble(),
      stops: (json['stops'] as List<dynamic>)
          .map((s) => TripStop.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}
