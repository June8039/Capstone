package com.example.capstone_healthcare_app.native

import android.Manifest
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.util.Size
import android.view.View
import android.widget.FrameLayout
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
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF

class GuideBoxOverlay(context: Context) : View(context) {
    private val paint = Paint().apply {
        color = Color.GREEN
        style = Paint.Style.STROKE
        strokeWidth = 8f
        isAntiAlias = true
    }
    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val marginX = width * 0.20f
        val marginY = height * 0.20f
        val left = marginX
        val top = marginY
        val right = width - marginX
        val bottom = height - marginY
        canvas.drawRect(RectF(left, top, right, bottom), paint)
    }

}

class NativeCalibrationView(
    private val activity: FlutterActivity,
    private val methodChannel: MethodChannel,
    private val eventChannel: EventChannel,
    creationParams: Map<String, Any>?
) : PlatformView, ImageAnalysis.Analyzer {

    private var currentLensFacing = CameraSelector.LENS_FACING_BACK
    private val cameraExecutor = Executors.newSingleThreadExecutor()
    private val cameraProviderFuture = ProcessCameraProvider.getInstance(activity)
    private lateinit var cameraProvider: ProcessCameraProvider
    private lateinit var poseDetector: PoseDetector
    private val calibrationPoses = mutableListOf<Pose>()
    private var calibrationTimer: Timer? = null
    private val frameLayout = FrameLayout(activity)
    private val previewView = PreviewView(activity).apply {
        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
    }
    private val guideBoxOverlay = GuideBoxOverlay(activity).apply {
        layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
    }
    private var eventSink: EventChannel.EventSink? = null
    private var isProcessing = false

    init {
        Log.d("Calibration", "NativeCalibrationView init 시작") // 1. 초기화 시작 로그

        creationParams?.get("initialLensFacing")?.let {
            currentLensFacing = it as Int
        }

        cameraProviderFuture.addListener({
            try {
                cameraProvider = cameraProviderFuture.get()
                Log.d("Calibration", "카메라 프로바이더 초기화 성공") // 2. 카메라 프로바이더 초기화
                bindCameraUseCases()
            } catch (e: Exception) {
                Log.e("Calibration", "카메라 초기화 실패", e)
                sendError("CAMERA_INIT_FAILED", e.message)
            }
        }, ContextCompat.getMainExecutor(activity))

        frameLayout.addView(previewView)
        frameLayout.addView(guideBoxOverlay)

        // 포즈 감지기 초기화
        val options = PoseDetectorOptions.Builder()
            .setDetectorMode(PoseDetectorOptions.STREAM_MODE)
            .build()
        poseDetector = PoseDetection.getClient(options)
        Log.d("Calibration", "포즈 감지기 초기화 완료") // 3. 포즈 감지기 초기화

        // 이벤트 채널 설정
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                Log.d("Calibration", "이벤트 채널 연결됨") // 4. 이벤트 채널 연결
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
                Log.d("Calibration", "이벤트 채널 연결 해제") // 5. 이벤트 채널 해제
            }
        })

        // 메서드 채널 설정
        methodChannel.setMethodCallHandler { call, result ->
            Log.d("Calibration", "메서드 채널 호출: ${call.method}") // 6. 메서드 채널 호출 시점
            when (call.method) {
                "switchCamera" -> {
                    switchCamera()
                    result.success(null)
                }
                "startCalibration" -> {
                    Log.d("Calibration", "기준 자세 측정 시작 명령 수신")
                    calibrationPoses.clear()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        Log.d("Calibration", "NativeCalibrationView init 완료") // 7. 초기화 완료 로그
    }

    //카메라 바인딩
    private fun bindCameraUseCases() {
        val cameraSelector = CameraSelector.Builder()
            .requireLensFacing(currentLensFacing)
            .build()

        val preview = Preview.Builder()
            .setTargetRotation(previewView.display.rotation)
            .build()
            .also { it.setSurfaceProvider(previewView.surfaceProvider) }

        val imageAnalysis = ImageAnalysis.Builder()
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

    override fun getView(): View = frameLayout

    fun isUserInGuideBox(pose: Pose): Boolean {
        val marginX = previewView.width * 0.08f
        val marginY = previewView.height * 0.08f
        val left = marginX
        val top = marginY
        val right = previewView.width - marginX
        val bottom = previewView.height - marginY

        val keyLandmarks = listOf(
            pose.getPoseLandmark(PoseLandmark.LEFT_SHOULDER),
            pose.getPoseLandmark(PoseLandmark.RIGHT_SHOULDER),
            pose.getPoseLandmark(PoseLandmark.LEFT_HIP),
            pose.getPoseLandmark(PoseLandmark.RIGHT_HIP)
        )
        return keyLandmarks.all { lm ->
            lm != null &&
                    lm.position.x in left..right &&
                    lm.position.y in top..bottom
        }
    }


    //카메라 전환
    private fun switchCamera() {
        val newLensFacing = if (currentLensFacing == CameraSelector.LENS_FACING_BACK) {
            CameraSelector.LENS_FACING_FRONT
        } else {
            CameraSelector.LENS_FACING_BACK
        }

        cameraProviderFuture.addListener({
            try {
                val cameraProvider = cameraProviderFuture.get()
                currentLensFacing = newLensFacing

                cameraProvider.unbindAll()
                bindCameraUseCases()

                Log.d("Calibration", "카메라 전환 성공: ${if (currentLensFacing == CameraSelector.LENS_FACING_BACK) "후면" else "전면"}")
            } catch (e: Exception) {
                Log.e("Calibration", "카메라 전환 실패", e)
                sendError("SWITCH_FAILED", e.message)
            }
        }, ContextCompat.getMainExecutor(activity))
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
        val isInBox = isUserInGuideBox(pose)
        val isConfident = isHighConfidencePose(pose)

        sendEvent(mapOf(
            "type" to "position_status",
            "isInBox" to isInBox
        ))

        if (isConfident && isInBox) {
            calibrationPoses.add(pose)
            val progress = calibrationPoses.size.toDouble() / 100
            val percent = (progress * 100).toInt()
            Log.d("Calibration", "진행률 업데이트: ${calibrationPoses.size}/100 ($percent%)")
            sendEvent(mapOf("type" to "progress", "value" to percent))

            if (calibrationPoses.size >= 100) {
                calculateBaseline()
            }
        } else {
            if (!isConfident && !isInBox) {
                Log.w("Calibration", "신뢰도 부족 + 박스 밖 포즈 무시")
            } else if (!isConfident) {
                Log.w("Calibration", "신뢰도 부족 포즈 무시")
            } else if (!isInBox) {
                Log.w("Calibration", "박스 밖 포즈 무시")
            }
        }
    }

    private fun isHighConfidencePose(pose: Pose): Boolean {
        val minConfidence = 0.4f
        val requiredLandmarks = listOf(
            PoseLandmark.LEFT_SHOULDER,    // 11
            PoseLandmark.RIGHT_SHOULDER,   // 12
            PoseLandmark.LEFT_HIP,         // 23
            PoseLandmark.RIGHT_HIP,        // 24
            PoseLandmark.LEFT_KNEE,        // 25
            PoseLandmark.RIGHT_KNEE,       // 26
            PoseLandmark.LEFT_ANKLE,       // 27
            PoseLandmark.RIGHT_ANKLE,      // 28
            PoseLandmark.LEFT_HEEL,        // 29
            PoseLandmark.RIGHT_HEEL        // 30
        )
        for (type in requiredLandmarks) {
            val landmark = pose.getPoseLandmark(type)
            if (landmark == null || landmark.inFrameLikelihood < minConfidence) {
                Log.w("Calibration", "랜드마크 $type 신뢰도 부족: ${landmark?.inFrameLikelihood}")
                return false
            }
        }
        return true
    }


    private fun median(list: List<Float>): Double {
        if (list.isEmpty()) return Double.NaN
        val sorted = list.sorted()
        val size = sorted.size
        return if (size % 2 == 1) {
            sorted[size / 2].toDouble()
        } else {
            (sorted[size / 2 - 1] + sorted[size / 2]) / 2.0
        }
    }


    private fun calculateBaseline() {
        if (calibrationPoses.size < 30) {
            sendError("INSUFFICIENT_DATA", "포즈 데이터 부족 (${calibrationPoses.size}/30)")
            return
        }

        val baselineValues = mutableMapOf<String, Double>()
        calibrationPoses.flatMap { it.allPoseLandmarks }
            .groupBy { it.landmarkType }
            .forEach { (typeInt, landmarks) ->
                // X, Y 좌표 추출
                val xs = landmarks.map { it.position.x }
                val ys = landmarks.map { it.position.y }

                val medianX = median(xs)
                val medianY = median(ys)

                val typeName = typeInt.toString()
                baselineValues["${typeName}_x"] = medianX
                baselineValues["${typeName}_y"] = medianY

                // 발 뒤꿈치 Y값 별도 저장
                if (typeInt == PoseLandmark.LEFT_HEEL) {
                    baselineValues["left_heel_y"] = medianY
                }
                if (typeInt == PoseLandmark.RIGHT_HEEL) {
                    baselineValues["right_heel_y"] = medianY
                }
                // 눈 Y값 별도 저장
                if (typeInt == PoseLandmark.LEFT_EYE) {
                    baselineValues["left_eye_y"] = medianY
                }
                if (typeInt == PoseLandmark.RIGHT_EYE) {
                    baselineValues["right_eye_y"] = medianY
                }
            }

        Handler(Looper.getMainLooper()).post {
            sendEvent(
                mapOf(
                    "type" to "completed",
                    "baselineValues" to baselineValues,
                    "lensFacing" to currentLensFacing
                )
            )
            calibrationPoses.clear()
        }
    }


    private fun sendEvent(event: Map<String, Any>) {
        activity.runOnUiThread {
            try {
                Log.d("Calibration", "이벤트 전송 시도: $event")
                eventSink?.success(event)
                Log.d("Calibration", "이벤트 전송 성공")
            } catch (e: Exception) {
                Log.e("Calibration", "이벤트 전송 실패", e)
            }
        }
    }


    private fun sendError(code: String, message: String?) {
        try {
            eventSink?.error(code, message, null)
        } catch (e: Exception) {
            Log.e("Calibration", "에러 전송 실패", e)
        }
    }

    override fun dispose() {
        Log.d("Calibration", "리소스 해제 시작")
        cameraProvider.unbindAll()
        cameraExecutor.shutdownNow()
        calibrationTimer?.cancel()
        poseDetector.close()
        eventSink = null
        Log.d("Calibration", "리소스 해제 완료")
    }
}