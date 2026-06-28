import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/trip_stop.dart';
import '../../models/collection_record.dart';
import '../../providers/trip_provider.dart';
import '../../providers/sync_provider.dart';
import '../../db/database_helper.dart';

class TripReportScreen extends StatefulWidget {
  const TripReportScreen({super.key});

  @override
  State<TripReportScreen> createState() => _TripReportScreenState();
}

class _TripReportScreenState extends State<TripReportScreen> {
  List<_StopReport> _stopReports = [];
  double _totalClearKg = 0;
  double _totalColouredKg = 0;
  String _tripDuration = '--';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFromLocal();
    });
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

      return _StopReport(
        supplierName: stop.supplierName,
        collectedClearKg: clearKg,
        collectedColouredKg: colouredKg,
        expectedClearKg: stop.expectedClearKg,
        expectedColouredKg: stop.expectedColouredKg,
        belowExpected:
            clearKg < stop.expectedClearKg ||
            colouredKg < stop.expectedColouredKg,
      );
    }).toList();

    String duration = '--';
    if (earliest != null && latest != null) {
      final diff = latest!.difference(earliest!);
      final hours = diff.inHours.toString().padLeft(2, '0');
      final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
      duration = '$hours:$minutes';
    }

    setState(() {
      _stopReports = reports;
      _totalClearKg = reports.fold(0, (sum, r) => sum + r.collectedClearKg);
      _totalColouredKg = reports.fold(
        0,
        (sum, r) => sum + r.collectedColouredKg,
      );
      _tripDuration = duration;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Trip Report')),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTripStatsRow(theme),
          const SizedBox(height: 24),
          Text(
            'Stop Breakdown',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ..._stopReports.map((r) => _buildStopCard(r, theme)),
          const SizedBox(height: 24),
          _buildSyncButton(theme),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTripStatsRow(ThemeData theme) {
    final tripProvider = context.read<TripProvider>();

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Distance',
            '${tripProvider.trip?.totalDistanceKm.toStringAsFixed(1) ?? '--'} km',
            Icons.route,
            theme,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard('Duration', _tripDuration, Icons.timer, theme),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Total Glass',
            '${(_totalClearKg + _totalColouredKg).toStringAsFixed(1)} kg',
            Icons.recycling,
            theme,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    ThemeData theme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 24),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStopCard(_StopReport stop, ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: stop.belowExpected
            ? BorderSide(color: theme.colorScheme.error, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  stop.supplierName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (stop.belowExpected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Below Expected',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _buildKgRow(
              'Clear Glass',
              stop.collectedClearKg,
              stop.expectedClearKg,
              theme,
            ),
            const SizedBox(height: 6),
            _buildKgRow(
              'Coloured Glass',
              stop.collectedColouredKg,
              stop.expectedColouredKg,
              theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKgRow(
    String label,
    double collected,
    double expected,
    ThemeData theme,
  ) {
    final isBelow = collected < expected;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '${collected.toStringAsFixed(1)} kg',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isBelow
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurface,
                ),
              ),
              TextSpan(
                text: ' / ${expected.toStringAsFixed(1)} kg expected',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSyncButton(ThemeData theme) {
    final tripProvider = context.read<TripProvider>();

    return Consumer<SyncProvider>(
      builder: (context, syncProvider, _) {
        if (syncProvider.syncComplete) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_done, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Synced successfully',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            if (syncProvider.error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        syncProvider.error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: syncProvider.isSyncing
                    ? null
                    : () => syncProvider.sync(tripProvider.trip!.tripId),
                icon: syncProvider.isSyncing
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(
                  syncProvider.isSyncing
                      ? 'Syncing...'
                      : syncProvider.error != null
                      ? 'Retry Sync'
                      : 'Sync to Server',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StopReport {
  final String supplierName;
  final double collectedClearKg;
  final double collectedColouredKg;
  final double expectedClearKg;
  final double expectedColouredKg;
  final bool belowExpected;

  _StopReport({
    required this.supplierName,
    required this.collectedClearKg,
    required this.collectedColouredKg,
    required this.expectedClearKg,
    required this.expectedColouredKg,
    required this.belowExpected,
  });
}
