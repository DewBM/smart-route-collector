import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Pill showing a stop status: Pending, Next or Collected.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final s = context.status;
    final (bg, fg, icon) = switch (status) {
      'Collected' => (
        s.successContainer,
        s.success,
        Icons.check_circle_rounded,
      ),
      'Skipped' => (s.warningContainer, s.warning, Icons.skip_next_rounded),
      'Next' => (s.nextContainer, s.next, Icons.navigation_rounded),
      _ => (s.pendingContainer, s.pending, Icons.schedule_rounded),
    };

    return Semantics(
      label: 'Status: $status',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Corners.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
            Text(
              status,
              style: context.text.labelMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
