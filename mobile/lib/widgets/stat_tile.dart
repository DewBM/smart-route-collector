import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Icon + big value + label. `onHero` renders for use over the brand gradient.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.onHero = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final bool onHero;

  @override
  Widget build(BuildContext context) {
    final fg = onHero ? Colors.white : context.colors.onSurface;
    final muted = onHero
        ? Colors.white.withValues(alpha: 0.75)
        : context.colors.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: muted),
        const SizedBox(height: Gap.sm),
        Text(
          value,
          style: context.text.titleLarge?.copyWith(
            color: fg,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(label, style: context.text.bodySmall?.copyWith(color: muted)),
      ],
    );
  }
}
