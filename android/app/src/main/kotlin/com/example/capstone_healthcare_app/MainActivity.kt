package com.example.capstone_healthcare_app

import android.media.MediaRecorder
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import com.example.capstone_healthcare_app.native.CalibrationViewFactory
import com.example.capstone_healthcare_app.native.SquatViewFactory
import com.example.capstone_healthcare_app.native.HeelRaiseViewFactory

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.example.capstone_healthcare_app/heel_raise"
    private var mediaRecorder: MediaRecorder? = null
    private var outputFilePath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // MethodChannel 등록
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL
        ).setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            when (call.method) {
                "startRecording" -> {
                    val path = call.argument<String>("outputPath")!!
                    startRecordingNative(path)
                    result.success(null)
                }
                "stopRecording" -> {
                    stopRecordingNative()
                    result.success(null)
                }
                "cancel" -> {
                    cancelRecordingNative()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // 기존 플랫폼뷰 팩토리 등록
        flutterEngine.platformViewsController.registry.apply {
            registerViewFactory(
                "NativeCalibrationView",
                CalibrationViewFactory(
                    flutterEngine.dartExecutor.binaryMessenger,
                    this@MainActivity
                )
            )
            registerViewFactory(
                "NativeHeelRaiseView",
                HeelRaiseViewFactory(
                    flutterEngine.dartExecutor.binaryMessenger,
                    this@MainActivity
                )
            )
            registerViewFactory(
                "NativeSquatView",
                SquatViewFactory(
                    flutterEngine.dartExecutor.binaryMessenger,
                    this@MainActivity
                )
            )
        }
    }

    private fun startRecordingNative(path: String) {
        // 기존 녹화 중이면 해제
        mediaRecorder?.release()
        mediaRecorder = MediaRecorder().apply {
            setAudioSource(MediaRecorder.AudioSource.MIC)
            setVideoSource(MediaRecorder.VideoSource.SURFACE)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setOutputFile(path)
            setVideoEncoder(MediaRecorder.VideoEncoder.H264)
            setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            prepare()
            start()
        }
        outputFilePath = path
    }

    private fun stopRecordingNative() {
        mediaRecorder?.apply {
            try {
                stop()
            } catch (_: Exception) {
                // stop 오류 무시
            }
            release()
        }
        mediaRecorder = null
    }

    private fun cancelRecordingNative() {
        // 녹화 취소 시 사용자가 제공한 파일 삭제 로직 등
        outputFilePath?.let {
            try { file(it).delete() } catch (_: Exception) {}
        }
        mediaRecorder?.release()
        mediaRecorder = null
    }
}
