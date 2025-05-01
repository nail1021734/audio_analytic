package com.example.audio_analytic_app

import org.jtransforms.fft.DoubleFFT_1D
import kotlin.math.*
import java.util.Arrays
import android.os.Handler
import android.os.Looper

object StftProcessor {
    // fun computeStftInChunks(
    //     pcm: FloatArray,
    //     sampleRate: Int,
    //     windowSize: Int,
    //     overlapRatio: Double,
    //     windowType: String,
    //     chunkSize: Int = 2000,
    //     onChunk: (List<FloatArray>) -> Unit,
    //     onComplete: () -> Unit
    // ) {
    //     Thread {
    //         val hopSize = (windowSize * (1.0 - overlapRatio)).toInt()
    //         val totalFrames = ((pcm.size - windowSize) / hopSize).coerceAtLeast(0)
    //         val fft = org.jtransforms.fft.DoubleFFT_1D(windowSize.toLong())
    //         val window = generateWindow(windowSize, windowType)

    //         val buffer = DoubleArray(windowSize * 2)
    //         val result = mutableListOf<FloatArray>()

    //         for (i in 0 until totalFrames) {
    //             val start = i * hopSize
    //             buffer.fill(0.0)

    //             for (j in 0 until windowSize) {
    //                 val sample = if (start + j < pcm.size) pcm[start + j].toDouble() else 0.0
    //                 buffer[2 * j] = sample * window[j]
    //                 buffer[2 * j + 1] = 0.0
    //             }

    //             fft.complexForward(buffer)

    //             val magnitudes = FloatArray(windowSize / 2) { k ->
    //                 val re = buffer[2 * k]
    //                 val im = buffer[2 * k + 1]
    //                 sqrt(re * re + im * im).toFloat()
    //             }

    //             result.add(magnitudes)

    //             // 每處理 chunkSize 幀就回傳一次
    //             if (result.size >= chunkSize) {
    //                 val chunk = ArrayList(result)
    //                 result.clear()
    //                 Handler(Looper.getMainLooper()).post {
    //                     stftEventSink?.success(onChunk(chunk))
    //                 }
    //             }
    //         }

    //         // 傳回最後未滿 chunk 的資料
    //         if (result.isNotEmpty()) {
    //             Handler(Looper.getMainLooper()).post {
    //                 stftEventSink?.success(onChunk(result))
    //             }
    //         }

    //         Handler(Looper.getMainLooper()).post {
    //             stftEventSink?.success(onComplete())
    //         }
    //     }.start()
    // }

    fun stft(
        pcm: FloatArray,
        sampleRate: Int,
        windowSize: Int,
        overlapRatio: Double,
        windowType: String,
        chunkSize: Int = 1024
    ): List<List<Double>> {
        val hopSize = (windowSize * (1.0 - overlapRatio)).toInt()
        val totalFrames = ((pcm.size - windowSize) / hopSize).coerceAtLeast(0)
        val fft = DoubleFFT_1D(windowSize.toLong())
        val window = generateWindow(windowSize, windowType)

        val result = mutableListOf<List<Double>>()
        var frameIndex = 0
        val buffer = DoubleArray(windowSize * 2)

        while (frameIndex < totalFrames) {
            val endFrame = (frameIndex + chunkSize).coerceAtMost(totalFrames)

            for (i in frameIndex until endFrame) {
                val start = i * hopSize
                Arrays.fill(buffer, 0.0)

                for (j in 0 until windowSize) {
                    val s = if (start + j < pcm.size) pcm[start + j].toDouble() else 0.0
                    buffer[2 * j] = s * window[j]
                    buffer[2 * j + 1] = 0.0
                }

                fft.complexForward(buffer)

                val mag = MutableList(windowSize / 2) { k ->
                    val re = buffer[2 * k]
                    val im = buffer[2 * k + 1]
                    sqrt(re * re + im * im)
                }

                result.add(mag)
            }

            frameIndex = endFrame
        }

        return result
    }

    fun computeSingleStft(pcm: FloatArray, windowSize: Int): FloatArray {
        val fft = DoubleFFT_1D(windowSize.toLong())
        val buffer = DoubleArray(windowSize * 2) // real + imag interleaved

        // Apply window (uniform, or you can change this to hamming/hanning)
        for (i in 0 until windowSize) {
            buffer[2 * i] = if (i < pcm.size) pcm[i].toDouble() else 0.0
            buffer[2 * i + 1] = 0.0
        }

        fft.complexForward(buffer)

        val magnitudes = FloatArray(windowSize / 2)
        for (k in 0 until windowSize / 2) {
            val re = buffer[2 * k]
            val im = buffer[2 * k + 1]
            magnitudes[k] = sqrt(re * re + im * im).toFloat()
        }

        return magnitudes
    }

    private fun generateWindow(size: Int, type: String): DoubleArray {
        return when (type.lowercase()) {
            "hanning" -> DoubleArray(size) { i -> 0.5 - 0.5 * cos(2.0 * PI * i / size) }
            "hamming" -> DoubleArray(size) { i -> 0.54 - 0.46 * cos(2.0 * PI * i / size) }
            else -> DoubleArray(size) { 1.0 }
        }
    }
}
