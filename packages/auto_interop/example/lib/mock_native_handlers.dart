/// Mock implementations of generated binding interfaces.
///
/// In a real app, the generated classes (e.g., `PlatformInfo`, `SensorStream`)
/// communicate with native code via platform channels. These mock
/// implementations simulate the native responses entirely in Dart.
///
/// This demonstrates the testability pattern: generated bindings produce
/// abstract interfaces, so you can inject real or mock implementations.
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:auto_interop/auto_interop.dart';

import 'generated/platform_info.dart';
import 'generated/sensor_stream.dart';
import 'generated/image_processor.dart';
import 'generated/file_downloader.dart';

// ---------------------------------------------------------------------------
// 1. Mock PlatformInfo — simulates device info queries
// ---------------------------------------------------------------------------

class MockPlatformInfo implements PlatformInfoInterface {
  @override
  Future<int> getBatteryLevel() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return 73;
  }

  @override
  Future<BatteryState> getBatteryState() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return BatteryState.charging;
  }

  @override
  Future<DeviceInfo> getDeviceInfo() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return DeviceInfo(
      model: 'iPhone 16 Pro',
      platform: 'iOS',
      osVersion: '18.2',
      availableMemoryMb: 3072,
    );
  }

  @override
  Future<bool> isNetworkAvailable() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return true;
  }
}

// ---------------------------------------------------------------------------
// 2. Mock SensorStream — simulates accelerometer data
// ---------------------------------------------------------------------------

class MockSensorStream implements SensorStreamInterface {
  @override
  Stream<AccelerometerEvent> accelerometerEvents({int samplingRate = 60}) {
    final random = Random();
    final interval = Duration(milliseconds: 1000 ~/ samplingRate);
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
// 3. Mock ImageProcessor — simulates opaque native object handles
// ---------------------------------------------------------------------------

class MockImageProcessor implements ImageProcessorInterface {
  int _nextHandle = 1;

  @override
  Future<NativeObject<ImageProcessor>> loadImage(Uint8List data) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return NativeObject<ImageProcessor>(
      handle: 'h_${_nextHandle++}',
      channelName: 'image_processor',
    );
  }

  @override
  Future<NativeObject<ImageProcessor>> applyFilter(
    NativeObject<ImageProcessor> image,
    ImageFilter filter,
    double intensity,
  ) async {
    image.ensureNotDisposed();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return NativeObject<ImageProcessor>(
      handle: 'h_${_nextHandle++}',
      channelName: 'image_processor',
    );
  }

  @override
  Future<ImageMetadata> getMetadata(NativeObject<ImageProcessor> image) async {
    image.ensureNotDisposed();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return ImageMetadata(
      width: 1920,
      height: 1080,
      format: 'PNG',
      sizeBytes: 8294400,
    );
  }

  @override
  Future<Uint8List> exportPng(NativeObject<ImageProcessor> image) async {
    image.ensureNotDisposed();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return Uint8List.fromList(List.filled(256, 0xAB));
  }
}

// ---------------------------------------------------------------------------
// 4. Mock FileDownloader — simulates download with progress callbacks
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
