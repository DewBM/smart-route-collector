import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/supplier_detail.dart';
import '../../models/trip_stop.dart';
import '../../services/api_service.dart';
import '../../theme/app_tokens.dart';
import '../../utils/format.dart';
import '../../utils/navigation.dart';
import '../../widgets/section_header.dart';
import '../../widgets/state_views.dart';
import '../../widgets/status_chip.dart';

/// Bottom sheet with everything a collector needs to know about a supplier:
/// contact details (available offline), site notes, and recent collections
/// (loaded from the server when online).
Future<void> showSupplierSheet(BuildContext context, TripStop stop) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) =>
          _SupplierSheet(stop: stop, scrollController: controller),
    ),
  );
}

class _SupplierSheet extends StatefulWidget {
  const _SupplierSheet({required this.stop, required this.scrollController});

  final TripStop stop;
  final ScrollController scrollController;

  @override
  State<_SupplierSheet> createState() => _SupplierSheetState();
}

class _SupplierSheetState extends State<_SupplierSheet> {
  late Future<SupplierHistory> _history;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() =>
      _history = ApiService().fetchSupplierHistory(widget.stop.supplierId);

  Future<void> _call(BuildContext context, String phone) async {
    final messenger = ScaffoldMessenger.of(context);
    var ok = false;
    try {
      ok = await launchUrl(
        Uri(scheme: 'tel', path: phone.replaceAll(' ', '')),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the phone app.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final stop = widget.stop;
    final hasContact = stop.phone != null || stop.address != null;

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.xxl),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(stop.supplierName, style: context.text.titleLarge),
            ),
            const SizedBox(width: Gap.sm),
            StatusChip(stop.status),
          ],
        ),
        const SizedBox(height: Gap.xs),
        Text(
          'Stop ${stop.stopOrder} · ${formatKg(stop.expectedClearKg + stop.expectedColouredKg)} kg expected',
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Gap.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => navigateToStop(context, stop),
                icon: const Icon(Icons.navigation_rounded),
                label: const Text('Navigate'),
              ),
            ),
            if (stop.phone != null) ...[
              const SizedBox(width: Gap.sm),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () => _call(context, stop.phone!),
                  icon: const Icon(Icons.call_rounded),
                  label: const Text('Call'),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: Gap.xl),
        const SectionHeader('Contact'),
        const SizedBox(height: Gap.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: hasContact
                ? Column(
                    children: [
                      if (stop.contactName != null)
                        _InfoRow(
                          Icons.person_outline_rounded,
                          'Contact',
                          stop.contactName!,
                        ),
                      if (stop.phone != null)
                        _InfoRow(Icons.call_outlined, 'Phone', stop.phone!),
                      if (stop.address != null)
                        _InfoRow(
                          Icons.place_outlined,
                          'Address',
                          stop.address!,
                        ),
                    ],
                  )
                : Text(
                    'No contact details on file.',
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
          ),
        ),
        if (stop.notes != null) ...[
          const SizedBox(height: Gap.lg),
          const SectionHeader('Site notes'),
          const SizedBox(height: Gap.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Gap.lg),
            decoration: BoxDecoration(
              color: context.status.warningContainer,
              borderRadius: Corners.lgAll,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.sticky_note_2_outlined,
                  color: context.status.warning,
                  size: 20,
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Text(
                    stop.notes!,
                    style: context.text.bodyMedium?.copyWith(
                      color: context.status.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: Gap.xl),
        const SectionHeader('Recent collections'),
        const SizedBox(height: Gap.md),
        FutureBuilder<SupplierHistory>(
          future: _history,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Column(
                children: [
                  SkeletonBox(height: 64, radius: Corners.md),
                  SizedBox(height: Gap.sm),
                  SkeletonBox(height: 64, radius: Corners.md),
                ],
              );
            }
            if (snap.hasError) {
              return _Note(
                icon: Icons.cloud_off_rounded,
                text: 'History is unavailable offline.',
                action: TextButton(
                  onPressed: () => setState(_load),
                  child: const Text('Retry'),
                ),
              );
            }
            final h = snap.data!;
            if (h.recent.isEmpty) {
              return const _Note(
                icon: Icons.history_rounded,
                text: 'No previous collections yet.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${h.totalCollections} collections · '
                  '${formatKg(double.parse(h.averageKg.toStringAsFixed(1)))} kg average',
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Gap.md),
                for (final c in h.recent) _CollectionTile(c),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: context.colors.primary),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                Text(value, style: context.text.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile(this.c);

  final SupplierCollection c;

  @override
  Widget build(BuildContext context) {
    final s = context.status;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.belowExpected
                      ? s.warningContainer
                      : s.successContainer,
                  borderRadius: Corners.smAll,
                ),
                child: Icon(
                  c.belowExpected
                      ? Icons.warning_amber_rounded
                      : Icons.check_rounded,
                  size: 20,
                  color: c.belowExpected ? s.warning : s.success,
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatTripDate(c.date.toIso8601String()),
                      style: context.text.titleSmall,
                    ),
                    Text(
                      '${formatKg(c.clearKg)} kg clear · ${formatKg(c.colouredKg)} kg coloured · ${c.condition}',
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: context.colors.onSurfaceVariant),
        const SizedBox(width: Gap.md),
        Expanded(
          child: Text(
            text,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
        ?action,
      ],
    );
  }
}
