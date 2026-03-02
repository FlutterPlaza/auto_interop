/// Mock implementations of generated binding interfaces.
///
/// In a real app, the generated classes (e.g., `SensorStream`, `FileDownloader`)
/// communicate with native code via platform channels. These mock
/// implementations simulate the native responses entirely in Dart.
///
/// This demonstrates the testability pattern: generated bindings produce
/// abstract interfaces, so you can inject real or mock implementations.
import 'dart:async';
import 'dart:math';

import 'generated/sensor_stream.dart';
import 'generated/file_downloader.dart';

// ---------------------------------------------------------------------------
// 1. Mock SensorStream — simulates accelerometer data
// ---------------------------------------------------------------------------

class MockSensorStream implements SensorStreamInterface {
  @override
  Stream<AccelerometerEvent> accelerometerEvents({int? samplingRate}) {
    final rate = samplingRate ?? 60;
    final random = Random();
    final interval = Duration(milliseconds: 1000 ~/ rate);
    return Stream.periodic(interval, (_) {
      return AccelerometerEvent(
        x: (random.nextDouble() - 0.5) * 2.0,
        y: (random.nextDouble() - 0.5) * 2.0,
        z: 9.8 + (random.nextDouble() - 0.5) * 0.5,
        timestamp: DateTime.now(),
      );
    });
  }

  @override
  Future<void> stopAll() async {}
}

// ---------------------------------------------------------------------------
// 2. Mock FileDownloader — simulates download with progress callbacks
// ---------------------------------------------------------------------------

class MockFileDownloader implements FileDownloaderInterface {
  @override
  Future<void> download({
    required String url,
    required String destination,
    required void Function(DownloadProgress) onProgress,
    required void Function(DownloadStatus status, String? error) onComplete,
  }) async {
    const totalBytes = 10485760; // 10 MB
    const steps = 5;
    const chunkSize = totalBytes ~/ steps;

    for (var i = 1; i <= steps; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final bytesReceived = chunkSize * i;
      onProgress(DownloadProgress(
        bytesReceived: bytesReceived,
        totalBytes: totalBytes,
        progress: bytesReceived / totalBytes,
      ));
    }

    await Future<void>.delayed(const Duration(milliseconds: 300));
    onComplete(DownloadStatus.completed, null);
  }

  @override
  Future<void> cancelAll() async {}
}
