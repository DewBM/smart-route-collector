import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/trip_stop.dart';
import '../../theme/app_tokens.dart';
import '../../utils/format.dart';
import '../../widgets/status_chip.dart';

/// One stop in the route timeline: a rail with a numbered node on the left,
/// and a card on the right. The "Next" stop is emphasised with a Scan CTA.
class StopTimelineTile extends StatelessWidget {
  const StopTimelineTile({
    super.key,
    required this.stop,
    required this.isFirst,
    required this.isLast,
    this.onScan,
    this.onNavigate,
    this.onTap,
  });

  final TripStop stop;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onScan;
  final VoidCallback? onNavigate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.status;
    final isNext = stop.status == 'Next';
    final isDone = stop.status == 'Collected';
    final isSkipped = stop.status == 'Skipped';
    final railColor = isDone ? s.success : context.colors.outlineVariant;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: SizedBox(
              width: 44,
              child: Column(
                children: [
                  Expanded(
                    flex: 0,
                    child: Container(
                      width: 2,
                      height: 12,
                      color: isFirst ? Colors.transparent : railColor,
                    ),
                  ),
                  _Node(stop: stop),
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isLast ? Colors.transparent : railColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: Gap.md),
              child: Card(
                clipBehavior: Clip.antiAlias,
                color: isNext ? s.nextContainer.withValues(alpha: 0.5) : null,
                shape: RoundedRectangleBorder(
                  borderRadius: Corners.lgAll,
                  side: BorderSide(
                    color: isNext
                        ? s.next
                        : context.colors.outlineVariant.withValues(alpha: 0.5),
                    width: isNext ? 1.5 : 1,
                  ),
                ),
                child: InkWell(
                  onTap: onTap,
                  child: Opacity(
                    opacity: (isDone || isSkipped) ? 0.72 : 1,
                    child: Padding(
                      padding: const EdgeInsets.all(Gap.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Semantics(
                                  label:
                                      'Stop ${stop.stopOrder}, ${stop.supplierName}',
                                  excludeSemantics: true,
                                  child: Text(
                                    stop.supplierName,
                                    style: context.text.titleMedium,
                                  ),
                                ),
                              ),
                              const SizedBox(width: Gap.sm),
                              StatusChip(stop.status),
                            ],
                          ),
                          const SizedBox(height: Gap.sm),
                          Wrap(
                            spacing: Gap.lg,
                            runSpacing: Gap.xs,
                            children: [
                              _Meta(
                                Icons.alt_route_rounded,
                                '${stop.distanceFromPrevKm.toStringAsFixed(1)} km',
                              ),
                              _Meta(
                                Icons.scale_rounded,
                                '${formatKg(stop.expectedClearKg + stop.expectedColouredKg)} kg expected',
                              ),
                            ],
                          ),
                          if (isSkipped && stop.skipReason != null) ...[
                            const SizedBox(height: Gap.sm),
                            Text(
                              'Skipped: ${stop.skipReason}',
                              style: context.text.bodySmall?.copyWith(
                                color: context.status.warning,
                              ),
                            ),
                          ],
                          if (isNext && onScan != null) ...[
                            const SizedBox(height: Gap.lg),
                            Row(
                              children: [
                                if (onNavigate != null)
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(48),
                                      ),
                                      onPressed: onNavigate,
                                      icon: const Icon(
                                        Icons.navigation_rounded,
                                      ),
                                      label: const Text('Navigate'),
                                    ),
                                  ),
                                const SizedBox(width: Gap.sm),
                                Expanded(
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(48),
                                    ),
                                    onPressed: onScan,
                                    icon: const Icon(
                                      Icons.qr_code_scanner_rounded,
                                    ),
                                    label: const Text('Scan'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.stop});

  final TripStop stop;

  @override
  Widget build(BuildContext context) {
    final s = context.status;
    final isNext = stop.status == 'Next';
    final isDone = stop.status == 'Collected';
    final isSkipped = stop.status == 'Skipped';

    final node = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDone
            ? s.success
            : isSkipped
            ? s.warning
            : isNext
            ? s.next
            : context.colors.surfaceContainerHighest,
      ),
      alignment: Alignment.center,
      child: isSkipped
          ? const Icon(Icons.skip_next_rounded, size: 18, color: Colors.white)
          : isDone
          ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
          : Text(
              '${stop.stopOrder}',
              style: context.text.labelLarge?.copyWith(
                color: isNext
                    ? context.colors.surface
                    : context.colors.onSurfaceVariant,
              ),
            ),
    );

    if (!isNext) return node;

    // Pulsing halo for the active stop.
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(shape: BoxShape.circle, color: s.next),
            )
            .animate(onPlay: (c) => c.repeat())
            .scale(
              begin: const Offset(1, 1),
              end: const Offset(1.7, 1.7),
              duration: 1400.ms,
              curve: Curves.easeOut,
            )
            .fadeOut(duration: 1400.ms),
        node,
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors.onSurfaceVariant;
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
