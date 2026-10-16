import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_route/theme/app_theme.dart';
import 'package:smart_route/widgets/status_chip.dart';

void main() {
  for (final theme in {
    'light': AppTheme.light,
    'dark': AppTheme.dark,
  }.entries) {
    testWidgets('StatusChip renders every status (${theme.key})', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme.value,
          home: const Scaffold(
            body: Column(
              children: [
                StatusChip('Pending'),
                StatusChip('Next'),
                StatusChip('Collected'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Collected'), findsOneWidget);
    });
  }
}
