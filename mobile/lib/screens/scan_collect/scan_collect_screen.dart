import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../models/trip_stop.dart';
import '../../providers/collection_provider.dart';
import '../../providers/trip_provider.dart';

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
  final _conditionController = TextEditingController();

  bool _isVerified = false;
  bool _isScanning = false;
  String? _scanError;

  @override
  void dispose() {
    _scannerController.dispose();
    _clearKgController.dispose();
    _colouredKgController.dispose();
    _conditionController.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_isVerified) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;

    final scannedValue = barcode.rawValue ?? '';

    if (scannedValue == widget.stop.barcodeRef) {
      _scannerController.stop();
      setState(() {
        _isVerified = true;
        _scanError = null;
        _isScanning = false;
      });
    } else {
      setState(() {
        _scanError =
            'Wrong location. Expected ${widget.stop.barcodeRef}, got $scannedValue.';
      });
    }
  }

  Future<void> _submitCollection() async {
    if (!_formKey.currentState!.validate()) return;

    final tripProvider = context.read<TripProvider>();
    final collectionProvider = context.read<CollectionProvider>();

    final tripId = tripProvider.trip!.tripId;
    final supplierId = widget.stop.supplierId;

    await collectionProvider.submitCollection(
      tripId: tripId,
      supplierId: supplierId,
      clearKg: double.parse(_clearKgController.text),
      colouredKg: double.parse(_colouredKgController.text),
      condition: _conditionController.text,
    );

    await tripProvider.advanceStop(supplierId);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.stop.supplierName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStopInfoCard(theme),
            const SizedBox(height: 16),
            _buildScanSection(theme),
            const SizedBox(height: 16),
            _buildCollectionForm(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildStopInfoCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stop Details',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.location_on,
              'Coordinates',
              '${widget.stop.latitude.toStringAsFixed(4)}, ${widget.stop.longitude.toStringAsFixed(4)}',
              theme,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.water_drop,
              'Expected Clear Glass',
              '${widget.stop.expectedClearKg} kg',
              theme,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.color_lens,
              'Expected Coloured Glass',
              '${widget.stop.expectedColouredKg} kg',
              theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    ThemeData theme,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildScanSection(ThemeData theme) {
    if (_isVerified) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: theme.colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Location verified: ${widget.stop.supplierName}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Scan Location Barcode',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_isScanning) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 250,
              child: MobileScanner(
                controller: _scannerController,
                onDetect: _onBarcodeDetected,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _isScanning = false),
              child: const Text('Cancel Scan'),
            ),
          ),
        ] else ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () => setState(() {
                _isScanning = true;
                _scanError = null;
              }),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Barcode'),
            ),
          ),
        ],
        if (_scanError != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: theme.colorScheme.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _scanError!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCollectionForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Collection Details',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: _isVerified
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _clearKgController,
            enabled: _isVerified,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              labelText: 'Clear Glass (kg)',
              border: const OutlineInputBorder(),
              suffixText: 'kg',
              filled: !_isVerified,
              fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Required';
              if (double.tryParse(value) == null) return 'Enter a valid number';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _colouredKgController,
            enabled: _isVerified,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              labelText: 'Coloured Glass (kg)',
              border: const OutlineInputBorder(),
              suffixText: 'kg',
              filled: !_isVerified,
              fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Required';
              if (double.tryParse(value) == null) return 'Enter a valid number';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _conditionController,
            enabled: _isVerified,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Condition',
              border: const OutlineInputBorder(),
              hintText: 'e.g. Clean, Contaminated, Broken',
              filled: !_isVerified,
              fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Required';
              return null;
            },
          ),
          const SizedBox(height: 24),
          Consumer<CollectionProvider>(
            builder: (context, collectionProvider, _) {
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _isVerified && !collectionProvider.isSubmitting
                      ? _submitCollection
                      : null,
                  child: collectionProvider.isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Confirm Collection'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
