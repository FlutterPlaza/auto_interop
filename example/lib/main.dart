/// Example app demonstrating auto_interop usage with three native packages:
/// - date-fns (npm) for date formatting
/// - Alamofire (CocoaPods) for HTTP networking on iOS
/// - OkHttp (Gradle) for HTTP networking on Android
///
/// The generated bindings in lib/generated/ were produced by running:
///   dart run auto_interop_generator:generate
import 'package:flutter/material.dart';
import 'package:auto_interop/auto_interop.dart';

import 'generated/date_fns.dart';
import 'generated/alamofire.dart';
import 'generated/com_squareup_okhttp3_okhttp.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the native bridge runtime
  await AutoInteropLifecycle.instance.initialize();

  runApp(const AutoInteropExampleApp());
}

class AutoInteropExampleApp extends StatelessWidget {
  const AutoInteropExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'auto_interop Example',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const ExampleHomePage(),
    );
  }
}

class ExampleHomePage extends StatefulWidget {
  const ExampleHomePage({super.key});

  @override
  State<ExampleHomePage> createState() => _ExampleHomePageState();
}

class _ExampleHomePageState extends State<ExampleHomePage> {
  String _result = 'Tap a button to try a native binding.';

  // Dependency injection via interfaces — easy to mock in tests
  final DateFnsInterface _dateFns = DateFns.instance;
  final SessionInterface _session = Session();
  final OkHttpClientInterface _httpClient = OkHttpClient();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('auto_interop Example')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_result, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 24),

            // date-fns example
            FilledButton(
              onPressed: _formatDate,
              child: const Text('date-fns: Format Date'),
            ),
            const SizedBox(height: 8),

            // Alamofire example (iOS)
            FilledButton(
              onPressed: _alamofireRequest,
              child: const Text('Alamofire: GET Request (iOS)'),
            ),
            const SizedBox(height: 8),

            // OkHttp example (Android)
            FilledButton(
              onPressed: _okhttpRequest,
              child: const Text('OkHttp: GET Request (Android)'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _formatDate() async {
    try {
      final formatted = await _dateFns.format(
        DateTime.now(),
        'yyyy-MM-dd HH:mm:ss',
      );
      setState(() => _result = 'Formatted: $formatted');
    } catch (e) {
      setState(() => _result = 'Error: $e');
    }
  }

  Future<void> _alamofireRequest() async {
    try {
      final request = await _session.request(
        'https://httpbin.org/get',
        'GET',
        null,
      );
      setState(() => _result = 'Alamofire request created: $request');
    } catch (e) {
      setState(() => _result = 'Error: $e');
    }
  }

  Future<void> _okhttpRequest() async {
    try {
      final request = Request(
        url: 'https://httpbin.org/get',
        method: 'GET',
        headers: {'Accept': 'application/json'},
      );
      final call = await _httpClient.newCall(request);
      setState(() => _result = 'OkHttp call created: $call');
    } catch (e) {
      setState(() => _result = 'Error: $e');
    }
  }
}
