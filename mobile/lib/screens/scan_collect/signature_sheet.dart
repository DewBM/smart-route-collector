import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/signature_pad.dart';

class SignatureResult {
  final Uint8List png;
  final String? signerName;
  const SignatureResult(this.png, this.signerName);
}

/// Full-height sheet for the supplier to sign. Resolves to null if dismissed.
Future<SignatureResult?> showSignatureSheet(
  BuildContext context,
  String supplierName,
) {
  return showModalBottomSheet<SignatureResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    // Dragging the sheet would fight with drawing.
    enableDrag: false,
    useSafeArea: true,
    builder: (_) => _SignatureSheet(supplierName: supplierName),
  );
}

class _SignatureSheet extends StatefulWidget {
  const _SignatureSheet({required this.supplierName});

  final String supplierName;

  @override
  State<_SignatureSheet> createState() => _SignatureSheetState();
}

class _SignatureSheetState extends State<_SignatureSheet> {
  final _controller = SignatureController();
  final _name = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final png = await _controller.toPng();
    final name = _name.text.trim();
    if (mounted) {
      Navigator.pop(context, SignatureResult(png, name.isEmpty ? null : name));
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Text('Supplier signature', style: context.text.titleLarge),
            const SizedBox(height: Gap.xs),
            Text(
              'Ask the person at ${widget.supplierName} to sign to confirm the handover.',
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Gap.lg),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: 'Name of signer (optional)',
                counterText: '',
              ),
            ),
            const SizedBox(height: Gap.md),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: Corners.mdAll,
                border: Border.all(color: context.colors.outlineVariant),
              ),
              child: SignaturePad(controller: _controller, height: 220),
            ),
            const SizedBox(height: Gap.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _controller.isEmpty
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            _controller.clear();
                          },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _controller.isEmpty || _saving ? null : _save,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
