import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_tokens.dart';

const skipReasons = [
  ('Supplier closed', Icons.storefront_outlined),
  ('No access to location', Icons.block_rounded),
  ('Nothing to collect', Icons.inventory_2_outlined),
  ('Other', Icons.more_horiz_rounded),
];

class SkipResult {
  final String reason;
  final String? note;
  const SkipResult(this.reason, this.note);
}

/// Bottom sheet asking why a stop can't be collected. Resolves to null if the
/// collector dismisses it.
Future<SkipResult?> showSkipStopSheet(BuildContext context, String stopName) {
  return showModalBottomSheet<SkipResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SkipStopSheet(stopName: stopName),
  );
}

class _SkipStopSheet extends StatefulWidget {
  const _SkipStopSheet({required this.stopName});

  final String stopName;

  @override
  State<_SkipStopSheet> createState() => _SkipStopSheetState();
}

class _SkipStopSheetState extends State<_SkipStopSheet> {
  String? _reason;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.status;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Gap.xl,
        0,
        Gap.xl,
        Gap.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Skip this stop?', style: context.text.titleLarge),
            const SizedBox(height: Gap.xs),
            Text(
              '${widget.stopName} will be marked as skipped and the remaining '
              'route re-optimised from here.',
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Gap.lg),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: [
                for (final (label, icon) in skipReasons)
                  ChoiceChip(
                    avatar: Icon(icon, size: 18),
                    label: Text(label),
                    selected: _reason == label,
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _reason = label);
                    },
                  ),
              ],
            ),
            const SizedBox(height: Gap.lg),
            TextField(
              controller: _note,
              maxLength: 300,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: _reason == 'Other'
                    ? 'Note (required)'
                    : 'Note (optional)',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Gap.md),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: s.warning,
                foregroundColor: Colors.white,
                disabledBackgroundColor: s.warning.withValues(alpha: 0.3),
              ),
              onPressed: _canConfirm
                  ? () => Navigator.pop(
                      context,
                      SkipResult(
                        _reason!,
                        _note.text.trim().isEmpty ? null : _note.text.trim(),
                      ),
                    )
                  : null,
              icon: const Icon(Icons.skip_next_rounded),
              label: const Text('Skip stop'),
            ),
            const SizedBox(height: Gap.sm),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  bool get _canConfirm =>
      _reason != null && (_reason != 'Other' || _note.text.trim().isNotEmpty);
}
