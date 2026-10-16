import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../models/analytics.dart';
import '../../providers/analytics_provider.dart';
import '../../theme/app_tokens.dart';
import '../../utils/format.dart';
import '../../widgets/hero_header.dart';
import '../../widgets/progress_ring.dart';
import '../../widgets/section_header.dart';
import '../../widgets/state_views.dart';

const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final a = context.watch<AnalyticsProvider>();
    final data = a.insights;

    return Column(
      children: [
        HeroHeader(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LAST ${a.insightsDays} DAYS',
                style: context.text.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: data?.totalKg ?? 0),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => Text(
                      formatKg(double.parse(v.toStringAsFixed(1))),
                      style: context.text.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Text(
                    'kg collected',
                    style: context.text.titleMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, 0),
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 7, label: Text('7 days')),
              ButtonSegment(value: 30, label: Text('30 days')),
            ],
            selected: {a.insightsDays},
            onSelectionChanged: (v) => a.loadInsights(days: v.first),
          ),
        ),
        Expanded(child: _body(context, a)),
      ],
    );
  }

  Widget _body(BuildContext context, AnalyticsProvider a) {
    final data = a.insights;

    if (a.insightsLoading && data == null) return const _Skeleton();

    if (a.insightsError != null && data == null) {
      return ErrorState(message: a.insightsError!, onRetry: a.loadInsights);
    }

    if (data == null || data.stopCount == 0) {
      return const EmptyState(
        title: 'No data yet',
        message: 'Complete a trip to see collection insights here.',
      );
    }

    return RefreshIndicator(
      onRefresh: a.loadInsights,
      child: ListView(
        padding: const EdgeInsets.all(Gap.lg),
        children:
            [
                  _StatGrid(data: data),
                  const SizedBox(height: Gap.lg),
                  _DailyChart(data: data),
                  const SizedBox(height: Gap.lg),
                  _ShortfallCard(rate: data.shortfallRate),
                  if (data.topSuppliers.isNotEmpty) ...[
                    const SizedBox(height: Gap.lg),
                    _TopSuppliers(suppliers: data.topSuppliers),
                  ],
                ]
                .animate(interval: 70.ms)
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.06, end: 0),
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.data});

  final Insights data;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.local_shipping_outlined, '${data.tripCount}', 'Trips'),
      (Icons.pin_drop_outlined, '${data.stopCount}', 'Stops'),
      (
        Icons.scale_rounded,
        '${formatKg(double.parse(data.averageKgPerStop.toStringAsFixed(1)))} kg',
        'Avg per stop',
      ),
      (
        Icons.route_rounded,
        '${data.totalDistanceKm.toStringAsFixed(0)} km',
        'Distance',
      ),
    ];

    return GridView.count(
      // Without this the grid adds the status-bar inset as top padding.
      padding: EdgeInsets.zero,
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: Gap.md,
      crossAxisSpacing: Gap.md,
      childAspectRatio: 2.1,
      children: [
        for (final (icon, value, label) in items)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: context.colors.primary.withValues(alpha: 0.12),
                      borderRadius: Corners.smAll,
                    ),
                    child: Icon(icon, size: 20, color: context.colors.primary),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(value, style: context.text.titleMedium),
                        ),
                        Text(
                          label,
                          style: context.text.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.data});

  final Insights data;

  @override
  Widget build(BuildContext context) {
    final clearColor = context.colors.primary;
    const colouredColor = Brand.violet;
    final days = data.daily;
    final maxY = days
        .map((d) => d.totalKg)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final compact = days.length > 10;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              'Daily collection',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Dot(clearColor, 'Clear'),
                  const SizedBox(width: Gap.md),
                  _Dot(colouredColor, 'Coloured'),
                ],
              ),
            ),
            const SizedBox(height: Gap.lg),
            SizedBox(
              height: 190,
              child: BarChart(
                BarChartData(
                  maxY: maxY == 0 ? 10 : maxY * 1.15,
                  alignment: BarChartAlignment.spaceAround,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: context.colors.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (v, meta) => v == meta.max
                            ? const SizedBox.shrink()
                            : SideTitleWidget(
                                meta: meta,
                                child: Text(
                                  _compactKg(v),
                                  style: context.text.labelSmall?.copyWith(
                                    color: context.colors.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          if (i < 0 || i >= days.length) {
                            return const SizedBox.shrink();
                          }
                          final d = days[i].date;
                          // 30 days: label roughly every 5th bar only.
                          if (compact && i % 5 != 0) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              compact ? '${d.day}' : _weekdays[d.weekday - 1],
                              style: context.text.labelSmall?.copyWith(
                                color: context.colors.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                        '${formatKg(double.parse(rod.toY.toStringAsFixed(1)))} kg',
                        TextStyle(
                          color: context.colors.onInverseSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < days.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: days[i].totalKg,
                            width: compact ? 5 : 16,
                            borderRadius: BorderRadius.circular(4),
                            rodStackItems: [
                              BarChartRodStackItem(
                                0,
                                days[i].clearKg,
                                clearColor,
                              ),
                              BarChartRodStackItem(
                                days[i].clearKg,
                                days[i].totalKg,
                                colouredColor,
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
                duration: const Duration(milliseconds: 600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color, this.label);

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: context.text.bodySmall),
    ],
  );
}

class _ShortfallCard extends StatelessWidget {
  const _ShortfallCard({required this.rate});

  final double rate;

  @override
  Widget build(BuildContext context) {
    final s = context.status;
    final pct = (rate * 100).round();
    // Low shortfall rate is good.
    final color = rate <= 0.15
        ? s.success
        : rate <= 0.35
        ? s.warning
        : context.colors.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Row(
          children: [
            ProgressRing(
              size: 84,
              strokeWidth: 9,
              color: color,
              trackColor: color.withValues(alpha: 0.15),
              progress: rate,
              semanticsLabel: '$pct percent of stops below expected',
              center: Text('$pct%', style: context.text.titleMedium),
            ),
            const SizedBox(width: Gap.xl),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Shortfall rate', style: context.text.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Share of stops where less glass than expected was collected.',
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopSuppliers extends StatelessWidget {
  const _TopSuppliers({required this.suppliers});

  final List<SupplierTotal> suppliers;

  @override
  Widget build(BuildContext context) {
    final max = suppliers.first.totalKg;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('Top suppliers'),
            const SizedBox(height: Gap.lg),
            for (final (i, s) in suppliers.indexed) ...[
              Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(
                      '${i + 1}',
                      style: context.text.labelLarge?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Text(
                    '${formatKg(double.parse(s.totalKg.toStringAsFixed(1)))} kg',
                    style: context.text.labelLarge,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 22),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Corners.pill),
                  child: LinearProgressIndicator(
                    value: max == 0 ? 0 : s.totalKg / max,
                    minHeight: 6,
                    backgroundColor: context.colors.primary.withValues(
                      alpha: 0.12,
                    ),
                  ),
                ),
              ),
              if (i != suppliers.length - 1) const SizedBox(height: Gap.md),
            ],
          ],
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(Gap.lg),
    children: const [
      SkeletonBox(height: 140, radius: Corners.lg),
      SizedBox(height: Gap.lg),
      SkeletonBox(height: 230, radius: Corners.lg),
      SizedBox(height: Gap.lg),
      SkeletonBox(height: 110, radius: Corners.lg),
    ],
  );
}

/// 1500 -> "1.5k", 1000 -> "1k", 250 -> "250". Keeps axis labels on one line.
String _compactKg(double v) {
  if (v < 1000) return formatKg(v);
  final k = v / 1000;
  return '${k == k.roundToDouble() ? k.toStringAsFixed(0) : k.toStringAsFixed(1)}k';
}
