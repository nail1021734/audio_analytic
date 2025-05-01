import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:math';

class SpectrogramPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final int frameCount = stftResult.length;
    final int freqBins = stftResult.isNotEmpty ? stftResult[0].length : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Spectrogram')),
      body: InteractiveViewer(
        maxScale: 10.0,
        child: CustomPaint(
          size: Size(frameCount.toDouble(), freqBins.toDouble()),
          painter: SpectrogramPainter(stftResult, minDb, maxDb),
        ),
      ),
    );
  }
}

class SpectrogramPainter extends CustomPainter {
  final List<Float32List> stftResult;
  final double minDb;
  final double maxDb;

  SpectrogramPainter(this.stftResult, this.minDb, this.maxDb);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final int frameCount = stftResult.length;
    final int freqBins = stftResult.isNotEmpty ? stftResult[0].length : 0;

    final double cellWidth = size.width / frameCount;
    final double cellHeight = size.height / freqBins;

    int hop_step = 1000;
    int count = 2;
    for (int t = 0; t < frameCount; t+=hop_step) {
      final row = stftResult[t];
      for (int f = 0; f < freqBins; f+=count) {
        double mag = row[f];
        double db = 20 * log(max(mag, 1e-10)) / ln10; // 轉為 dB
        double norm = ((db - minDb) / (maxDb - minDb)).clamp(0.0, 1.0);
        paint.color = HSVColor.lerp(
          HSVColor.fromAHSV(1.0, 270, 1, 0.2),
          HSVColor.fromAHSV(1.0, 0, 1, 1),
          norm,
        )!.toColor();

        canvas.drawRect(
          Rect.fromLTWH(t * cellWidth, size.height - (f + 1) * cellHeight, cellWidth, cellHeight),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
