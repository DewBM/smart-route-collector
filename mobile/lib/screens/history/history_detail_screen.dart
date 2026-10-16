import 'package:flutter/material.dart';
import '../../models/analytics.dart';
import '../../models/trip_report.dart';
import '../../services/api_service.dart';
import '../../widgets/state_views.dart';
import '../../theme/app_tokens.dart';
import '../trip_report/trip_report_screen.dart';

/// Loads a past trip's summary from the server, then shows it in the regular
/// (read-only) trip report screen.
class HistoryDetailScreen extends StatefulWidget {
  const HistoryDetailScreen({super.key, required this.trip});

  final TripHistoryItem trip;

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  late Future<TripReportData> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService().fetchTripReport(widget.trip.tripId);
  }

  void _retry() => setState(
    () => _future = ApiService().fetchTripReport(widget.trip.tripId),
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TripReportData>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasData) return TripReportScreen(data: snap.data);

        return Scaffold(
          appBar: AppBar(),
          body: snap.hasError
              ? ErrorState(
                  message: "Couldn't load this trip. Check your connection.",
                  onRetry: _retry,
                )
              : const Padding(
                  padding: EdgeInsets.all(Gap.lg),
                  child: Column(
                    children: [
                      SkeletonBox(height: 160, radius: Corners.lg),
                      SizedBox(height: Gap.lg),
                      SkeletonBox(height: 150, radius: Corners.lg),
                      SizedBox(height: Gap.lg),
                      SkeletonBox(height: 110, radius: Corners.lg),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
