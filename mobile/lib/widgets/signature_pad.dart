import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Holds the strokes drawn on a [SignaturePad] and exports them as a PNG.
class SignatureController extends ChangeNotifier {
  final List<List<Offset>> _strokes = [];
  Size _size = Size.zero;

  bool get isEmpty => _strokes.isEmpty;

  void _start(Offset p) {
    _strokes.add([p]);
    notifyListeners();
  }

  void _extend(Offset p) {
    if (_strokes.isEmpty) return;
    _strokes.last.add(p);
    notifyListeners();
  }

  void clear() {
    _strokes.clear();
    notifyListeners();
  }

  /// Renders the signature (dark ink on an opaque white background) at
  /// [scale] times the on-screen size.
  Future<Uint8List> toPng({double scale = 2}) async {
    final size = _size == Size.zero ? const Size(300, 160) : _size;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);

    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    _SignaturePainter(_strokes, const Color(0xFF111827), 3).paint(canvas, size);

    final image = await recorder.endRecording().toImage(
      (size.width * scale).round(),
      (size.height * scale).round(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }
}

/// A finger-drawing surface. Always shows dark ink on white, in light and dark
/// mode, so the stored image looks like a paper signature.
class SignaturePad extends StatelessWidget {
  const SignaturePad({super.key, required this.controller, this.height = 200});

  final SignatureController controller;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: Corners.mdAll,
      child: Container(
        height: height,
        color: Colors.white,
        child: LayoutBuilder(
          builder: (context, constraints) {
            controller._size = constraints.biggest;
            return Semantics(
              label: 'Signature pad. Draw the supplier signature here.',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) => controller._start(d.localPosition),
                onPanUpdate: (d) => controller._extend(d.localPosition),
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => CustomPaint(
                    size: Size.infinite,
                    painter: _SignaturePainter(
                      controller._strokes,
                      const Color(0xFF111827),
                      3,
                    ),
                    child: controller.isEmpty
                        ? const Center(
                            child: Text(
                              'Sign here',
                              style: TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 16,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.strokes, this.color, this.width);

  final List<List<Offset>> strokes;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length == 1) {
        // A tap: draw a dot.
        canvas.drawCircle(
          stroke.first,
          width / 2,
          paint..style = PaintingStyle.fill,
        );
        paint.style = PaintingStyle.stroke;
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        // Smooth the polyline with midpoint quadratic curves.
        final prev = stroke[i - 1];
        final cur = stroke[i];
        path.quadraticBezierTo(
          prev.dx,
          prev.dy,
          (prev.dx + cur.dx) / 2,
          (prev.dy + cur.dy) / 2,
        );
      }
      path.lineTo(stroke.last.dx, stroke.last.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => true;
}
