import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:async';

class SpectrogramPage extends StatefulWidget {
  final List<Float32List> stftResult;
  final double minDb;
  final double maxDb;

  const SpectrogramPage({
    super.key,
    required this.stftResult,
    this.minDb = -80.0,
    this.maxDb = 0.0,
  });

  @override
  State<SpectrogramPage> createState() => _SpectrogramPageState();
}

class _SpectrogramPageState extends State<SpectrogramPage> {
  late int frameCount;
  late int freqBins;
  late int displayBins;
  double? cursorX;
  double? cursorY;
  Future<ui.Image>? _futureImage;
  double currentMinDb = -80.0;
  int neighborRangeY = 5;
  int neighborRangeX = 5;
  double erosionStrength = 1.0;
  double screenHeight = 0;

  @override
  void initState() {
    super.initState();
    frameCount = widget.stftResult.length;
    freqBins = widget.stftResult[0].length;
    displayBins = ((10000 * 2 * freqBins) / 44100).floor();
    currentMinDb = widget.minDb;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    screenHeight = MediaQuery.of(context).size.height - kToolbarHeight - 40;
    _futureImage = _generateSpectrogramImage(screenHeight);
  }

  Future<ui.Image> _generateSpectrogramImage(double screenHeight) async {
    final height = screenHeight.toInt();
    final pixels = Uint8List(frameCount * height * 4);

    for (int t = 0; t < frameCount; t++) {
      for (int y = 0; y < height; y++) {
        final f = ((height - 1 - y) * displayBins / height).floor();
        if (f >= freqBins) continue;

        double centerMag = widget.stftResult[t][f];
        double sum = 0.0;
        int count = 0;

        for (int dt = -neighborRangeX; dt <= neighborRangeX; dt++) {
          for (int df = -neighborRangeY; df <= neighborRangeY; df++) {
            if (dt == 0 && df == 0) continue;
            int tIdx = t + dt;
            int fIdx = f + df;
            if (tIdx >= 0 && tIdx < frameCount && fIdx >= 0 && fIdx < freqBins) {
              sum += widget.stftResult[tIdx][fIdx];
              count++;
            }
          }
        }

        double avgNeighbor = count > 0 ? sum / count : 0.0;
        double mag = max(centerMag - erosionStrength * avgNeighbor, 0.0);

        double db = 20 * log(max(mag, 1e-10)) / ln10;
        double norm = ((db - currentMinDb) / (widget.maxDb - currentMinDb)).clamp(0.0, 1.0);

        final color = HSVColor.lerp(
          HSVColor.fromAHSV(1.0, 270, 1, 0.2),
          HSVColor.fromAHSV(1.0, 0, 1, 1),
          norm,
        )!.toColor();

        final pixelIndex = ((y * frameCount) + t) * 4;
        pixels[pixelIndex + 0] = color.red;
        pixels[pixelIndex + 1] = color.green;
        pixels[pixelIndex + 2] = color.blue;
        pixels[pixelIndex + 3] = color.alpha;
      }
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      frameCount,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  Widget _buildAxisLabels(double fullWidth, double height, double canvasWidth, double scaleY, double offsetY) {
    return Positioned.fill(
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(5, (i) {
                      double visualY = i * height / 4;
                      int pixelY = ((visualY - offsetY) / scaleY).round().clamp(0, height.toInt() - 1);
                      int bin = ((height - 1 - pixelY) * displayBins / height).floor();
                      int freq = bin * 44100 ~/ (2 * freqBins);
                      return Text("$freq Hz", style: const TextStyle(fontSize: 11));
                    }),
                  ),
                ),
                Expanded(
                  child: Container(),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (i) {
                double sec = (i * (frameCount / 6) * 512 / 44100);
                return Text("${sec.toStringAsFixed(1)}s", style: const TextStyle(fontSize: 10));
              }),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final canvasWidth = frameCount.toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spectrogram'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () async {
              double tempMinDb = currentMinDb;
              int tempRangeY = neighborRangeY;
              int tempRangeX = neighborRangeX;
              double tempStrength = erosionStrength;

              final result = await showDialog<Map<String, dynamic>>(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('顯示設定'),
                    content: StatefulBuilder(
                      builder: (context, setStateSB) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("Min dB"),
                          Slider(
                            min: -120,
                            max: 0,
                            value: tempMinDb,
                            divisions: 120,
                            label: tempMinDb.toStringAsFixed(1),
                            onChanged: (v) => setStateSB(() => tempMinDb = v),
                          ),
                          const SizedBox(height: 10),
                          Text("Y軸鄰近範圍：±$tempRangeY"),
                          Slider(
                            min: 0,
                            max: 20,
                            divisions: 20,
                            value: tempRangeY.toDouble(),
                            onChanged: (v) => setStateSB(() => tempRangeY = v.toInt()),
                          ),
                          const SizedBox(height: 10),
                          Text("X軸鄰近範圍：±$tempRangeX"),
                          Slider(
                            min: 0,
                            max: 20,
                            divisions: 20,
                            value: tempRangeX.toDouble(),
                            onChanged: (v) => setStateSB(() => tempRangeX = v.toInt()),
                          ),
                          const SizedBox(height: 10),
                          Text("腐蝕強度：${tempStrength.toStringAsFixed(1)}"),
                          Slider(
                            min: 0.0,
                            max: 3.0,
                            divisions: 30,
                            value: tempStrength,
                            onChanged: (v) => setStateSB(() => tempStrength = v),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, {
                          'minDb': tempMinDb,
                          'rangeY': tempRangeY,
                          'rangeX': tempRangeX,
                          'strength': tempStrength
                        }),
                        child: const Text('確定'),
                      )
                    ],
                  );
                },
              );
              if (result != null) {
                setState(() {
                  currentMinDb = result['minDb'];
                  neighborRangeY = result['rangeY'];
                  neighborRangeX = result['rangeX'];
                  erosionStrength = result['strength'];
                  _futureImage = _generateSpectrogramImage(screenHeight);
                });
              }
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final viewportHeight = constraints.maxHeight;
          final scaleY = screenHeight / viewportHeight;
          final offsetY = 0.0;

          return FutureBuilder<ui.Image>(
            future: _futureImage,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return GestureDetector(
                onTapDown: (details) {
                  setState(() {
                    cursorX = details.localPosition.dx;
                    cursorY = details.localPosition.dy;
                  });
                },
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 40, bottom: 20),
                      child: InteractiveViewer(
                        constrained: false,
                        maxScale: 10,
                        child: SizedBox(
                          width: canvasWidth,
                          height: screenHeight,
                          child: RawImage(image: snapshot.data!, fit: BoxFit.fill),
                        ),
                      ),
                    ),
                    if (cursorX != null)
                      Positioned(
                        left: cursorX! + 40,
                        top: 0,
                        bottom: 20,
                        child: Container(width: 2, color: Colors.red),
                      ),
                    if (cursorY != null)
                      Positioned(
                        left: 45,
                        top: cursorY!.clamp(0, viewportHeight - 20),
                        child: Builder(builder: (_) {
                          int visualY = cursorY!.round();
                          int pixelY = ((visualY - offsetY) / scaleY).round().clamp(0, screenHeight.toInt() - 1);
                          int bin = ((screenHeight - pixelY - 1) * displayBins / screenHeight).floor();
                          int freq = bin * 44100 ~/ (2 * freqBins);
                          return Text("$freq Hz", style: const TextStyle(color: Colors.white, fontSize: 12));
                        }),
                      ),
                    _buildAxisLabels(screenWidth, viewportHeight, canvasWidth, scaleY, offsetY),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
