import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soloud_test/main.dart';

void main() {
  testWidgets('SoLoud Position Test UI loads correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MaterialApp(
      home: SoLoudPositionTest(),
    ));

    // Verify that the title is displayed
    expect(find.text('SoLoud Position Test'), findsOneWidget);

    // Verify that the run button is displayed
    expect(find.text('Run Position Test'), findsOneWidget);

    // Verify that the button is enabled
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNotNull);
  });
}
