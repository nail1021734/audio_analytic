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
  late Future<ui.Image> _futureImage;
  late int frameCount;
  late int freqBins;
  double? cursorX;

  @override
  void initState() {
    super.initState();
    frameCount = widget.stftResult.length;
    freqBins = widget.stftResult[0].length;
    _futureImage = _generateSpectrogramImage();
  }

  Future<ui.Image> _generateSpectrogramImage() async {
    final pixels = Uint8List(frameCount * freqBins * 4);

    for (int t = 0; t < frameCount; t++) {
      final frame = widget.stftResult[t];
      for (int f = 0; f < freqBins; f++) {
        double mag = frame[f];
        double db = 20 * log(max(mag, 1e-10)) / ln10;
        double norm = ((db - widget.minDb) / (widget.maxDb - widget.minDb)).clamp(0.0, 1.0);

        final color = HSVColor.lerp(
          HSVColor.fromAHSV(1.0, 270, 1, 0.2),
          HSVColor.fromAHSV(1.0, 0, 1, 1),
          norm,
        )!.toColor();

        final int flippedF = freqBins - 1 - f;
        final int pixelIndex = ((flippedF * frameCount) + t) * 4;
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
      freqBins,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  Widget _buildAxisLabels(double width, double height) {
    return Positioned.fill(
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(5, (i) {
                      int freq = ((4 - i) * (freqBins ~/ 5)) * 44100 ~/ (2 * freqBins);
                      return Text("$freq Hz", style: const TextStyle(fontSize: 10));
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
    final double aspectRatio = frameCount / freqBins;
    final imageDisplayHeight = screenWidth / aspectRatio;

    return Scaffold(
      appBar: AppBar(title: const Text('Spectrogram')),
      body: FutureBuilder<ui.Image>(
        future: _futureImage,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return GestureDetector(
            onTapDown: (details) {
              setState(() {
                cursorX = details.localPosition.dx;
              });
            },
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 40, bottom: 20),
                  child: InteractiveViewer(
                    maxScale: 10,
                    child: SizedBox(
                      width: screenWidth,
                      height: imageDisplayHeight,
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
                _buildAxisLabels(screenWidth, imageDisplayHeight),
              ],
            ),
          );
        },
      ),
    );
  }
}
