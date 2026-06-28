import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/trip_provider.dart';
import '../../models/trip_stop.dart';
import '../scan_collect/scan_collect_screen.dart';
import '../trip_report/trip_report_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final tripProvider = context.watch<TripProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today\'s Route'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<TripProvider>().loadTrip(),
          ),
        ],
      ),
      body: _buildBody(tripProvider, theme),
    );
  }

  Widget _buildBody(TripProvider tripProvider, ThemeData theme) {
    if (tripProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (tripProvider.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(
                tripProvider.error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.read<TripProvider>().loadTrip(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (tripProvider.stops.isEmpty) {
      return const Center(child: Text('No stops scheduled for today.'));
    }

    return Column(
      children: [
        _buildTripSummaryCard(tripProvider, theme),
        Expanded(
          child: ListView.builder(
            itemCount: tripProvider.stops.length,
            itemBuilder: (context, index) {
              final stop = tripProvider.stops[index];
              return _buildStopCard(stop, tripProvider, theme);
            },
          ),
        ),
        if (tripProvider.isTripComplete)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TripReportScreen(),
                  ),
                ),
                child: const Text('View Trip Report'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTripSummaryCard(TripProvider tripProvider, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Distance',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                  Text(
                    '${tripProvider.trip?.totalDistanceKm.toStringAsFixed(1)} km',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Remaining Stops',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                  Text(
                    '${tripProvider.remainingStops}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
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

  Widget _buildStopCard(TripStop stop, TripProvider tripProvider, ThemeData theme) {
    final isNext = stop.status == 'Next';
    final isCollected = stop.status == 'Collected';

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isNext
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isNext
            ? () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ScanCollectScreen(stop: stop),
                  ),
                );
                if (mounted) {
                  context.read<TripProvider>().loadTrip();
                }
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildStopNumber(stop, isNext, isCollected, theme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.supplierName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${stop.distanceFromPrevKm.toStringAsFixed(1)} km from previous',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(stop.status, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStopNumber(TripStop stop, bool isNext, bool isCollected, ThemeData theme) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCollected
            ? theme.colorScheme.primary
            : isNext
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceVariant,
      ),
      child: Center(
        child: isCollected
            ? Icon(Icons.check, color: theme.colorScheme.onPrimary, size: 20)
            : Text(
                '${stop.stopOrder}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isNext
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, ThemeData theme) {
    Color bgColor;
    Color textColor;

    switch (status) {
      case 'Next':
        bgColor = theme.colorScheme.primaryContainer;
        textColor = theme.colorScheme.onPrimaryContainer;
        break;
      case 'Collected':
        bgColor = theme.colorScheme.primary;
        textColor = theme.colorScheme.onPrimary;
        break;
      default:
        bgColor = theme.colorScheme.surfaceVariant;
        textColor = theme.colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: theme.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
