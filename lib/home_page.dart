import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'Setting.dart';
import 'audio.dart';
import 'package:file_picker/file_picker.dart';
import 'spectrogram.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? audio_filePath;
  bool isLoading = false;
  // double decodeProgress = 0.0;
  double mindb = -80.0;
  final audioProcessor = AudioProcessor();

  // The function to pick file in system.
  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'wav'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        audio_filePath = result.files.single.path!;
      });
    }
  }

  // The function to load the audio file and decode it.
  Future<void> _loadAudio() async {
    if (audio_filePath == null) return;

    setState(() {
      isLoading = true;
    });

    await audioProcessor.startStreamingDecode(audio_filePath!);
    print("🎵 音訊檔案讀取完成，檔案大小：${audioProcessor.pcmBytes!.lengthInBytes} bytes");
    await audioProcessor.computeStftChunked(
      windowSize: 8192,
      overlapRatio: 0.25,
    );
    print("🎵 STFT 計算完成，共 ${audioProcessor.stftResult.length} 幀");
    // await audioProcessor.computeStft(
    //   windowSize: 8192,
    //   overlapRatio: 0.5,
    //   windowType: 'hamming',
    // );
    // print("🎵 STFT 計算完成，共 ${stftResult!.length} 幀");
    // TODO: 可切換頁面顯示 ChartWidget（如果已實作）
    setState(() {
      isLoading = false;
    });
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SpectrogramPage(
          stftResult: audioProcessor.stftResult,
          minDb: -80,
          maxDb: 0,
        ),
      ),
    );
  }

  // If stftResult is not null, draw the spectrogram.
  // push the spectrogram data to the chart widget and switch to that widget.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Audio Visualizer'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () async {
              final result = await showDialog<double>(
                context: context,
                builder: (context) => SettingDialog(mindb: mindb),
              );
              setState(() {
                mindb = result!;
              });
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _pickAudioFile,
                icon: const Icon(Icons.folder),
                label: const Text('選擇音訊檔案'),
              ),
              const SizedBox(height: 12),
              if (audio_filePath != null)
                Text(
                  '已選擇檔案：\n${audio_filePath!.split('/').last}',
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _loadAudio,
                icon: const Icon(Icons.graphic_eq),
                label: const Text('開始解碼並分析 STFT'),
              ),
              const SizedBox(height: 24),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Text(
                    '🔄 音訊讀取與分析中...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
