import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class AudioProcessor {
  final MethodChannel _nativeChannel = const MethodChannel('com.example.audio_analytic_app/audio');

  final AudioPlayer _player = AudioPlayer();

  String? audioPath;
  Uint8List? pcmBytes;
  List<Float32List> stftResult = [];
  int sampleRate = 44100; // default, updated on load
  List<int> pcmBuffer = [];


  /// Set path to audio and load it
  /// old function
  // Future<void> loadAudio(String path) async {
  //   audioPath = path;
  //   final result = await _nativeChannel.invokeMethod<Map>('decodeToPCM', {'path': path});
  //   if (result != null) {
  //     pcmBytes = result['pcm'];
  //     sampleRate = result['sampleRate'];
  //     print("🎵 音訊檔案讀取完成，檔案大小：${pcmBytes!.lengthInBytes} bytes");
  //   } else {
  //     throw Exception('Failed to load audio.');
  //   }
  // }

  EventChannel? _pcmStream = EventChannel("com.example.audio_analytic_app/pcm_stream");

  static const _stftStreamChannel = EventChannel("com.example.audio_analytic_app/stft_stream");

  Future<void> startStreamingDecode(String path) async {
    pcmBuffer.clear();
    final completer = Completer<void>();

    _pcmStream ??= const EventChannel("com.example.audio_analytic_app/pcm_stream");

    _pcmStream!.receiveBroadcastStream().listen(
      (chunk) {
        pcmBuffer.addAll(chunk.cast<int>());
      },
      onDone: () {
        pcmBytes = Uint8List.fromList(pcmBuffer);
        completer.complete(); // ✅ 在這裡完成
      },
      onError: (e) => completer.completeError(e),
      cancelOnError: true,
    );

    await _nativeChannel.invokeMethod("startDecodeStream", {"path": path});
    return completer.future; // ✅ 這才是正確的 Future
  }

  /// Start audio playback
  Future<void> play() async {
    if (audioPath == null) throw Exception("Audio not loaded");
    await _player.setFilePath(audioPath!);
    await _player.play();
  }

  /// Stop audio playback
  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> computeStftChunked({
    required int windowSize,
    required double overlapRatio,
  }) async {
    if (pcmBytes == null) throw Exception("PCM data not available");

    stftResult.clear();

    final samples = Int16List.view(pcmBytes!.buffer).map((s) => s / 32768.0).toList();
    final hopSize = (windowSize * (1.0 - overlapRatio)).toInt();
    final totalFrames = ((samples.length - windowSize) / hopSize).floor();

    for (int i = 0; i < totalFrames; i++) {
      print("Processing frame $i / $totalFrames");
      final start = i * hopSize;
      final frame = samples.skip(start).take(windowSize).toList();
      final result = await _nativeChannel.invokeMethod<List<dynamic>>("StftChunk", {
        'chunk': frame,
        'windowSize': windowSize,
      });

      if (result != null) {
        final magnitude = Float32List.fromList(result.map((e) => (e as num).toDouble()).toList());
        stftResult.add(magnitude);
      }
    }
  }

  /// Perform STFT (call your Dart implementation or native method)
  // Future computeStft({
  //   required int windowSize,
  //   required double overlapRatio,
  //   required String windowType,
  // }) async {
  //   if (pcmBytes == null) throw Exception("PCM data not available");

  //   final result = await _nativeChannel.invokeMethod<List<dynamic>>('Stft', {
  //     'pcm': pcmBytes,
  //     'sampleRate': sampleRate,
  //     'windowSize': windowSize,
  //     'overlapRatio': overlapRatio,
  //     'windowType': windowType,
  //   });

  //   final rawResult = result as List;

  //   stftResult = rawResult.map<Float32List>((row) =>
  //     Float32List.fromList(List<double>.from((row as List).map((e) => e.toDouble())))
  //   ).toList();

  //   // if (result != null) {
  //   //   stftResult = result.map<Float32List>((row) =>
  //   //     Float32List.fromList((row as List).map((e) => e.toDouble())).toList()
  //   //   ).toList();
  //   // }
  // }

  Future<void> computeStft({
    required int windowSize,
    required double overlapRatio,
    required String windowType,
  }) async {
    if (pcmBytes == null) throw Exception("PCM data not available");

    stftResult = []; // 清空前次結果
    final completer = Completer<void>();

    _stftStreamChannel.receiveBroadcastStream().listen(
      (dynamic chunkData) {
        final List<Float32List> chunk = (chunkData as List).map<Float32List>((row) {
          final List<double> values = List<double>.from(row);
          return Float32List.fromList(values);
        }).toList();

        stftResult!.addAll(chunk); // 實際收集分段資料
      },
      onDone: () {
        print("✅ STFT 完成，總幀數：${stftResult!.length}");
        completer.complete();
      },
      onError: (e) => completer.completeError(e),
      cancelOnError: true,
    );

    await _nativeChannel.invokeMethod("Stft", {
      'pcm': pcmBytes,
      'sampleRate': sampleRate,
      'windowSize': windowSize,
      'overlapRatio': overlapRatio,
      'windowType': windowType,
    });

    return completer.future;
  }

  void dispose() {
    _player.dispose();
  }
}
