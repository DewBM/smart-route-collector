import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../models/trip_stop.dart';
import '../../providers/trip_provider.dart';
import '../../theme/app_tokens.dart';
import '../../utils/format.dart';
import '../../widgets/hero_header.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/progress_ring.dart';
import '../../widgets/state_views.dart';
import '../../widgets/stat_tile.dart';
import '../scan_collect/scan_collect_screen.dart';
import '../trip_report/trip_report_screen.dart';
import '../../utils/navigation.dart';
import '../../utils/routes.dart';
import 'route_map_screen.dart';
import 'supplier_sheet.dart';
import 'stop_timeline_tile.dart';

class TripSequenceScreen extends StatefulWidget {
  const TripSequenceScreen({super.key});

  @override
  State<TripSequenceScreen> createState() => _TripSequenceScreenState();
}

class _TripSequenceScreenState extends State<TripSequenceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TripProvider>().loadTrip();
    });
  }

  Future<void> _openScan(TripStop stop) async {
    await Navigator.push(context, appRoute(ScanCollectScreen(stop: stop)));
    if (mounted) context.read<TripProvider>().loadTrip();
  }

  void _openReport() =>
      Navigator.push(context, appRoute(const TripReportScreen()));

  @override
  Widget build(BuildContext context) {
    final trip = context.watch<TripProvider>();
    final hasData = trip.stops.isNotEmpty;

    return Scaffold(
      body: Column(
        children: [
          _Header(
            trip: trip,
            onMap: () =>
                Navigator.push(context, appRoute(const RouteMapScreen())),
          ),
          Expanded(child: _buildBody(trip, hasData)),
        ],
      ),
      bottomNavigationBar: trip.isTripComplete
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Gap.lg),
                child: PrimaryButton(
                  label: 'View trip report',
                  icon: Icons.assessment_rounded,
                  onPressed: _openReport,
                ),
              ),
            ).animate().slideY(begin: 1, end: 0, duration: 400.ms).fadeIn()
          : null,
    );
  }

  Widget _buildBody(TripProvider trip, bool hasData) {
    // Keep showing the previous data during a background refresh.
    if (trip.isLoading && !hasData) return const _Skeleton();

    if (trip.error != null && !hasData) {
      return ErrorState(message: trip.error!, onRetry: trip.loadTrip);
    }

    if (!hasData) {
      return const EmptyState(
        title: 'No stops today',
        message: 'There are no suppliers scheduled for collection today.',
      );
    }

    return _TimelineList(trip: trip, onScan: _openScan);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.trip, required this.onMap});

  final TripProvider trip;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    final total = trip.stops.length;
    final done = trip.finishedStops;
    final date = trip.trip == null ? '' : formatTripDate(trip.trip!.tripDate);

    return HeroHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date.isEmpty ? 'Glassline' : date.toUpperCase(),
                      style: context.text.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Today's route",
                      style: context.text.headlineMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  foregroundColor: Colors.white,
                ),
                tooltip: 'Route overview',
                onPressed: trip.stops.isEmpty ? null : onMap,
                icon: const Icon(Icons.map_rounded),
              ),
              const SizedBox(width: Gap.sm),
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  foregroundColor: Colors.white,
                ),
                tooltip: 'Refresh',
                onPressed: trip.isLoading ? null : trip.loadTrip,
                icon: trip.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: Gap.xl),
          Row(
            children: [
              ProgressRing(
                semanticsLabel: '$done of $total stops done',
                progress: total == 0 ? 0 : done / total,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$done/$total',
                      style: context.text.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'stops',
                      style: context.text.labelSmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.xl),
              Expanded(
                child: StatTile(
                  onHero: true,
                  icon: Icons.route_rounded,
                  value:
                      '${trip.trip?.totalDistanceKm.toStringAsFixed(1) ?? '--'} km',
                  label: 'Total distance',
                ),
              ),
              Expanded(
                child: StatTile(
                  onHero: true,
                  icon: Icons.flag_rounded,
                  value: '${trip.remainingStops}',
                  label: 'Remaining',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineList extends StatelessWidget {
  const _TimelineList({required this.trip, required this.onScan});

  final TripProvider trip;
  final ValueChanged<TripStop> onScan;

  @override
  Widget build(BuildContext context) {
    final stops = trip.stops;
    return RefreshIndicator(
      onRefresh: trip.loadTrip,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
        itemCount: stops.length,
        itemBuilder: (context, i) {
          final stop = stops[i];
          return StopTimelineTile(
                stop: stop,
                isFirst: i == 0,
                isLast: i == stops.length - 1,
                onScan: () => onScan(stop),
                onNavigate: () => navigateToStop(context, stop),
                onTap: () => showSupplierSheet(context, stop),
              )
              .animate()
              .fadeIn(delay: (60 * i).ms, duration: 300.ms)
              .slideY(begin: 0.08, end: 0, delay: (60 * i).ms);
        },
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(Gap.lg),
      children: [
        const SkeletonBox(height: 44, radius: Corners.pill),
        const SizedBox(height: Gap.xl),
        for (var i = 0; i < 4; i++) ...[
          const SkeletonBox(height: 92, radius: Corners.lg),
          const SizedBox(height: Gap.md),
        ],
      ],
    );
  }
}
