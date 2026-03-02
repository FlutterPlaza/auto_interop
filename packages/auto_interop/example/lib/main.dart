/// Example app demonstrating all auto_interop runtime capabilities.
///
/// Three native plugins are exercised on iOS:
///   1. Alamofire — HTTP GET, POST, Download, Upload via platform channels
///   2. SensorStream — Accelerometer event stream via EventChannel
///   3. FileDownloader — File download with Dart callback progress reporting
///
/// The app also demonstrates:
///   - NativeObject handle-based lifecycle (create → use → dispose)
///   - ErrorHandler structured error propagation
///   - TypeConverter DateTime serialization (sensor timestamps)
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:auto_interop/auto_interop.dart';

import 'generated/alamofire.dart';
import 'generated/sensor_stream.dart';
import 'generated/file_downloader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AutoInteropLifecycle.instance.initialize();
  runApp(const AutoInteropShowcase());
}

class AutoInteropShowcase extends StatelessWidget {
  const AutoInteropShowcase({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'auto_interop Showcase',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const _MainShell(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main shell with bottom navigation
// ─────────────────────────────────────────────────────────────────────────────

class _MainShell extends StatefulWidget {
  const _MainShell();
  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _tab = 0;

  static const _pages = <Widget>[
    _HttpTab(),
    _SensorsTab(),
    _SystemTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Scaffold(
        body: _pages[_tab],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.http), label: 'HTTP'),
            NavigationDestination(icon: Icon(Icons.sensors), label: 'Sensors'),
            NavigationDestination(icon: Icon(Icons.build), label: 'System'),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 1 — HTTP (Alamofire)
// ═══════════════════════════════════════════════════════════════════════════════

class _HttpTab extends StatelessWidget {
  const _HttpTab();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverAppBar.large(title: Text('Alamofire HTTP')),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList.list(children: const [
            _GetRequestDemo(),
            SizedBox(height: 12),
            _PostRequestDemo(),
            SizedBox(height: 12),
            _DownloadDemo(),
            SizedBox(height: 12),
            _UploadDemo(),
            SizedBox(height: 12),
            _CancelResumeDemo(),
          ]),
        ),
      ],
    );
  }
}

// 1a. GET Request
class _GetRequestDemo extends StatefulWidget {
  const _GetRequestDemo();
  @override
  State<_GetRequestDemo> createState() => _GetRequestDemoState();
}

class _GetRequestDemoState extends State<_GetRequestDemo> {
  String _info = 'Tap to make a GET request via native Alamofire.';
  bool _loading = false;
  Session? _session;

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      _session ??= await Session.create();
      final req = await _session!.request(
        'https://httpbin.org/get',
        HTTPMethod.get,
        null,
      );
      final resp = await req.response();
      final body = resp.data != null ? utf8.decode(resp.data!) : '(empty)';
      final json = jsonDecode(body) as Map<String, dynamic>;
      setState(() {
        _info = 'Status: ${resp.statusCode}\n'
            'Origin: ${json['origin']}\n'
            'URL: ${json['url']}\n'
            'Headers received: ${resp.headers.length}';
      });
      await req.dispose();
    } on AutoInteropException catch (e) {
      setState(() => _info = 'Native error: ${e.code} — ${e.message}');
    } catch (e) {
      setState(() => _info = 'Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _DemoCard(
      title: 'GET Request',
      subtitle: 'AutoInteropChannel.invoke<T>()',
      result: _info,
      loading: _loading,
      onTap: _fetch,
      buttonLabel: 'GET httpbin.org/get',
    );
  }
}

// 1b. POST Request
class _PostRequestDemo extends StatefulWidget {
  const _PostRequestDemo();
  @override
  State<_PostRequestDemo> createState() => _PostRequestDemoState();
}

class _PostRequestDemoState extends State<_PostRequestDemo> {
  String _info = 'Tap to POST JSON data via Alamofire.';
  bool _loading = false;
  Session? _session;

