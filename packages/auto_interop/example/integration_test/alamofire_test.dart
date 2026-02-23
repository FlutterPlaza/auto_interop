import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:auto_interop_example/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Alamofire GET request succeeds', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    final button = find.text('Alamofire: GET Request');
    expect(button, findsOneWidget);
    await tester.tap(button);

    String? resultText;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      resultText = _findTextContaining(tester, 'Status:');
      if (resultText != null) break;
    }

    debugPrint('=== ALAMOFIRE RESULT ===');
    debugPrint(resultText ?? '(no result)');

    expect(resultText, isNotNull, reason: 'Should get a response');
    expect(resultText, contains('Status:'));
  });

  testWidgets('Sensor stream emits data via EventChannel', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Scroll down to find the Start Stream button
    await tester.scrollUntilVisible(
      find.text('Start Stream'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final button = find.text('Start Stream');
    expect(button, findsOneWidget);
    await tester.tap(button);

    // Wait for stream events to arrive
    String? resultText;
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      resultText = _findTextContaining(tester, 'x:');
      if (resultText != null) break;
    }

    debugPrint('=== SENSOR STREAM RESULT ===');
    debugPrint(resultText ?? '(no result)');

    expect(resultText, isNotNull, reason: 'Should receive sensor events');
    expect(resultText, contains('x:'));
    expect(resultText, contains('y:'));
    expect(resultText, contains('z:'));

    // Stop the stream
    final stopButton = find.text('Stop Stream');
    if (stopButton.evaluate().isNotEmpty) {
      await tester.tap(stopButton);
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Native object lifecycle works', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Session Lifecycle'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final button = find.text('Session Lifecycle');
    expect(button, findsOneWidget);
    await tester.tap(button);

    String? resultText;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      resultText = _findTextContaining(tester, 'Disposed Session');
      if (resultText != null) break;
    }

    debugPrint('=== NATIVE OBJECT RESULT ===');
    debugPrint(resultText ?? '(no result)');

    expect(resultText, isNotNull, reason: 'Should complete lifecycle');
    expect(resultText, contains('Created Session'));
    expect(resultText, contains('Disposed Session'));
  });

  testWidgets('File download with callbacks works', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Download File'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final button = find.text('Download File');
    expect(button, findsOneWidget);
    await tester.tap(button);

    // Wait for download progress or completion
    String? resultText;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      // Look for either progress updates or completion
      resultText = _findTextContaining(tester, 'Download complete') ??
          _findTextContaining(tester, 'Downloading:');
      if (resultText != null && resultText.contains('complete')) break;
    }

    debugPrint('=== FILE DOWNLOAD RESULT ===');
    debugPrint(resultText ?? '(no result)');

    expect(resultText, isNotNull, reason: 'Should see download activity');
  });

  testWidgets('Error handling shows structured exception', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Trigger Error'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final button = find.text('Trigger Error');
    expect(button, findsOneWidget);
    await tester.tap(button);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    String? resultText = _findTextContaining(tester, 'AutoInteropException') ??
        _findTextContaining(tester, 'code:');

    debugPrint('=== ERROR HANDLING RESULT ===');
    debugPrint(resultText ?? '(no result)');

    expect(resultText, isNotNull, reason: 'Should catch and display error');
  });
}

/// Finds a Text widget containing the given substring.
String? _findTextContaining(WidgetTester tester, String substring) {
  final textWidgets = find.byType(Text).evaluate();
  for (final element in textWidgets) {
    final widget = element.widget as Text;
    final data = widget.data ?? '';
    if (data.contains(substring)) return data;
  }
  return null;
}
