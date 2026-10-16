import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:smart_route/models/trip.dart';
import 'package:smart_route/models/trip_stop.dart';
import 'package:smart_route/providers/collection_provider.dart';
import 'package:smart_route/providers/trip_provider.dart';
import 'package:smart_route/screens/scan_collect/scan_collect_screen.dart';
import 'package:smart_route/theme/app_theme.dart';
import 'package:smart_route/widgets/signature_pad.dart';

/// A scanner that never touches the camera: tests push barcodes through
/// [emit], exactly as the native plugin would.
class FakeScanner extends MobileScannerPlatform {
  final _barcodes = StreamController<BarcodeCapture?>.broadcast();

  void emit(String value) => _barcodes.add(
    BarcodeCapture(
      barcodes: [Barcode(rawValue: value, format: BarcodeFormat.code128)],
    ),
  );

  @override
  Stream<BarcodeCapture?> get barcodesStream => _barcodes.stream;
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() => const ColoredBox(color: Color(0xFF1F2937));
  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async =>
      const MobileScannerViewAttributes(
        cameraDirection: CameraFacing.back,
        currentTorchMode: TorchState.off,
        size: Size(1280, 720),
      );
  @override
  Future<void> stop() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> toggleTorch() async {}
  @override
  Future<void> updateScanWindow(Rect? window) async {}
  @override
  Future<void> resetZoomScale() async {}
  @override
  Future<void> setZoomScale(double zoomScale) async {}
  @override
  Future<Set<CameraLensType>> getSupportedLenses() async => {};
  @override
  Future<void> dispose() async {}
}

class FakeTrips extends ChangeNotifier implements TripProvider {
  final advanced = <int>[];

