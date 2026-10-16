import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../models/analytics.dart';
import '../../providers/analytics_provider.dart';
import '../../theme/app_tokens.dart';
import '../../utils/format.dart';
import '../../utils/routes.dart';
import '../../widgets/hero_header.dart';
import '../../widgets/state_views.dart';
import 'history_detail_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final a = context.watch<AnalyticsProvider>();

    return Column(
      children: [
        HeroHeader(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PAST COLLECTIONS',
                style: context.text.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Trip history',
                style: context.text.headlineMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _body(context, a)),
      ],
    );
  }

  Widget _body(BuildContext context, AnalyticsProvider a) {
    if (a.historyLoading && a.history.isEmpty) return const _Skeleton();

    if (a.historyError != null && a.history.isEmpty) {
      return ErrorState(message: a.historyError!, onRetry: a.loadHistory);
    }

    if (a.history.isEmpty) {
      return const EmptyState(
        title: 'No trips yet',
        message: 'Completed trips will show up here.',
      );
    }

    return RefreshIndicator(
      onRefresh: a.loadHistory,
      child: ListView.separated(
        padding: const EdgeInsets.all(Gap.lg),
        itemCount: a.history.length,
        separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
        itemBuilder: (context, i) => _TripCard(trip: a.history[i])
            .animate()
            .fadeIn(delay: (50 * i).ms)
            .slideY(begin: 0.08, end: 0, delay: (50 * i).ms),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});

  final TripHistoryItem trip;

  @override
  Widget build(BuildContext context) {
    final s = context.status;
    final short = trip.shortfallCount > 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            Navigator.push(context, appRoute(HistoryDetailScreen(trip: trip))),
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatTripDate(trip.tripDate),
                      style: context.text.titleMedium,
                    ),
                  ),
                  _Pill(
                    label: trip.isComplete
                        ? 'Complete'
                        : 'In progress ${trip.collectedCount + trip.skippedCount}/${trip.stopCount}',
                    bg: trip.isComplete ? s.successContainer : s.nextContainer,
                    fg: trip.isComplete ? s.success : s.next,
                  ),
                ],
              ),
              const SizedBox(height: Gap.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    formatKg(double.parse(trip.totalKg.toStringAsFixed(1))),
                    style: context.text.headlineMedium,
                  ),
                  const SizedBox(width: Gap.xs),
                  Text('kg collected', style: context.text.bodySmall),
                ],
              ),
              const SizedBox(height: Gap.md),
              Wrap(
                spacing: Gap.lg,
                runSpacing: Gap.sm,
                children: [
                  _Meta(Icons.pin_drop_outlined, '${trip.stopCount} stops'),
                  _Meta(
                    Icons.route_rounded,
                    '${trip.totalDistanceKm.toStringAsFixed(1)} km',
                  ),
                  if (trip.durationMinutes > 0)
                    _Meta(
                      Icons.timer_outlined,
                      formatDuration(Duration(minutes: trip.durationMinutes)),
                    ),
                  if (trip.skippedCount > 0)
                    _Meta(
                      Icons.skip_next_rounded,
                      '${trip.skippedCount} skipped',
                      color: s.warning,
                    ),
                  if (short)
                    _Meta(
                      Icons.warning_amber_rounded,
                      '${trip.shortfallCount} shortfall${trip.shortfallCount == 1 ? '' : 's'}',
                      color: s.warning,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg, fg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 6),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(Corners.pill),
    ),
    child: Text(
      label,
      style: context.text.labelMedium?.copyWith(
        color: fg,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text, {this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text, style: context.text.bodySmall?.copyWith(color: c)),
        ),
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(Gap.lg),
    children: [
      for (var i = 0; i < 4; i++) ...[
        const SkeletonBox(height: 130, radius: Corners.lg),
        const SizedBox(height: Gap.md),
      ],
    ],
  );
}
