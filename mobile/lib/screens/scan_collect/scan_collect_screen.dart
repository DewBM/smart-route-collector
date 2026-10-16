import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../models/trip_stop.dart';
import '../../providers/collection_provider.dart';
import '../../providers/trip_provider.dart';
import '../../theme/app_tokens.dart';
import '../../utils/format.dart';
import '../../widgets/kg_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_header.dart';
import '../../services/photo_service.dart';
import '../../widgets/proof_photo.dart';
import 'scanner_panel.dart';
import 'signature_sheet.dart';
import 'skip_stop_sheet.dart';

const _conditions = ['Clean', 'Contaminated', 'Broken'];

class ScanCollectScreen extends StatefulWidget {
  final TripStop stop;

  const ScanCollectScreen({super.key, required this.stop});

  @override
  State<ScanCollectScreen> createState() => _ScanCollectScreenState();
}

class _ScanCollectScreenState extends State<ScanCollectScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final _formKey = GlobalKey<FormState>();
  final _clearKgController = TextEditingController();
  final _colouredKgController = TextEditingController();

  final _photos = PhotoService();
  String? _photoPath;
  bool _capturing = false;
  String? _signaturePath;
  String? _signerName;
  String? _condition;
  bool _conditionMissing = false;
  bool _isVerified = false;
  bool _skipping = false;
  String? _scanError;
  int _errorCount = 0;
  String? _lastWrong;
  DateTime _lastWrongAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    _scannerController.dispose();
    _clearKgController.dispose();
    _colouredKgController.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_isVerified) return;

    final scannedValue = capture.barcodes.firstOrNull?.rawValue;
    if (scannedValue == null) return;

    if (scannedValue == widget.stop.barcodeRef) {
      HapticFeedback.mediumImpact();
      _scannerController.stop();
      setState(() {
        _isVerified = true;
        _scanError = null;
      });
      return;
    }

    // The camera reports the same frame many times a second; only react to a
    // repeated wrong code every couple of seconds.
    final now = DateTime.now();
    if (scannedValue == _lastWrong &&
        now.difference(_lastWrongAt) < const Duration(seconds: 2)) {
      return;
    }
    _lastWrong = scannedValue;
    _lastWrongAt = now;

    HapticFeedback.heavyImpact();
    setState(() {
      _errorCount++;
      _scanError =
          "That barcode belongs to a different supplier "
          "(scanned: $scannedValue). Head to ${widget.stop.supplierName}.";
    });
  }

  Future<void> _submitCollection() async {
    final formOk = _formKey.currentState!.validate();
    final conditionOk = _condition != null;
    setState(() => _conditionMissing = !conditionOk);
    if (!formOk || !conditionOk) return;

    final tripProvider = context.read<TripProvider>();
    final collectionProvider = context.read<CollectionProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final tripId = tripProvider.trip!.tripId;
    final supplierId = widget.stop.supplierId;

    await collectionProvider.submitCollection(
      tripId: tripId,
      supplierId: supplierId,
      clearKg: double.parse(_clearKgController.text),
      colouredKg: double.parse(_colouredKgController.text),
      condition: _condition!,
      photoPath: _photoPath,
      signaturePath: _signaturePath,
      signerName: _signerName,
    );

    await tripProvider.advanceStop(supplierId);

    HapticFeedback.mediumImpact();
    messenger.showSnackBar(
      SnackBar(content: Text('Collected from ${widget.stop.supplierName}')),
    );
    if (mounted) navigator.pop();
  }

  Future<void> _takePhoto() async {
    setState(() => _capturing = true);
    try {
      final path = await _photos.capture(
        tripId: context.read<TripProvider>().trip!.tripId,
        supplierId: widget.stop.supplierId,
      );
      if (path != null) {
        await _photos.delete(_photoPath); // replaced by the retake
        if (mounted) setState(() => _photoPath = path);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the camera.')),
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _getSignature() async {
    final result = await showSignatureSheet(context, widget.stop.supplierName);
    if (result == null || !mounted) return;

    final tripId = context.read<TripProvider>().trip!.tripId;
    final path = await _photos.saveSignature(
      result.png,
      tripId: tripId,
      supplierId: widget.stop.supplierId,
    );
    await _photos.delete(_signaturePath); // replaced by the new one
    if (mounted) {
      setState(() {
        _signaturePath = path;
        _signerName = result.signerName;
      });
    }
  }

  Future<void> _skipStop() async {
    final result = await showSkipStopSheet(context, widget.stop.supplierName);
    if (result == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _skipping = true);
    final confirmed = await context.read<TripProvider>().skipStop(
      supplierId: widget.stop.supplierId,
      reason: result.reason,
      note: result.note,
    );

    HapticFeedback.mediumImpact();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          confirmed
              ? 'Skipped ${widget.stop.supplierName}. Route updated.'
              : 'Skipped ${widget.stop.supplierName}. Will sync when you are online.',
        ),
      ),
    );
    navigator.pop();
  }

  double get _clearEntered => double.tryParse(_clearKgController.text) ?? 0;
  double get _colouredEntered =>
      double.tryParse(_colouredKgController.text) ?? 0;

  bool get _hasEntered =>
      _clearKgController.text.isNotEmpty ||
      _colouredKgController.text.isNotEmpty;

  double get _shortfallKg {
    final clear = (widget.stop.expectedClearKg - _clearEntered).clamp(0, 1e9);
    final coloured = (widget.stop.expectedColouredKg - _colouredEntered).clamp(
      0,
      1e9,
    );
    return (clear + coloured).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan & collect'),
        actions: [
          if (!_isVerified)
            TextButton.icon(
              onPressed: _skipping ? null : _skipStop,
              icon: const Icon(Icons.skip_next_rounded),
              label: const Text('Skip'),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
          children: [
            _StopCard(stop: widget.stop),
            const SizedBox(height: Gap.lg),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOutBack,
              child: _isVerified
                  ? _VerifiedBanner(
                      key: const ValueKey('ok'),
                      name: widget.stop.supplierName,
                    )
                  : Column(
                      key: const ValueKey('scan'),
                      children: [
                        SizedBox(
                          height: 300,
                          child: ScannerPanel(
                            controller: _scannerController,
                            onDetect: _onBarcodeDetected,
                            hasError: _scanError != null,
                          ),
                        ),
                        if (_scanError != null)
                          _ErrorBanner(message: _scanError!)
                              .animate(key: ValueKey(_errorCount))
                              .fadeIn(duration: 200.ms)
                              .shakeX(hz: 4, amount: 6),
                      ],
                    ),
            ),
            const SizedBox(height: Gap.xl),
            _buildForm(context),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final locked = !_isVerified;

    return Form(
      key: _formKey,
      child: Stack(
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: locked ? 0.45 : 1,
            child: IgnorePointer(
              ignoring: locked,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    'Collection details',
                    trailing: Icon(
                      locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                      size: 20,
                      color: locked
                          ? context.colors.onSurfaceVariant
                          : context.status.success,
                    ),
                  ),
                  const SizedBox(height: Gap.lg),
                  KgField(
                    controller: _clearKgController,
                    label: 'Clear glass',
                    icon: Icons.wine_bar_outlined,
                    accent: context.colors.primary,
                    expectedKg: widget.stop.expectedClearKg,
                    enabled: !locked,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: Gap.md),
                  KgField(
                    controller: _colouredKgController,
                    label: 'Coloured glass',
                    icon: Icons.palette_outlined,
                    accent: Brand.violet,
                    expectedKg: widget.stop.expectedColouredKg,
                    enabled: !locked,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: Gap.md),
                  Text('Condition', style: context.text.labelLarge),
                  const SizedBox(height: Gap.sm),
                  Wrap(
                    spacing: Gap.sm,
                    children: [
                      for (final c in _conditions)
                        ChoiceChip(
                          label: Text(c),
                          selected: _condition == c,
                          onSelected: (_) => setState(() {
                            HapticFeedback.selectionClick();
                            _condition = c;
                            _conditionMissing = false;
                          }),
                        ),
                    ],
                  ),
                  if (_conditionMissing)
                    Padding(
                      padding: const EdgeInsets.only(top: Gap.sm),
                      child: Text(
                        'Select the glass condition',
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: Gap.lg),
                  Row(
                    children: [
                      Text('Photo proof', style: context.text.labelLarge),
                      const SizedBox(width: Gap.sm),
                      Text(
                        'optional',
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.sm),
                  if (_photoPath == null)
                    OutlinedButton.icon(
                      onPressed: _capturing ? null : _takePhoto,
                      icon: _capturing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.photo_camera_outlined),
                      label: const Text('Take photo of the glass'),
                    )
                  else
                    Stack(
                      children: [
                        ProofPhoto(localPath: _photoPath, height: 160),
                        Positioned(
                          top: Gap.sm,
                          right: Gap.sm,
                          child: Row(
                            children: [
                              IconButton.filled(
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                ),
                                tooltip: 'Retake photo',
                                onPressed: _capturing ? null : _takePhoto,
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: Gap.xs),
                              IconButton.filled(
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                ),
                                tooltip: 'Remove photo',
                                onPressed: () async {
                                  await _photos.delete(_photoPath);
                                  if (mounted) {
                                    setState(() => _photoPath = null);
                                  }
                                },
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: Gap.lg),
                  Row(
                    children: [
                      Text(
                        'Supplier signature',
                        style: context.text.labelLarge,
                      ),
                      const SizedBox(width: Gap.sm),
                      Text(
                        'optional',
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.sm),
                  if (_signaturePath == null)
                    OutlinedButton.icon(
                      onPressed: _getSignature,
                      icon: const Icon(Icons.draw_outlined),
                      label: const Text('Get supplier signature'),
                    )
                  else
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(Gap.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ProofPhoto(localPath: _signaturePath, height: 90),
                            const SizedBox(height: Gap.sm),
                            Row(
                              children: [
                                Icon(
                                  Icons.verified_outlined,
                                  size: 18,
                                  color: context.status.success,
                                ),
                                const SizedBox(width: Gap.sm),
                                Expanded(
                                  child: Text(
                                    _signerName == null
                                        ? 'Signed'
                                        : 'Signed by $_signerName',
                                    style: context.text.bodySmall,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _getSignature,
                                  child: const Text('Redo'),
                                ),
                                IconButton(
                                  tooltip: 'Remove signature',
                                  onPressed: () async {
                                    await _photos.delete(_signaturePath);
                                    if (mounted) {
                                      setState(() {
                                        _signaturePath = null;
                                        _signerName = null;
                                      });
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_isVerified && _hasEntered && _shortfallKg > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: Gap.lg),
                      child: _ShortfallHint(kg: _shortfallKg),
                    ),
                  const SizedBox(height: Gap.xl),
                  Consumer<CollectionProvider>(
                    builder: (context, cp, _) => PrimaryButton(
                      label: 'Confirm collection',
                      icon: Icons.check_rounded,
                      loading: cp.isSubmitting,
                      onPressed: _isVerified ? _submitCollection : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (locked)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 80),
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.lg,
                    vertical: Gap.sm,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.inverseSurface,
                    borderRadius: BorderRadius.circular(Corners.pill),
                  ),
                  child: Text(
                    'Scan the barcode to unlock',
                    style: context.text.labelLarge?.copyWith(
                      color: context.colors.onInverseSurface,
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

class _StopCard extends StatelessWidget {
  const _StopCard({required this.stop});

  final TripStop stop;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: Brand.hero,
                borderRadius: Corners.mdAll,
              ),
              alignment: Alignment.center,
              child: Text(
                '${stop.stopOrder}',
                style: context.text.titleLarge?.copyWith(color: Colors.white),
              ),
            ),
            const SizedBox(width: Gap.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CURRENT STOP',
                    style: context.text.labelSmall?.copyWith(
                      color: context.status.next,
                    ),
                  ),
                  Text(stop.supplierName, style: context.text.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    '${formatKg(stop.expectedClearKg)} kg clear · '
                    '${formatKg(stop.expectedColouredKg)} kg coloured expected',
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
    );
  }
}

class _VerifiedBanner extends StatelessWidget {
  const _VerifiedBanner({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final s = context.status;
    return Container(
      padding: const EdgeInsets.all(Gap.xl),
      decoration: BoxDecoration(
        color: s.successContainer,
        borderRadius: Corners.lgAll,
      ),
      child: Row(
        children: [
          Icon(
            Icons.verified_rounded,
            color: s.success,
            size: 40,
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
          const SizedBox(width: Gap.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location verified',
                  style: context.text.titleMedium?.copyWith(color: s.success),
                ),
                Text(
                  '$name · enter the collected quantities below',
                  style: context.text.bodySmall?.copyWith(color: s.success),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: Gap.md),
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: context.colors.errorContainer,
        borderRadius: Corners.mdAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.block_rounded, size: 20, color: context.colors.error),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              message,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortfallHint extends StatelessWidget {
  const _ShortfallHint({required this.kg});

  final double kg;

  @override
  Widget build(BuildContext context) {
    final s = context.status;
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: s.warningContainer,
        borderRadius: Corners.mdAll,
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: s.warning),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              '${formatKg(kg)} kg below expected. This stop will be flagged in the trip report.',
              style: context.text.bodySmall?.copyWith(color: s.warning),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.2, end: 0);
  }
}
