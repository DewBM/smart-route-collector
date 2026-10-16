import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../theme/app_tokens.dart';

/// Camera preview with a corner-bracket scan frame, animated scan line and
/// torch toggle. [hasError] tints the frame red.
class ScannerPanel extends StatelessWidget {
  const ScannerPanel({
    super.key,
    required this.controller,
    required this.onDetect,
    required this.hasError,
  });

  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final frameColor = hasError ? const Color(0xFFFB7185) : Colors.white;

    return ClipRRect(
      borderRadius: Corners.lgAll,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: controller, onDetect: onDetect),
          const CustomPaint(painter: _DimPainter(), size: Size.infinite),
          Center(
            child: SizedBox(
              width: 260,
              height: 150,
              child: Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      borderRadius: Corners.mdAll,
                      border: Border.all(
                        color: frameColor.withValues(alpha: 0.9),
                        width: 3,
                      ),
                    ),
                  ),
                  if (!hasError)
                    Positioned(
                      left: 10,
                      right: 10,
                      top: 10,
                      child:
                          Container(
                                height: 2.5,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.white54,
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              )
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .moveY(begin: 0, end: 124, duration: 1500.ms),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            top: Gap.md,
            right: Gap.md,
            child: ValueListenableBuilder(
              valueListenable: controller,
              builder: (context, state, _) {
                final on = state.torchState == TorchState.on;
                return IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: on ? Colors.white : Colors.black45,
                    foregroundColor: on ? Colors.black : Colors.white,
                  ),
                  tooltip: 'Torch',
                  onPressed: controller.toggleTorch,
                  icon: Icon(
                    on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: Gap.lg,
            child: Text(
              'Align the barcode inside the frame',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Darkens everything except a rounded window in the centre.
class _DimPainter extends CustomPainter {
  const _DimPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final window = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: size.center(Offset.zero),
        width: 260,
        height: 150,
      ),
      const Radius.circular(Corners.md),
    );
    final path = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(window),
    );
    canvas.drawPath(path, Paint()..color = const Color(0x99000000));
  }

  @override
  bool shouldRepaint(_DimPainter old) => false;
}
