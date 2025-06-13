package com.example.capstone_healthcare_app.native

import android.content.Context
import android.graphics.Color
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.os.Handler
import android.os.Looper
import android.widget.FrameLayout
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.example.capstone_healthcare_app.motion.CoordinateMapper
import com.example.capstone_healthcare_app.motion.PosePainter
import com.example.capstone_healthcare_app.motion.SquatCounter
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.pose.Pose
import com.google.mlkit.vision.pose.PoseDetection
import com.google.mlkit.vision.pose.defaults.PoseDetectorOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import androidx.camera.video.VideoCapture
import androidx.camera.video.Recorder
import androidx.camera.video.Recording
import androidx.camera.video.FileOutputOptions
import androidx.camera.video.VideoRecordEvent
import androidx.camera.video.Quality
import androidx.camera.video.QualitySelector
import java.io.File

class NativeSquatView(
    private val activity: FlutterActivity,
    private val messenger: BinaryMessenger,
    viewId: Int,
    creationParams: Map<String, Any>?
) : PlatformView, ImageAnalysis.Analyzer {

    private val methodChannel = MethodChannel(messenger, "com.example.capstone_healthcare_app/squat")
    private val eventChannel = EventChannel(messenger, "com.example.capstone_healthcare_app/squat_events")
    private val cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val cameraProviderFuture = ProcessCameraProvider.getInstance(activity)
    private var eventSink: EventChannel.EventSink? = null

    // 뷰 계층 구조
    private lateinit var previewView: PreviewView
    private lateinit var posePainter: PosePainter
    private val containerLayout = FrameLayout(activity).apply {
        layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
    }

    private lateinit var squatCounter: SquatCounter
    private var currentLensFacing = CameraSelector.LENS_FACING_FRONT
    private var videoCapture: VideoCapture<Recorder>? = null
    private var recording: Recording? = null

    init {
        setupEventChannel()
        setupMethodChannel()

        // PreviewView 설정
        previewView = PreviewView(activity).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            implementationMode = PreviewView.ImplementationMode.COMPATIBLE // TextureView 사용
            scaleType = PreviewView.ScaleType.FILL_CENTER
        }


        posePainter = PosePainter(activity).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(Color.TRANSPARENT)
            z = 1f
        }

        containerLayout.addView(previewView)
        containerLayout.addView(posePainter)
        posePainter.bringToFront()

        squatCounter = SquatCounter(
            maxCount = 10
        )
        startCamera()
    }

    override fun getView(): View = containerLayout

    private fun setupEventChannel() {
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events // 이벤트 전송 객체 저장
                Log.d("NativeSquatView", "이벤트 채널 연결됨")
                eventSink?.success(mapOf(
                    "type" to "pose_update",
                    "count" to squatCounter.getCount(),
                    "status" to if (squatCounter.getCount() >= 10) "completed" else "active"
                ))
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null // 이벤트 전송 객체 해제
                stopCameraAndAnalysis()
                Log.d("NativeSquatView", "이벤트 채널 연결 해제")
            }
        })
    }


    private fun setupMethodChannel() {
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "flipCamera" -> {
                    switchCamera()
                    result.success(null)
                }

                "resetCount" -> {
                    squatCounter.reset()
                    result.success(null)
                }

                "startCamera" -> {
                    startCamera()
                    result.success(null)
                }
                "reset" -> {
                    squatCounter.reset()
                    result.success(null)
                }
                "startRecording" -> {
                    Log.d("NativeSquatView", "startRecording 메서드 호출됨")
                    val outputPath = call.argument<String>("outputPath") ?: return@setMethodCallHandler
                    Log.d("NativeSquatView", "outputPath: $outputPath")
                    Log.d("NativeSquatView", "videoCapture is null? ${videoCapture == null}")
                    startVideoRecording(outputPath, result)
                }

                "stopRecording" -> {
                    stopVideoRecording(result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startCamera() {
        cameraProviderFuture.addListener({
            try {
                val cameraProvider = cameraProviderFuture.get()
                cameraProvider.unbindAll()

                val preview = Preview.Builder().build().also {
                    it.setSurfaceProvider(previewView.surfaceProvider)
                }

                val imageAnalysis = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()
                    .also { it.setAnalyzer(cameraExecutor, this) }

                val cameraSelector = CameraSelector.Builder()
                    .requireLensFacing(currentLensFacing)
                    .build()

                val recorder = Recorder.Builder()
                    .setQualitySelector(QualitySelector.from(Quality.HD))
                    .build()
                videoCapture = VideoCapture.withOutput(recorder)

                cameraProvider.bindToLifecycle(
                    activity as LifecycleOwner,
                    cameraSelector,
                    preview,
                    imageAnalysis,
                    videoCapture
                )

                Handler(Looper.getMainLooper()).postDelayed({
                    if (videoCapture != null) {
                        Log.d("NativeHeelRaiseView", "videoCapture 정상 초기화 확인")
                        eventSink?.success(mapOf("type" to "camera_ready"))
                    } else {
                        Log.e("NativeHeelRaiseView", "videoCapture 초기화 실패!")
                        eventSink?.error("VIDEO_CAPTURE_ERROR", "VideoCapture 초기화 실패", null)
                    }
                }, 1000) // CameraX 바인딩 완료 대기

            } catch (e: Exception) {
                Log.e("NativeSquatView", "카메라 시작 실패", e)
                eventSink?.error("CAMERA_ERROR", e.message, null)

            }
        }, ContextCompat.getMainExecutor(activity))
    }

    private fun bindImageAnalysis(
        cameraProvider: ProcessCameraProvider,
        cameraSelector: CameraSelector
    ) {
        val imageAnalysis = ImageAnalysis.Builder()
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .build()

        imageAnalysis.setAnalyzer(cameraExecutor, this)

        cameraProvider.bindToLifecycle(
            activity as LifecycleOwner,
            cameraSelector,
            imageAnalysis
        )
    }

    override fun analyze(imageProxy: ImageProxy) {
        val mediaImage = imageProxy.image
        if (mediaImage != null) {
            val image = InputImage.fromMediaImage(
                mediaImage,
                imageProxy.imageInfo.rotationDegrees
            )

            val options = PoseDetectorOptions.Builder()
                .setDetectorMode(PoseDetectorOptions.STREAM_MODE)
                .build()

            val poseDetector = PoseDetection.getClient(options)

            poseDetector.process(image)
                .addOnSuccessListener { pose ->
                    Log.d("NativeSquatView", "포즈 감지 성공: ${pose.allPoseLandmarks.size}개 랜드마크")

                    posePainter.setPose(
                        pose,
                        mediaImage.width,
                        mediaImage.height,
                        currentLensFacing == CameraSelector.LENS_FACING_FRONT,
                        imageProxy.imageInfo.rotationDegrees
                    )

                    handlePose(pose)
                }
                .addOnCompleteListener {
                    imageProxy.close()
                }
        } else {
            imageProxy.close()
        }
    }

    private fun handlePose(pose: Pose) {
        squatCounter.onPoseDetected(pose)
        Log.d("NativeSquatView", "현재 카운트: ${squatCounter.getCount()}")

        if (eventSink != null) {
            eventSink?.success(
                mapOf(
                    "type" to "pose_update",
                    "count" to squatCounter.getCount(),
                    "status" to if (squatCounter.getCount() >= 10) "completed" else "active"
                )
            )
            Log.d("NativeSquatView", "이벤트 전송: count=${squatCounter.getCount()}")
        } else {
            Log.e("NativeSquatView", "eventSink가 null입니다!")
        }
        methodChannel.invokeMethod("updateCount", squatCounter.getCount())
    }


    private fun switchCamera() {
        val newLensFacing = if (currentLensFacing == CameraSelector.LENS_FACING_BACK) {
            CameraSelector.LENS_FACING_FRONT
        } else {
            CameraSelector.LENS_FACING_BACK
        }

        cameraProviderFuture.addListener({
            try {
                val cameraProvider = cameraProviderFuture.get()
                val preview = Preview.Builder().build().also {
                    it.setSurfaceProvider(previewView.surfaceProvider)
                }
                val cameraSelector = CameraSelector.Builder()
                    .requireLensFacing(newLensFacing)
                    .build()

                cameraProvider.unbindAll()
                cameraProvider.bindToLifecycle(
                    activity as LifecycleOwner,
                    cameraSelector,
                    preview
                )
                bindImageAnalysis(cameraProvider, cameraSelector)
                currentLensFacing = newLensFacing
            } catch (e: Exception) {
                Log.e("NativeSquatView", "카메라 전환 실패", e)
            }
        }, ContextCompat.getMainExecutor(activity))
    }

    private fun stopCameraAndAnalysis() {
        try {
            val cameraProvider = cameraProviderFuture.get()
            cameraProvider.unbindAll()
            Log.d("NativeSquatView", "카메라 UseCase 해제 완료")
        } catch (e: Exception) {
            Log.e("NativeSquatView", "카메라 UseCase 해제 실패", e)
        }

        try {
            if (!cameraExecutor.isShutdown) {
                cameraExecutor.shutdownNow()
                Log.d("NativeSquatView", "카메라 Executor 종료 완료")
            }
        } catch (e: Exception) {
            Log.e("NativeSquatView", "카메라 Executor 종료 실패", e)
        }
    }

    private fun startVideoRecording(outputPath: String, result: MethodChannel.Result) {
        val videoCapture = this.videoCapture ?: run {
            result.error("NO_VIDEO_CAPTURE", "VideoCapture not initialized", null)
            return
        }
        val outputFile = File(outputPath)
        val outputOptions = FileOutputOptions.Builder(outputFile).build()
        recording = videoCapture.output
            .prepareRecording(activity, outputOptions)
            .start(ContextCompat.getMainExecutor(activity)) { event ->
                when (event) {
                    is VideoRecordEvent.Start -> {
                        Log.d("NativeHeelRaiseView", "녹화 시작")
                        result.success(null)
                    }
                    is VideoRecordEvent.Finalize -> {
                        Log.d("NativeHeelRaiseView", "녹화 종료: ${outputFile.absolutePath}")
                        Log.d("NativeHeelRaiseView", "파일 존재 여부: ${outputFile.exists()}")
                        eventSink?.success(mapOf("type" to "recording_complete", "filePath" to outputFile.absolutePath))
                    }
                }
            }
    }

    private fun stopVideoRecording(result: MethodChannel.Result) {
        recording?.stop()
        recording = null
        result.success(null)
    }

    override fun dispose() {
        cameraExecutor.shutdown()
        eventSink?.endOfStream() //이벤트 스트림 종료 알림
        eventChannel.setStreamHandler(null) // 핸들러 제거
        containerLayout.removeAllViews()
        Log.d("NativeSquatView", "리소스 해제 완료")
    }
}