  Future<void> _post() async {
    setState(() => _loading = true);
    try {
      _session ??= await Session.create();
      final req = await _session!.request(
        'https://httpbin.org/post',
        HTTPMethod.post,
        {'Content-Type': 'application/json'},
      );
      final resp = await req.response();
      final body = resp.data != null ? utf8.decode(resp.data!) : '(empty)';
      final json = jsonDecode(body) as Map<String, dynamic>;
      setState(() {
        _info = 'Status: ${resp.statusCode}\n'
            'Echoed data: ${json['data'] ?? '(none)'}\n'
            'Content-Type: ${json['headers']?['Content-Type'] ?? 'n/a'}';
      });
      await req.dispose();
    } on AutoInteropException catch (e) {
      setState(() => _info = 'Native error: ${e.code} — ${e.message}');
    } catch (e) {
      setState(() => _info = 'Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _DemoCard(
      title: 'POST Request',
      subtitle: 'HTTPMethod enum + custom headers',
      result: _info,
      loading: _loading,
      onTap: _post,
      buttonLabel: 'POST httpbin.org/post',
    );
  }
}

// 1c. Download
class _DownloadDemo extends StatefulWidget {
  const _DownloadDemo();
  @override
  State<_DownloadDemo> createState() => _DownloadDemoState();
}

class _DownloadDemoState extends State<_DownloadDemo> {
  String _info = 'Tap to download a file via Alamofire.';
  bool _loading = false;
  Session? _session;

  Future<void> _download() async {
    setState(() => _loading = true);
    try {
      _session ??= await Session.create();
      final result = await _session!.download(
        'https://httpbin.org/bytes/4096',
        '/tmp/alamofire_test.bin',
      );
      setState(() => _info = 'Download result: $result');
    } on AutoInteropException catch (e) {
      setState(() => _info = 'Native error: ${e.code} — ${e.message}');
    } catch (e) {
      setState(() => _info = 'Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _DemoCard(
      title: 'Download File',
      subtitle: 'Session.download() with destination path',
      result: _info,
      loading: _loading,
      onTap: _download,
      buttonLabel: 'Download 4 KB',
    );
  }
}

// 1d. Upload
class _UploadDemo extends StatefulWidget {
  const _UploadDemo();
  @override
  State<_UploadDemo> createState() => _UploadDemoState();
}

class _UploadDemoState extends State<_UploadDemo> {
  String _info = 'Tap to upload binary data via Alamofire.';
  bool _loading = false;
  Session? _session;

