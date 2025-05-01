package com.example.audio_analytic_app

import android.media.*
import android.util.Log
import java.io.File
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.io.ByteArrayOutputStream

object PcmDecoder {
    fun decodeToPCMStream(path: String, onChunk: (ByteArray) -> Unit, onComplete: (Int) -> Unit) {
        Thread {
            val extractor = MediaExtractor()
            extractor.setDataSource(path)
            var audioTrackIndex = -1
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME)
                if (mime?.startsWith("audio/") == true) {
                    audioTrackIndex = i
                    break
                }
            }
            if (audioTrackIndex < 0) throw IllegalArgumentException("找不到音軌")

            extractor.selectTrack(audioTrackIndex)
            val format = extractor.getTrackFormat(audioTrackIndex)
            val sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            val codec = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
            codec.configure(format, null, null, 0)
            codec.start()

            val bufferInfo = MediaCodec.BufferInfo()
            val TIMEOUT_US = 10000L
            val chunkSize = 2048 // 每次送 2048 bytes
            var totalBytes = 0

            var isEOS = false
            while (true) {
                if (!isEOS) {
                    val inIndex = codec.dequeueInputBuffer(TIMEOUT_US)
                    if (inIndex >= 0) {
                        val inputBuffer = codec.getInputBuffer(inIndex)!!
                        val size = extractor.readSampleData(inputBuffer, 0)
                        if (size < 0) {
                            codec.queueInputBuffer(inIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            isEOS = true
                        } else {
                            codec.queueInputBuffer(inIndex, 0, size, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }

                val outIndex = codec.dequeueOutputBuffer(bufferInfo, TIMEOUT_US)
                if (outIndex >= 0) {
                    val outBuffer = codec.getOutputBuffer(outIndex)!!
                    val pcmChunk = ByteArray(bufferInfo.size)
                    outBuffer.get(pcmChunk)
                    outBuffer.clear()

                    // 分段回傳
                    onChunk(pcmChunk)
                    totalBytes += pcmChunk.size

                    codec.releaseOutputBuffer(outIndex, false)

                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
                }
            }

            codec.stop()
            codec.release()
            extractor.release()

            // 回傳完成
            onComplete(sampleRate)
        }.start()
    }

    fun decodeToPCM(inputPath: String): Map<String, Any> {
        val extractor = MediaExtractor()
        extractor.setDataSource(inputPath)

        // 選擇音訊軌道
        var audioTrackIndex = -1
        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME)
            if (mime != null && mime.startsWith("audio/")) {
                audioTrackIndex = i
                break
            }
        }

        if (audioTrackIndex < 0) throw IllegalArgumentException("找不到音訊軌道")

        extractor.selectTrack(audioTrackIndex)
        val format = extractor.getTrackFormat(audioTrackIndex)
        val mime = format.getString(MediaFormat.KEY_MIME)!!
        val sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)

        val codec = MediaCodec.createDecoderByType(mime)
        codec.configure(format, null, null, 0)
        codec.start()

        val pcmOutput = ByteArrayOutputStream()
        val bufferInfo = MediaCodec.BufferInfo()

        var isEOS = false
        val TIMEOUT_US = 10000L

        while (true) {
            if (!isEOS) {
                val inputBufferIndex = codec.dequeueInputBuffer(TIMEOUT_US)
                if (inputBufferIndex >= 0) {
                    val inputBuffer = codec.getInputBuffer(inputBufferIndex)!!
                    val sampleSize = extractor.readSampleData(inputBuffer, 0)

                    if (sampleSize < 0) {
                        codec.queueInputBuffer(
                            inputBufferIndex, 0, 0, 0L,
                            MediaCodec.BUFFER_FLAG_END_OF_STREAM
                        )
                        isEOS = true
                    } else {
                        val presentationTimeUs = extractor.sampleTime
                        codec.queueInputBuffer(
                            inputBufferIndex, 0, sampleSize,
                            presentationTimeUs, 0
                        )
                        extractor.advance()
                    }
                }
            }

            val outputBufferIndex = codec.dequeueOutputBuffer(bufferInfo, TIMEOUT_US)
            if (outputBufferIndex >= 0) {
                val outputBuffer = codec.getOutputBuffer(outputBufferIndex)!!
                val pcmChunk = ByteArray(bufferInfo.size)
                outputBuffer.get(pcmChunk)
                outputBuffer.clear()
                pcmOutput.write(pcmChunk)
                codec.releaseOutputBuffer(outputBufferIndex, false)

                if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                    break
                }
            }
        }

        codec.stop()
        codec.release()
        extractor.release()

        val pcmData: ByteArray = pcmOutput.toByteArray();

        return mapOf(
            "pcm" to pcmData,
            "sampleRate" to sampleRate
        )
    }
}
