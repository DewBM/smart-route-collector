import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../models/trip_stop.dart';
import '../../providers/trip_provider.dart';
import '../../theme/app_tokens.dart';
import '../../utils/format.dart';
import '../../utils/navigation.dart';
import '../../widgets/status_chip.dart';
import 'route_map.dart';
import 'supplier_sheet.dart';

/// Full-screen overview of the whole route. Tap a pin to see the stop and
/// start navigation to it.
class RouteMapScreen extends StatefulWidget {
  const RouteMapScreen({super.key});

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  int? _selectedId;

  @override
  Widget build(BuildContext context) {
    final stops = context.watch<TripProvider>().stops;
    final selected =
        stops.where((s) => s.supplierId == _selectedId).firstOrNull ??
        stops.where((s) => s.status == 'Next').firstOrNull ??
        stops.firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Route overview')),
      body: stops.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RouteMap(
                      stops: stops,
                      onStopTap: (s) =>
                          setState(() => _selectedId = s.supplierId),
                    ),
                  ),
                  if (selected != null)
                    Positioned(
                      left: Gap.md,
                      right: Gap.md,
                      bottom: Gap.md,
                      child: _StopSheet(
                        key: ValueKey(selected.supplierId),
                        stop: selected,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _StopSheet extends StatelessWidget {
  const _StopSheet({super.key, required this.stop});

  final TripStop stop;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${stop.stopOrder}. ${stop.supplierName}',
                    style: context.text.titleMedium,
                  ),
                ),
                StatusChip(stop.status),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${stop.distanceFromPrevKm.toStringAsFixed(1)} km from previous · '
              '${formatKg(stop.expectedClearKg + stop.expectedColouredKg)} kg expected',
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Gap.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => showSupplierSheet(context, stop),
                    icon: const Icon(Icons.info_outline_rounded),
                    label: const Text('Details'),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => navigateToStop(context, stop),
                    icon: const Icon(Icons.navigation_rounded),
                    label: const Text('Navigate'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.1, end: 0);
  }
}