  Future<void> _upload() async {
    setState(() => _loading = true);
    try {
      _session ??= await Session.create();
      // Create 1 KB of test data
      final data = Uint8List(1024);
      for (var i = 0; i < data.length; i++) {
        data[i] = i % 256;
      }
      final result = await _session!.upload(data, 'https://httpbin.org/post');
      setState(() => _info = 'Upload result: $result');
    } on AutoInteropException catch (e) {
      setState(() => _info = 'Native error: ${e.code} — ${e.message}');
    } catch (e) {
      setState(() => _info = 'Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _DemoCard(
      title: 'Upload Data',
      subtitle: 'Session.upload() with Uint8List binary data',
      result: _info,
      loading: _loading,
      onTap: _upload,
      buttonLabel: 'Upload 1 KB',
    );
  }
}

// 1e. Cancel / Resume
class _CancelResumeDemo extends StatefulWidget {
  const _CancelResumeDemo();
  @override
  State<_CancelResumeDemo> createState() => _CancelResumeDemoState();
}

class _CancelResumeDemoState extends State<_CancelResumeDemo> {
  String _info = 'Tap to start a request, then cancel or resume it.';
  bool _loading = false;
  Session? _session;
  DataRequest? _activeRequest;

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _info = 'Request started... use Cancel or Resume.';
    });
    try {
      _session ??= await Session.create();
      _activeRequest = await _session!.request(
        'https://httpbin.org/delay/5',
        HTTPMethod.get,
        null,
      );
      setState(() => _info = 'Request in-flight to /delay/5...');
      final resp = await _activeRequest!.response();
      setState(() {
        _info = 'Response received: status ${resp.statusCode}';
        _activeRequest = null;
      });
    } on AutoInteropException catch (e) {
      setState(() {
        _info = 'Native error: ${e.code} — ${e.message}';
        _activeRequest = null;
      });
    } catch (e) {
      setState(() {
        _info = 'Error: $e';
        _activeRequest = null;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _cancel() async {
    if (_activeRequest == null) return;
    await _activeRequest!.cancel();
    setState(() => _info = 'Request cancelled.');
  }

  Future<void> _resume() async {
    if (_activeRequest == null) return;
    await _activeRequest!.resume();
    setState(() => _info = 'Request resumed.');
  }

  @override
  void dispose() {
    _activeRequest?.dispose();
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasActive = _activeRequest != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Cancel / Resume',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'DataRequest.cancel() and .resume() control in-flight requests',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _ResultBox(text: _info, loading: _loading),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _loading ? null : _start,
                    child: const Text('Start'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: hasActive ? _cancel : null,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: hasActive ? _resume : null,
                    child: const Text('Resume'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Sensors (EventChannel)
// ═══════════════════════════════════════════════════════════════════════════════

class _SensorsTab extends StatelessWidget {
  const _SensorsTab();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverAppBar.large(title: Text('Sensor Streams')),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList.list(children: const [
            _AccelerometerDemo(),
          ]),
        ),
      ],
    );
  }
}

class _AccelerometerDemo extends StatefulWidget {
  const _AccelerometerDemo();
  @override
  State<_AccelerometerDemo> createState() => _AccelerometerDemoState();
}

class _AccelerometerDemoState extends State<_AccelerometerDemo> {
  double _x = 0, _y = 0, _z = 0;
  String _timestamp = '';
  bool _streaming = false;
  String? _error;
  StreamSubscription<AccelerometerEvent>? _sub;
  int _eventCount = 0;

  void _toggle() {
    if (_streaming) {
      _sub?.cancel();
      _sub = null;
      setState(() {
        _streaming = false;
        _error = null;
      });
    } else {
      setState(() {
        _error = null;
        _eventCount = 0;
      });
      try {
        _sub =
            SensorStream.instance.accelerometerEvents(samplingRate: 30).listen(
          (e) {
            _eventCount++;
            setState(() {
              _x = e.x;
              _y = e.y;
              _z = e.z;
              _timestamp = '${e.timestamp.hour.toString().padLeft(2, '0')}:'
                  '${e.timestamp.minute.toString().padLeft(2, '0')}:'
                  '${e.timestamp.second.toString().padLeft(2, '0')}.'
                  '${e.timestamp.millisecond.toString().padLeft(3, '0')}';
            });
          },
          onError: (Object error) {
            setState(() {
              _streaming = false;
              _error = error is AutoInteropException
                  ? '${error.code}: ${error.message}'
                  : '$error';
            });
          },
        );
        setState(() => _streaming = true);
      } catch (e) {
        setState(() => _error = '$e');
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Accelerometer', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'AutoInteropEventChannel streams native sensor data to Dart. '
              'TypeConverter handles DateTime serialization.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!,
                    style:
                        TextStyle(color: theme.colorScheme.onErrorContainer)),
              )
            else ...[
              _AxisBar(label: 'X', value: _x, color: Colors.red),
              const SizedBox(height: 8),
              _AxisBar(label: 'Y', value: _y, color: Colors.green),
              const SizedBox(height: 8),
              _AxisBar(label: 'Z', value: _z, color: Colors.blue),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _streaming ? 'Events: $_eventCount' : 'Not streaming',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (_timestamp.isNotEmpty)
                    Text(_timestamp, style: theme.textTheme.bodySmall),
                ],
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _toggle,
              icon: Icon(_streaming ? Icons.stop : Icons.play_arrow),
              label: Text(_streaming ? 'Stop Stream' : 'Start Stream'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AxisBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _AxisBar(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    // Normalize: accelerometer values are typically -1.0 to 1.0 (in g)
    final clamped = value.clamp(-2.0, 2.0);
    final fraction = (clamped + 2.0) / 4.0; // 0.0 → 1.0
    return Row(
      children: [
        SizedBox(
            width: 20,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold))),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 20,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Text(
            value.toStringAsFixed(3),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 3 — System (Downloads, Lifecycle, Errors)
// ═══════════════════════════════════════════════════════════════════════════════

class _SystemTab extends StatelessWidget {
  const _SystemTab();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverAppBar.large(title: Text('System')),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList.list(children: const [
            _FileDownloadDemo(),
            SizedBox(height: 12),
            _HandleLifecycleDemo(),
            SizedBox(height: 12),
            _ErrorHandlingDemo(),
          ]),
        ),
      ],
    );
  }
}

// 3a. File download with progress callbacks
class _FileDownloadDemo extends StatefulWidget {
  const _FileDownloadDemo();
  @override
  State<_FileDownloadDemo> createState() => _FileDownloadDemoState();
}

class _FileDownloadDemoState extends State<_FileDownloadDemo> {
  double _progress = 0;
  int _bytesReceived = 0;
  int _totalBytes = 0;
  String _status = 'idle';
  String? _error;

  Future<void> _start() async {
    setState(() {
      _progress = 0;
      _bytesReceived = 0;
      _totalBytes = 0;
      _status = 'starting';
      _error = null;
    });
    try {
      await FileDownloader.instance.download(
        url: 'https://httpbin.org/bytes/1048576',
        destination: '/tmp/auto_interop_test.bin',
        onProgress: (p) {
          setState(() {
            _progress = p.progress;
            _bytesReceived = p.bytesReceived;
            _totalBytes = p.totalBytes;
            _status = 'downloading';
          });
        },
        onComplete: (status, error) {
          setState(() {
            _status = status.name;
            _error = error;
            if (status == DownloadStatus.completed) _progress = 1.0;
          });
        },
      );
    } on AutoInteropException catch (e) {
      setState(() {
        _status = 'error';
        _error = '${e.code}: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _status = 'error';
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDone = _status == 'completed';
    final isFailed = _status == 'failed' || _status == 'error';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('File Download', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'CallbackManager registers Dart functions invoked from native. '
              'onProgress and onComplete fire as the download proceeds.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 24,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  isDone
                      ? Colors.green
                      : isFailed
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(_progress * 100).toInt()}%',
                  style: const TextStyle(
                      fontFamily: 'monospace', fontWeight: FontWeight.bold),
                ),
                Text(
                  _totalBytes > 0
                      ? '${(_bytesReceived / 1024).toStringAsFixed(0)} / ${(_totalBytes / 1024).toStringAsFixed(0)} KB'
                      : _status,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style:
                      TextStyle(color: theme.colorScheme.error, fontSize: 12)),
            ],
            if (isDone) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Text('Saved to /tmp/auto_interop_test.bin',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.green)),
                ],
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: (_status == 'downloading' || _status == 'starting')
                  ? null
                  : _start,
              icon: const Icon(Icons.download),
              label: const Text('Download 1 MB'),
            ),
          ],
        ),
      ),
    );
  }
}

