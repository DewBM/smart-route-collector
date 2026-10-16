import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_tokens.dart';
import '../utils/format.dart';

/// Weight input with -/+ steppers, an "expected" reference and a
/// "use expected" shortcut.
class KgField extends StatelessWidget {
  const KgField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.expectedKg,
    required this.accent,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final double expectedKg;
  final Color accent;
  final bool enabled;
  final VoidCallback? onChanged;

  void _step(double delta) {
    final current = double.tryParse(controller.text) ?? 0;
    final next = (current + delta).clamp(0, 99999).toDouble();
    controller.text = formatKg(next);
    onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Gap.sm,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: accent),
                const SizedBox(width: Gap.sm),
                Text(label, style: context.text.labelLarge),
              ],
            ),
            Text(
              'Expected ${formatKg(expectedKg)} kg',
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.sm),
        TextFormField(
          controller: controller,
          enabled: enabled,
          textAlign: TextAlign.center,
          style: context.text.titleLarge,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d{0,5}\.?\d{0,2}')),
          ],
          onChanged: (_) => onChanged?.call(),
          decoration: InputDecoration(
            hintText: '0',
            suffixText: 'kg',
            prefixIcon: IconButton(
              onPressed: enabled ? () => _step(-1) : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            suffixIcon: IconButton(
              onPressed: enabled ? () => _step(1) : null,
              icon: const Icon(Icons.add_rounded),
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Enter a weight (0 if none)';
            if (double.tryParse(v) == null) return 'Enter a valid number';
            return null;
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: enabled
                ? () {
                    controller.text = formatKg(expectedKg);
                    onChanged?.call();
                  }
                : null,
            child: const Text('Use expected'),
          ),
        ),
      ],
    );
  }
}
