package com.example.capstone_healthcare_app.native

import android.Manifest
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.util.Size
import android.view.View
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.pose.Pose
import com.google.mlkit.vision.pose.PoseDetection
import com.google.mlkit.vision.pose.PoseDetector
import com.google.mlkit.vision.pose.PoseLandmark
import com.google.mlkit.vision.pose.defaults.PoseDetectorOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.util.Timer
import java.util.TimerTask
import java.util.concurrent.Executors

class NativeCalibrationView(
    private val activity: FlutterActivity,
    private val methodChannel: MethodChannel,
    private val eventChannel: EventChannel
) : PlatformView, ImageAnalysis.Analyzer {

    private val cameraExecutor = Executors.newSingleThreadExecutor()
    private val cameraProviderFuture = ProcessCameraProvider.getInstance(activity)
    private lateinit var cameraProvider: ProcessCameraProvider
    private var lensFacing: Int = CameraSelector.LENS_FACING_BACK
    private lateinit var poseDetector: PoseDetector
    private val calibrationPoses = mutableListOf<Pose>()
    private var calibrationTimer: Timer? = null
    private val previewView = PreviewView(activity).apply {
        implementationMode = PreviewView.ImplementationMode.PERFORMANCE
    }
    private var eventSink: EventChannel.EventSink? = null
    private var isProcessing = false

    init {
        cameraProviderFuture.addListener({
            try {
                cameraProvider = cameraProviderFuture.get()
                bindCameraUseCases()
            } catch (e: Exception) {
                Log.e("Calibration", "카메라 초기화 실패", e)
                sendError("CAMERA_INIT_FAILED", e.message)
            }
        }, ContextCompat.getMainExecutor(activity))

        // 포즈 감지기 초기화
        val options = PoseDetectorOptions.Builder()
            .setDetectorMode(PoseDetectorOptions.STREAM_MODE)
            .build()
        poseDetector = PoseDetection.getClient(options)

        // 이벤트 채널 설정
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                Log.d("Calibration", "이벤트 채널 연결됨")
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
                Log.d("Calibration", "이벤트 채널 연결 해제")
            }
        })

        // 메서드 채널 설정
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "switchCamera" -> {
                    switchCamera()
                    result.success(null)
                }
                "startCalibration" -> {
                    calibrationPoses.clear()
                    startCalibrationTimer()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    //카메라 바인딩
    private fun bindCameraUseCases() {
        val cameraSelector = CameraSelector.Builder()
            .requireLensFacing(lensFacing)
            .build()

        val preview = Preview.Builder()
            .setTargetRotation(previewView.display.rotation)
            .build()
            .also { it.setSurfaceProvider(previewView.surfaceProvider) }

        val imageAnalysis = ImageAnalysis.Builder()
            .setTargetResolution(Size(640, 480))
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .build()
            .also { it.setAnalyzer(cameraExecutor, this) }

        try {
            cameraProvider.unbindAll()
            cameraProvider.bindToLifecycle(
                activity,
                cameraSelector,
                preview,
                imageAnalysis
            )
        } catch (e: Exception) {
            Log.e("Calibration", "바인딩 실패: ${e.message}")
            sendError("BINDING_FAILED", e.message)
        }
    }

    //카메라 전환
    fun switchCamera() {
        lensFacing = if (lensFacing == CameraSelector.LENS_FACING_BACK)
            CameraSelector.LENS_FACING_FRONT
        else
            CameraSelector.LENS_FACING_BACK

        activity.runOnUiThread {
            try {
                cameraProvider.unbindAll()
                bindCameraUseCases()
                Log.d("Calibration", "카메라 전환 성공: ${if (lensFacing == CameraSelector.LENS_FACING_BACK) "후면" else "전면"}")
            } catch (e: Exception) {
                Log.e("Calibration", "카메라 전환 실패", e)
                sendError("SWITCH_FAILED", e.message)
            }
        }
    }

    override fun analyze(imageProxy: ImageProxy) {
        if (eventSink == null || isProcessing) {
            imageProxy.close()
            return
        }

        isProcessing = true
        val mediaImage = imageProxy.image
        if (mediaImage != null) {
            val image = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)
            poseDetector.process(image)
                .addOnSuccessListener { pose ->
                    handlePose(pose)
                    isProcessing = false
                    imageProxy.close()
                }
                .addOnFailureListener { e ->
                    Log.e("Calibration", "포즈 감지 실패", e)
                    isProcessing = false
                    imageProxy.close()
                }
        } else {
            imageProxy.close()
            isProcessing = false
        }
    }

    private fun handlePose(pose: Pose) {
        if (isHighConfidencePose(pose)) {
            calibrationPoses.add(pose)
            val progress = calibrationPoses.size.toDouble() / 30
            sendEvent(mapOf("type" to "progress", "value" to progress))
        }
    }

    private fun isHighConfidencePose(pose: Pose): Boolean {
        val minConfidence = 0.3f
        val requiredLandmarks = listOf(
            PoseLandmark.LEFT_SHOULDER,
            PoseLandmark.RIGHT_SHOULDER,
            PoseLandmark.LEFT_HIP,
            PoseLandmark.RIGHT_HIP
        )
        return requiredLandmarks.all {
            pose.getPoseLandmark(it)?.inFrameLikelihood ?: 0f >= minConfidence
        }
    }

    private fun startCalibrationTimer() {
        calibrationTimer?.cancel()
        calibrationTimer = Timer()
        calibrationTimer?.schedule(object : TimerTask() {
            override fun run() {
                calculateBaseline()
            }
        }, 3000)
    }

    private fun calculateBaseline() {
        if (calibrationPoses.size < 30) {
            sendError("INSUFFICIENT_DATA", "포즈 데이터 부족 (${calibrationPoses.size}/30)")
            return
        }

        val baselineValues = mutableMapOf<String, Double>()
        calibrationPoses.flatMap { it.allPoseLandmarks }
            .groupBy { it.landmarkType }
            .forEach { (type, landmarks) ->
                val avgX = landmarks.map { it.position.x }.average()
                val avgY = landmarks.map { it.position.y }.average()
                baselineValues["${type}_x"] = avgX
                baselineValues["${type}_y"] = avgY
            }

        Handler(Looper.getMainLooper()).post {
            sendEvent(mapOf(
                "type" to "completed",
                "baselineValues" to baselineValues
            ))
            calibrationPoses.clear()
        }
    }

    private fun sendEvent(event: Map<String, Any>) {
        try {
            eventSink?.success(event)
        } catch (e: Exception) {
            Log.e("Calibration", "이벤트 전송 실패", e)
        }
    }

    private fun sendError(code: String, message: String?) {
        try {
            eventSink?.error(code, message, null)
        } catch (e: Exception) {
            Log.e("Calibration", "에러 전송 실패", e)
        }
    }

    override fun getView(): View = previewView

    override fun dispose() {
        cameraProvider.unbindAll()
        cameraExecutor.shutdown()
        calibrationTimer?.cancel()
        poseDetector.close()
        eventSink = null
    }
}
