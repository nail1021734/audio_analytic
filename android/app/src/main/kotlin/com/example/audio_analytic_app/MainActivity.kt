package com.example.audio_analytic_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import com.example.audio_analytic_app.PcmDecoder
import com.example.audio_analytic_app.StftProcessor
import java.nio.ByteBuffer
import java.nio.ByteOrder
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.audio_analytic_app/audio"
    private val EVENT_CHANNEL = "com.example.audio_analytic_app/pcm_stream"
    private val STFT_EVENT_CHANNEL = "com.example.audio_analytic_app/stft_stream"
    private var pcmEventSink: EventChannel.EventSink? = null
    private var stftEventSink: EventChannel.EventSink? = null

    fun byteArrayToFloatArray(bytes: ByteArray): FloatArray {
        val buffer = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        val floats = FloatArray(bytes.size / 2)
        println("bytes.size: ${bytes.size}")
        println("floats.size: ${floats.size}")
        for (i in floats.indices) {
            floats[i] = buffer.short.toFloat() / Short.MAX_VALUE
        }
        return floats
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    pcmEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    pcmEventSink = null
                }
            })
        
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, STFT_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    stftEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    stftEventSink = null
                }
            })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            when (call.method) {
                "startDecodeStream" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("MISSING_PATH", "Path is null", null)
                        return@setMethodCallHandler
                    }

                    try {
                        PcmDecoder.decodeToPCMStream(
                            path,
                            onChunk = { chunk ->
                                runOnUiThread {
                                    pcmEventSink?.success(chunk) // ✅ 在 UI Thread 執行
                                }
                            },
                            onComplete = { sampleRate ->
                                runOnUiThread {
                                    pcmEventSink?.endOfStream()
                                    result.success(sampleRate)
                                }
                            }
                        )
                        // val decodeResult = PcmDecoder.decodeToPCM(path)
                        // result.success(decodeResult) // 傳 map 給 Flutter
                    } catch (e: Exception) {
                        result.error("DECODE_FAILED", e.message, e.stackTraceToString())
                    }
                }
                "StftChunk" -> {
                    val chunk = call.argument<List<Double>>("chunk") ?: run {
                        result.error("MISSING_CHUNK", "STFT chunk is null", null)
                        return@setMethodCallHandler
                    }
                    val windowSize = call.argument<Int>("windowSize") ?: 1024

                    val floatChunk = chunk.map { it.toFloat() }.toFloatArray()
                    val magnitudes = StftProcessor.computeSingleStft(floatChunk, windowSize)
                    result.success(magnitudes.toList())
                }

                "Stft" -> {
                    val pcmBytes = call.argument<ByteArray>("pcm") ?: run {
                        result.error("MISSING_PCM", "PCM data is null", null)
                        return@setMethodCallHandler
                    }
                    val sampleRate = call.argument<Int>("sampleRate")!!
                    val windowSize = call.argument<Int>("windowSize")!!
                    val overlapRatio = call.argument<Double>("overlapRatio")!!
                    val windowType = call.argument<String>("windowType")!!

                    val pcmFloats = byteArrayToFloatArray(pcmBytes)
                    // val stft = StftProcessor.stft(
                    //     pcmFloats,
                    //     sampleRate,
                    //     windowSize,
                    //     overlapRatio,
                    //     windowType
                    // )

                    // result.success(stft)
                    
                    // StftProcessor.computeStftInChunks(
                    //     pcmFloats,
                    //     sampleRate,
                    //     windowSize,
                    //     overlapRatio,
                    //     windowType,
                    //     chunkSize = 2000,
                    //     onChunk = { chunk ->
                    //         runOnUiThread {
                    //             stftEventSink?.success(chunk.map { it.toList() })
                    //         }
                    //     },
                    //     onComplete = {
                    //         runOnUiThread {
                    //             stftEventSink?.endOfStream()
                    //             result.success("done")
                    //         }
                    //     }
                    // )
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