// 3b. Handle lifecycle
class _HandleLifecycleDemo extends StatefulWidget {
  const _HandleLifecycleDemo();
  @override
  State<_HandleLifecycleDemo> createState() => _HandleLifecycleDemoState();
}

class _HandleLifecycleDemoState extends State<_HandleLifecycleDemo> {
  final List<_HandleEntry> _handles = [];
  String _log = '';
  bool _loading = false;

  Future<void> _createSession() async {
    setState(() => _loading = true);
    try {
      final session = await Session.create();
      setState(() {
        _handles.add(_HandleEntry('Session', session));
        _log += 'Created Session handle\n';
      });
    } catch (e) {
      setState(() => _log += 'Error: $e\n');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _useAndDispose(int index) async {
    if (index >= _handles.length) return;
    final entry = _handles[index];
    final session = entry.object as Session;
    setState(() => _log += 'Using ${entry.type}...\n');
    try {
      final req = await session.request(
          'https://httpbin.org/status/200', HTTPMethod.get, null);
      final resp = await req.response();
      setState(() => _log += '  Response: ${resp.statusCode}\n');
      await req.dispose();
      setState(() => _log += '  Disposed DataRequest\n');
      await session.dispose();
      setState(() {
        _log += '  Disposed ${entry.type} — native memory freed\n';
        _handles.removeAt(index);
      });
    } catch (e) {
      setState(() => _log += '  Error: $e\n');
    }
  }

  Future<void> _disposeAll() async {
    for (final entry in _handles) {
      await (entry.object as Session).dispose();
    }
    setState(() {
      _log += 'Disposed all ${_handles.length} handles\n';
      _handles.clear();
    });
  }

  @override
  void dispose() {
    for (final entry in _handles) {
      (entry.object as Session).dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text('Native Handle Lifecycle',
                        style: theme.textTheme.titleSmall)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_handles.length} live',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'NativeObject pattern: create() allocates a native handle, '
              'dispose() releases it. Each handle is independent.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (_handles.isNotEmpty)
              ...List.generate(_handles.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.memory,
                          size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${_handles[i].type} #${i + 1}')),
                      TextButton(
                        onPressed: () => _useAndDispose(i),
                        child: const Text('Use & Dispose'),
                      ),
                    ],
                  ),
                );
              }),
            if (_log.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                constraints: const BoxConstraints(maxHeight: 150),
                child: SingleChildScrollView(
                  reverse: true,
                  child: Text(
                    _log.trimRight(),
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _createSession,
                    icon: const Icon(Icons.add),
                    label: const Text('Create'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _handles.isNotEmpty ? _disposeAll : null,
                    icon: const Icon(Icons.delete_sweep),
                    label: const Text('Dispose All'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HandleEntry {
  final String type;
  final dynamic object;
  _HandleEntry(this.type, this.object);
}

// 3c. Error handling
class _ErrorHandlingDemo extends StatefulWidget {
  const _ErrorHandlingDemo();
  @override
  State<_ErrorHandlingDemo> createState() => _ErrorHandlingDemoState();
}

class _ErrorHandlingDemoState extends State<_ErrorHandlingDemo> {
  String _result = 'Tap to trigger different native errors.';
  bool _loading = false;

  Future<void> _triggerMissingPlugin() async {
    setState(() => _loading = true);
    try {
      await ErrorHandler.guard(() async {
        final channel = AutoInteropChannel('nonexistent_service');
        await channel.invoke<String>('missingMethod');
      });
    } on AutoInteropException catch (e) {
      setState(() {
        _result = 'AutoInteropException caught:\n'
            '  code: ${e.code}\n'
            '  message: ${e.message}\n'
            '  details: ${e.details}';
      });
    } catch (e) {
      setState(() => _result = 'Caught: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _triggerInvalidHandle() async {
    setState(() => _loading = true);
    try {
      // Use a fake handle that doesn't exist on the native side
      final fakeRequest = DataRequest.fromHandle('invalid_handle_999');
      await fakeRequest.response();
    } on AutoInteropException catch (e) {
      setState(() {
        _result = 'Invalid handle error:\n'
            '  code: ${e.code}\n'
            '  message: ${e.message}';
      });
    } catch (e) {
      setState(() => _result = 'Caught: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _triggerBadUrl() async {
    setState(() => _loading = true);
    try {
      final session = await Session.create();
      final req = await session.request(
        'not-a-valid-url',
        HTTPMethod.get,
        null,
      );
      final resp = await req.response();
      setState(() =>
          _result = 'Got response: ${resp.statusCode} (unexpected success)');
      await req.dispose();
      await session.dispose();
    } on AutoInteropException catch (e) {
      setState(() {
        _result = 'Bad URL error:\n'
            '  code: ${e.code}\n'
            '  message: ${e.message}';
      });
    } catch (e) {
      setState(() => _result = 'Caught: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Error Handling', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'ErrorHandler.guard() converts PlatformException to '
              'AutoInteropException with structured code/message/details.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _ResultBox(text: _result, loading: _loading),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: _loading ? null : _triggerMissingPlugin,
                  child: const Text('Missing Plugin'),
                ),
                FilledButton.tonal(
                  onPressed: _loading ? null : _triggerInvalidHandle,
                  child: const Text('Invalid Handle'),
                ),
                FilledButton.tonal(
                  onPressed: _loading ? null : _triggerBadUrl,
                  child: const Text('Bad URL'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared UI components
// ═══════════════════════════════════════════════════════════════════════════════

class _DemoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String result;
  final bool loading;
  final VoidCallback onTap;
  final String buttonLabel;

  const _DemoCard({
    required this.title,
    required this.subtitle,
    required this.result,
    required this.loading,
    required this.onTap,
    required this.buttonLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(subtitle, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            _ResultBox(text: result, loading: loading),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: loading ? null : onTap,
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultBox extends StatelessWidget {
  final String text;
  final bool loading;
  const _ResultBox({required this.text, required this.loading});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: loading
          ? const Center(
              child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)))
          : Text(
              text,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontFamily: 'monospace', fontSize: 12),
            ),
    );
  }
}
