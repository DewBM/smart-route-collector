import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_route/widgets/signature_pad.dart';

void main() {
  testWidgets('drawing fills the pad and exports a PNG', (tester) async {
    final controller = SignatureController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SignaturePad(controller: controller)),
      ),
    );

    expect(controller.isEmpty, isTrue);
    expect(find.text('Sign here'), findsOneWidget);

    final pad = find.byType(SignaturePad);
    final gesture = await tester.startGesture(tester.getCenter(pad));
    await gesture.moveBy(const Offset(40, 15));
    await gesture.moveBy(const Offset(30, -20));
    await gesture.up();
    await tester.pump();

    expect(controller.isEmpty, isFalse);
    expect(find.text('Sign here'), findsNothing);

    final png = await tester.runAsync(controller.toPng);
    // PNG magic number.
    expect(png!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);

    controller.clear();
    await tester.pump();
    expect(controller.isEmpty, isTrue);
  });
}
