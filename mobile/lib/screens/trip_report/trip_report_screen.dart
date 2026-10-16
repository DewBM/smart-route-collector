import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../db/database_helper.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/trip_report.dart';
import '../../services/report_pdf_service.dart';
import '../../providers/sync_provider.dart';
import '../../providers/trip_provider.dart';
import '../../theme/app_tokens.dart';
import '../../utils/format.dart';
import '../../widgets/hero_header.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/proof_photo.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/state_views.dart';
import '../../widgets/status_chip.dart';

class TripReportScreen extends StatefulWidget {
  /// When given, the report shows this (already loaded) data read-only, e.g. a
  /// past trip from History. When null it reads today's trip from the local
  /// database and offers the sync action.
  final TripReportData? data;

  const TripReportScreen({super.key, this.data});

  @override
  State<TripReportScreen> createState() => _TripReportScreenState();
}

class _TripReportScreenState extends State<TripReportScreen> {
  List<StopReport> _stopReports = [];
  double _distanceKm = 0;
  String? _tripDate;
  double _totalClearKg = 0;
  double _totalColouredKg = 0;
  Duration? _tripDuration;
  bool _isLoading = true;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    final data = widget.data;
    if (data != null) {
      _applyData(data);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadFromLocal());
    }
  }

  Future<void> _loadFromLocal() async {
    final db = DatabaseHelper();
    final stops = await db.getCachedStops();
    final collections = await db.getAllCollections();

    final collectionMap = {for (var c in collections) c.supplierId: c};

    DateTime? earliest;
    DateTime? latest;

    final reports = stops.map((stop) {
      final collection = collectionMap[stop.supplierId];
      final clearKg = collection?.clearKg ?? 0;
      final colouredKg = collection?.colouredKg ?? 0;

      if (collection != null) {
        final collectedAt = DateTime.parse(collection.collectedAt);
        if (earliest == null || collectedAt.isBefore(earliest!)) {
          earliest = collectedAt;
        }
        if (latest == null || collectedAt.isAfter(latest!)) {
          latest = collectedAt;
        }
      }

      return StopReport(
        supplierName: stop.supplierName,
        condition: collection?.condition,
        collectedClearKg: clearKg,
        collectedColouredKg: colouredKg,
        expectedClearKg: stop.expectedClearKg,
        expectedColouredKg: stop.expectedColouredKg,
        skipped: stop.status == 'Skipped',
        pending: stop.status == 'Pending' || stop.status == 'Next',
        skipReason: stop.skipReason,
        photoPath: collection?.photoPath,
        signaturePath: collection?.signaturePath,
        signedBy: collection?.signerName,
      );
    }).toList();

    if (!mounted) return;
    final tripProvider = context.read<TripProvider>();
    setState(() {
      _applyData(
        TripReportData(
          tripDate: tripProvider.trip?.tripDate,
          distanceKm: tripProvider.trip?.totalDistanceKm ?? 0,
          duration: (earliest != null && latest != null)
              ? latest!.difference(earliest!)
              : null,
          stops: reports,
        ),
      );
    });
  }

  void _applyData(TripReportData data) {
    _stopReports = data.stops;
    _totalClearKg = data.totalClearKg;
    _totalColouredKg = data.totalColouredKg;
    _tripDuration = data.duration;
    _distanceKm = data.distanceKm;
    _tripDate = data.tripDate;
    _isLoading = false;
  }

  Future<void> _sharePdf() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sharing = true);
    try {
      final data = TripReportData(
        tripDate: _tripDate,
        distanceKm: _distanceKm,
        duration: _tripDuration,
        stops: _stopReports,
      );
      final file = await ReportPdfService().save(data);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          subject: 'Glassline trip report',
          text:
              'Glassline trip report'
              '${_tripDate == null ? '' : ' - ${formatTripDate(_tripDate!)}'}',
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not create the PDF report.')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  String get _stopsSummary {
    final parts = ['${_stopReports.length} stops'];
    if (_skippedCount > 0) parts.add('$_skippedCount skipped');
    final pending = _stopReports.where((r) => r.pending).length;
    if (pending > 0) parts.add('$pending pending');
    return parts.join(' · ');
  }

  int get _skippedCount => _stopReports.where((r) => r.skipped).length;

  int get _shortfalls => _stopReports.where((r) => r.belowExpected).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stopReports.isEmpty
          ? const EmptyState(
              title: 'No report yet',
              message: 'Complete your stops to see the trip report.',
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHero(context),
                  Padding(
                    padding: const EdgeInsets.all(Gap.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBreakdownChart(context),
                        if (_shortfalls > 0) ...[
                          const SizedBox(height: Gap.lg),
                          _ShortfallSummary(count: _shortfalls),
                        ],
                        const SizedBox(height: Gap.xl),
                        SectionHeader(
                          'Stop breakdown',
                          trailing: Text(
                            _stopsSummary,
                            style: context.text.bodySmall?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: Gap.md),
                        for (var i = 0; i < _stopReports.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Gap.md),
                            child: _StopReportCard(report: _stopReports[i])
                                .animate()
                                .fadeIn(delay: (70 * i).ms)
                                .slideY(
                                  begin: 0.08,
                                  end: 0,
                                  delay: (70 * i).ms,
                                ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar:
          widget.data != null || _isLoading || _stopReports.isEmpty
          ? null
          : _buildSyncBar(context),
    );
  }

  Widget _buildHero(BuildContext context) {
    final total = _totalClearKg + _totalColouredKg;

    return HeroHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Text(
                  _tripDate == null
                      ? 'TRIP REPORT'
                      : 'TRIP REPORT · ${formatTripDate(_tripDate!).toUpperCase()}',
                  style: context.text.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  foregroundColor: Colors.white,
                ),
                tooltip: 'Share report as PDF',
                onPressed: _sharing ? null : _sharePdf,
                icon: _sharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.ios_share_rounded),
              ),
            ],
          ),
          const SizedBox(height: Gap.xl),
          Text(
            'Total collected',
            style: context.text.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(end: total),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Text(
                  v.toStringAsFixed(1),
                  style: context.text.displayMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Text(
                'kg',
                style: context.text.titleLarge?.copyWith(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: Gap.xl),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  onHero: true,
                  icon: Icons.route_rounded,
                  value: '${_distanceKm.toStringAsFixed(1)} km',
                  label: 'Distance',
                ),
              ),
              Expanded(
                child: StatTile(
                  onHero: true,
                  icon: Icons.timer_outlined,
                  value: formatDuration(_tripDuration),
                  label: 'Duration',
                ),
              ),
              Expanded(
                child: StatTile(
                  onHero: true,
                  icon: Icons.pin_drop_outlined,
                  value: '${_stopReports.length}',
                  label: 'Stops',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownChart(BuildContext context) {
    final total = _totalClearKg + _totalColouredKg;
    final clearColor = context.colors.primary;
    const colouredColor = Brand.violet;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Row(
          children: [
            SizedBox(
              width: 132,
              height: 132,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 42,
                      startDegreeOffset: -90,
                      sections: total == 0
                          ? [
                              PieChartSectionData(
                                value: 1,
                                color: context.colors.surfaceContainerHighest,
                                radius: 16,
                                showTitle: false,
                              ),
                            ]
                          : [
                              PieChartSectionData(
                                value: _totalClearKg,
                                color: clearColor,
                                radius: 16,
                                showTitle: false,
                              ),
                              PieChartSectionData(
                                value: _totalColouredKg,
                                color: colouredColor,
                                radius: 16,
                                showTitle: false,
                              ),
                            ],
                    ),
                    duration: const Duration(milliseconds: 800),
                  ),
                  Icon(
                    Icons.recycling_rounded,
                    color: context.colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Gap.xl),
            Expanded(
              child: Column(
                children: [
                  _LegendRow(
                    color: clearColor,
                    label: 'Clear glass',
                    kg: _totalClearKg,
                    share: total == 0 ? 0 : _totalClearKg / total,
                  ),
                  const SizedBox(height: Gap.lg),
                  _LegendRow(
                    color: colouredColor,
                    label: 'Coloured glass',
                    kg: _totalColouredKg,
                    share: total == 0 ? 0 : _totalColouredKg / total,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: context.colors.outlineVariant)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Consumer<SyncProvider>(
            builder: (context, sync, _) {
              final s = context.status;

              if (sync.syncComplete) {
                return Row(
                  children: [
                    Icon(Icons.cloud_done_rounded, color: s.success, size: 32)
                        .animate()
                        .scale(duration: 500.ms, curve: Curves.elasticOut),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Synced to server',
                            style: context.text.titleMedium?.copyWith(
                              color: s.success,
                            ),
                          ),
                          Text(
                            'All collection records are saved.',
                            style: context.text.bodySmall?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (sync.error != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: Gap.md),
                      padding: const EdgeInsets.all(Gap.md),
                      decoration: BoxDecoration(
                        color: context.colors.errorContainer,
                        borderRadius: Corners.mdAll,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: context.colors.error,
                            size: 20,
                          ),
                          const SizedBox(width: Gap.md),
                          Expanded(
                            child: Text(
                              '${sync.error!} Your data is safe on this device.',
                              style: context.text.bodySmall?.copyWith(
                                color: context.colors.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn().shakeX(hz: 4, amount: 4),
                  PrimaryButton(
                    label: sync.error != null ? 'Retry sync' : 'Sync to server',
                    icon: sync.error != null
                        ? Icons.refresh_rounded
                        : Icons.cloud_upload_rounded,
                    loading: sync.isSyncing,
                    onPressed: () =>
                        sync.sync(context.read<TripProvider>().trip!.tripId),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.kg,
    required this.share,
  });

  final Color color;
  final String label;
  final double kg;
  final double share;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: Gap.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: context.text.bodySmall),
              Text('${formatKg(kg)} kg', style: context.text.titleMedium),
            ],
          ),
        ),
        Text(
          '${(share * 100).round()}%',
          style: context.text.labelLarge?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ShortfallSummary extends StatelessWidget {
  const _ShortfallSummary({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final s = context.status;
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: s.warningContainer,
        borderRadius: Corners.lgAll,
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: s.warning, size: 28),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              count == 1
                  ? '1 supplier delivered less than expected.'
                  : '$count suppliers delivered less than expected.',
              style: context.text.titleSmall?.copyWith(color: s.warning),
            ),
          ),
        ],
      ),
    );
  }
}

class _StopReportCard extends StatelessWidget {
  const _StopReportCard({required this.report});

  final StopReport report;

  @override
  Widget build(BuildContext context) {
    if (report.skipped || report.pending) {
      return _UnvisitedStopCard(report: report);
    }

    final s = context.status;
    final short = report.belowExpected;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: Corners.lgAll,
        side: BorderSide(
          color: short
              ? s.warning.withValues(alpha: 0.6)
              : context.colors.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    report.supplierName,
                    style: context.text.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.md,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: short ? s.warningContainer : s.successContainer,
                    borderRadius: BorderRadius.circular(Corners.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        short
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_rounded,
                        size: 14,
                        color: short ? s.warning : s.success,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        short ? 'Shortfall' : 'On target',
                        style: context.text.labelMedium?.copyWith(
                          color: short ? s.warning : s.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (report.condition != null) ...[
              const SizedBox(height: 2),
              Text(
                'Condition: ${report.condition}',
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: Gap.lg),
            _QuantityBar(
              label: 'Clear',
              color: context.colors.primary,
              collected: report.collectedClearKg,
              expected: report.expectedClearKg,
            ),
            const SizedBox(height: Gap.md),
            _QuantityBar(
              label: 'Coloured',
              color: Brand.violet,
              collected: report.collectedColouredKg,
              expected: report.expectedColouredKg,
            ),
            if (report.photoPath != null || report.photoUrl != null) ...[
              const SizedBox(height: Gap.lg),
              ProofPhoto(
                localPath: report.photoPath,
                url: report.photoUrl,
                height: 110,
              ),
            ],
            if (report.signaturePath != null ||
                report.signatureUrl != null) ...[
              const SizedBox(height: Gap.lg),
              Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: ProofPhoto(
                      localPath: report.signaturePath,
                      url: report.signatureUrl,
                      height: 56,
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.verified_outlined,
                          size: 18,
                          color: context.status.success,
                        ),
                        const SizedBox(width: Gap.sm),
                        Expanded(
                          child: Text(
                            report.signedBy == null
                                ? 'Signed by supplier'
                                : 'Signed by ${report.signedBy}',
                            style: context.text.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuantityBar extends StatelessWidget {
  const _QuantityBar({
    required this.label,
    required this.color,
    required this.collected,
    required this.expected,
  });

  final String label;
  final Color color;
  final double collected;
  final double expected;

  @override
  Widget build(BuildContext context) {
    final short = collected < expected;
    final progress = expected == 0
        ? 1.0
        : (collected / expected).clamp(0.0, 1.0);
    final barColor = short ? context.status.warning : color;

    return Column(
      children: [
        Row(
          children: [
            Text(label, style: context.text.bodySmall),
            const Spacer(),
            Text(
              '${formatKg(collected)} / ${formatKg(expected)} kg',
              style: context.text.labelLarge?.copyWith(
                color: short ? context.status.warning : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween: Tween(end: progress),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => ClipRRect(
            borderRadius: BorderRadius.circular(Corners.pill),
            child: LinearProgressIndicator(
              value: v,
              minHeight: 8,
              color: barColor,
              backgroundColor: barColor.withValues(alpha: 0.15),
            ),
          ),
        ),
      ],
    );
  }
}

/// A stop with nothing to compare: skipped, or not visited yet.
class _UnvisitedStopCard extends StatelessWidget {
  const _UnvisitedStopCard({required this.report});

  final StopReport report;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    report.supplierName,
                    style: context.text.titleMedium,
                  ),
                ),
                StatusChip(report.skipped ? 'Skipped' : 'Pending'),
              ],
            ),
            if (report.skipReason != null) ...[
              const SizedBox(height: 2),
              Text(
                'Reason: ${report.skipReason}',
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: Gap.sm),
            Text(
              report.skipped
                  ? 'Not collected · ${formatKg(report.expectedClearKg + report.expectedColouredKg)} kg was expected'
                  : 'Not visited yet · ${formatKg(report.expectedClearKg + report.expectedColouredKg)} kg expected',
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
