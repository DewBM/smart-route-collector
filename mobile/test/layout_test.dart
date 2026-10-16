import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_route/models/trip_stop.dart';
import 'package:smart_route/screens/trip_sequence/stop_timeline_tile.dart';
import 'package:smart_route/theme/app_theme.dart';
import 'package:smart_route/widgets/kg_field.dart';
import 'package:smart_route/widgets/progress_ring.dart';
import 'package:smart_route/widgets/stat_tile.dart';

TripStop _stop(String status) => TripStop(
  supplierId: 1,
  supplierName: 'Kurunegala Waste Recycling Collection Centre',
  latitude: 7.48,
  longitude: 80.36,
  barcodeRef: 'SUP-001',
  expectedClearKg: 120.5,
  expectedColouredKg: 80,
  status: status,
  stopOrder: 12,
  distanceFromPrevKm: 34.7,
);

/// Pumps [child] on a small phone with the maximum text scale the app allows
/// (1.3). Any RenderFlex overflow fails the test.
Future<void> _pumpSmall(
  WidgetTester tester,
  Widget child,
  ThemeData theme,
) async {
  _errors.clear();
  _originalOnError = FlutterError.onError;
  FlutterError.onError = (d) => _errors.add(d.toString());
  tester.view.physicalSize = const Size(320 * 3, 568 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: 1.3,
        maxScaleFactor: 1.3,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  for (final t in {'light': AppTheme.light, 'dark': AppTheme.dark}.entries) {
    for (final status in ['Pending', 'Next', 'Collected']) {
      testWidgets('timeline tile fits small screen: $status (${t.key})', (
        tester,
      ) async {
        await _pumpSmall(
          tester,
          Padding(
            padding: const EdgeInsets.all(16),
            child: StopTimelineTile(
              stop: _stop(status),
              isFirst: false,
              isLast: false,
              onScan: () {},
              onNavigate: () {},
            ),
          ),
          t.value,
        );
        _expectNoOverflow(tester);
      });
    }

    testWidgets('kg field + hero stats fit small screen (${t.key})', (
      tester,
    ) async {
      await _pumpSmall(
        tester,
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              KgField(
                controller: TextEditingController(text: '120.5'),
                label: 'Coloured glass',
                icon: Icons.palette_outlined,
                accent: Colors.purple,
                expectedKg: 120.5,
              ),
              Row(
                children: [
                  const ProgressRing(progress: 0.5, center: Text('4/8')),
                  const SizedBox(width: 24),
                  const Expanded(
                    child: StatTile(
                      icon: Icons.route_rounded,
                      value: '120.2 km',
                      label: 'Total distance',
                    ),
                  ),
                  const Expanded(
                    child: StatTile(
                      icon: Icons.flag_rounded,
                      value: '4',
                      label: 'Remaining',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        t.value,
      );
      _expectNoOverflow(tester);
    });
  }
}

final _errors = <String>[];
void Function(FlutterErrorDetails)? _originalOnError;

void _expectNoOverflow(WidgetTester tester) {
  tester.takeException();
  FlutterError.onError = _originalOnError;
  if (_errors.isNotEmpty) fail(_errors.first.split('The overflowing').first);
}