  @override
  Trip get trip =>
      Trip(tripId: 7, tripDate: '2026-10-16', totalDistanceKm: 87.6, stops: []);
  @override
  Future<void> advanceStop(int completedSupplierId) async =>
      advanced.add(completedSupplierId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCollections extends ChangeNotifier implements CollectionProvider {
  final submitted = <Map<String, Object?>>[];

  @override
  bool get isSubmitting => false;
  @override
  String? get error => null;

  @override
  Future<bool> submitCollection({
    required int tripId,
    required int supplierId,
    required double clearKg,
    required double colouredKg,
    required String condition,
    String? photoPath,
    String? signaturePath,
    String? signerName,
  }) async {
    submitted.add({
      'tripId': tripId,
      'supplierId': supplierId,
      'clearKg': clearKg,
      'colouredKg': colouredKg,
      'condition': condition,
    });
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _stop = TripStop(
  supplierId: 1,
  supplierName: 'Kurunegala Glass Traders',
  latitude: 7.4863,
  longitude: 80.3647,
  barcodeRef: 'GL-SUP-001',
  expectedClearKg: 120,
  expectedColouredKg: 80,
  status: 'Next',
  stopOrder: 1,
  distanceFromPrevKm: 0.7,
);

const _shotDir = String.fromEnvironment('SHOT_DIR');
final _boundary = GlobalKey();

Future<void> _loadFonts() async {
  final app = FontLoader('PlusJakartaSans')
    ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'));
  await app.load();

  final root = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
  final icons = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await loader.load();
  }
}

Future<void> _screenshot(WidgetTester tester, String name) async {
  if (_shotDir.isEmpty) return;
  await tester.runAsync(() async {
    final boundary =
        _boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.625);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_shotDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<(FakeScanner, FakeTrips, FakeCollections)> _pump(
  WidgetTester tester,
) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);

  final scanner = FakeScanner();
  MobileScannerPlatform.instance = scanner;
  final trips = FakeTrips();
  final collections = FakeCollections();

  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundary,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<TripProvider>.value(value: trips),
          ChangeNotifierProvider<CollectionProvider>.value(value: collections),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: ScanCollectScreen(stop: _stop),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
  return (scanner, trips, collections);
}

/// Tear the tree down and let animation timers fire, so none are left pending.
Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('form is locked until the correct barcode is scanned', (
    tester,
  ) async {
    final (scanner, _, _) = await _pump(tester);

    expect(find.text('Scan the barcode to unlock'), findsOneWidget);
    expect(find.text('Location verified'), findsNothing);
    await _screenshot(tester, '08-scan-locked');

    // A code that belongs to no supplier.
    scanner.emit('GL-WRONG-999');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('different supplier'), findsOneWidget);
    expect(find.text('Scan the barcode to unlock'), findsOneWidget);
    expect(find.text('Location verified'), findsNothing);
    await _screenshot(tester, '08b-scan-wrong-barcode');

    // A real supplier, but not this stop.
    scanner.emit('GL-SUP-005');
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Scan the barcode to unlock'), findsOneWidget);
    expect(find.text('Location verified'), findsNothing);
    await _finish(tester);
  });

  testWidgets('the correct barcode unlocks the form', (tester) async {
    final (scanner, _, _) = await _pump(tester);

    scanner.emit('GL-SUP-001');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Location verified'), findsOneWidget);
    expect(find.text('Scan the barcode to unlock'), findsNothing);
    await _screenshot(tester, '10-scan-verified');
    await _finish(tester);
  });

  testWidgets('validates, then submits the collection for the right supplier', (
    tester,
  ) async {
    final (scanner, trips, collections) = await _pump(tester);
    scanner.emit('GL-SUP-001');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    final confirm = find.text('Confirm collection');
    await tester.scrollUntilVisible(
      confirm,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(confirm);
    await tester.pump();
    await tester.tap(confirm);
    await tester.pump();
    expect(find.text('Enter a weight (0 if none)'), findsNWidgets(2));
    expect(find.text('Select the glass condition'), findsOneWidget);
    expect(collections.submitted, isEmpty);

    await tester.enterText(find.byType(TextFormField).at(0), '100');
    await tester.enterText(find.byType(TextFormField).at(1), '80');
    await tester.pump();
    expect(
      find.text('Enter a weight (0 if none)'),
      findsNothing,
      reason: 'errors clear as soon as the values are valid',
    );
    await tester.tap(find.text('Clean'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('below expected'), findsOneWidget);
    await _screenshot(tester, '11-scan-form-shortfall');

    await tester.ensureVisible(confirm);
    await tester.pump();
    await tester.tap(confirm);
    await tester.pump(const Duration(milliseconds: 300));

    expect(collections.submitted, hasLength(1));
    expect(collections.submitted.single, {
      'tripId': 7,
      'supplierId': 1,
      'clearKg': 100.0,
      'colouredKg': 80.0,
      'condition': 'Clean',
    });
    expect(trips.advanced, [1]);
    await _finish(tester);
  });

  testWidgets('supplier signature: draw, save and show on the form', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('glassline_sig');
    addTearDown(() => dir.deleteSync(recursive: true));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => dir.path,
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          ),
    );

    final (scanner, _, _) = await _pump(tester);
    scanner.emit('GL-SUP-001');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    final open = find.text('Get supplier signature');
    await tester.scrollUntilVisible(
      open,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(open);
    await tester.pump();
    await tester.tap(open);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Supplier signature'), findsWidgets);
    final save = find.widgetWithText(FilledButton, 'Save');
    expect(
      tester.widget<FilledButton>(save).onPressed,
      isNull,
      reason: 'Save is disabled until something is drawn',
    );

    await tester.enterText(find.byType(TextField).last, 'N. Perera');
    final pad = find.byType(SignaturePad);
    final g = await tester.startGesture(
      tester.getCenter(pad) + const Offset(-110, 20),
    );
    for (final d in const [
      Offset(40, -60),
      Offset(40, 70),
      Offset(40, -70),
      Offset(40, 60),
      Offset(60, -30),
    ]) {
      await g.moveBy(d);
    }
    await g.up();
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    await tester.pump(const Duration(milliseconds: 600));
    await _screenshot(tester, '12-signature-sheet');

    await _finish(tester);
  });
}
