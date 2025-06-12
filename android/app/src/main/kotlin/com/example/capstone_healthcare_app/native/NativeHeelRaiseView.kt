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
import com.example.capstone_healthcare_app.motion.HeelRaiseCounter
import com.example.capstone_healthcare_app.motion.PosePainter
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

class NativeHeelRaiseView(
    private val activity: FlutterActivity,
    private val messenger: BinaryMessenger,
    viewId: Int,
    creationParams: Map<String, Any>?
) : PlatformView, ImageAnalysis.Analyzer {

    private val methodChannel = MethodChannel(messenger, "com.example.capstone_healthcare_app/heel_raise")
    private val eventChannel = EventChannel(messenger, "com.example.capstone_healthcare_app/heelraise_events")
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


    private lateinit var heelRaiseCounter: HeelRaiseCounter
    private var currentLensFacing = CameraSelector.LENS_FACING_FRONT
    private var videoCapture: VideoCapture<Recorder>? = null
    private var recording: Recording? = null

    init {
        // 생성 파라미터에서 초기 렌즈 방향 추출
        creationParams?.get("initialLensFacing")?.let { param ->
            currentLensFacing = when (param) {
                is Int -> param
                is Long -> param.toInt()
                is Double -> param.toInt()
                else -> CameraSelector.LENS_FACING_FRONT
            }
        }
        Log.d("NativeHeelRaiseView", "초기 카메라 방향: ${if (currentLensFacing == CameraSelector.LENS_FACING_BACK) "후면" else "전면"}")

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

        // 뷰 계층 구조 정의
        containerLayout.addView(previewView)
        containerLayout.addView(posePainter)
        posePainter.bringToFront()

        // 기준값 추출
        val baselineValues = creationParams?.get("baselineValues") as? Map<*, *>
        val baselineLeftHeelY = baselineValues?.get("left_heel_y") as? Float ?: 0f
        val baselineRightHeelY = baselineValues?.get("right_heel_y") as? Float ?: 0f
        val baselineLeftEyeY = (baselineValues?.get("left_eye_y") as? Number)?.toFloat() ?: 0f
        val baselineRightEyeY = (baselineValues?.get("right_eye_y") as? Number)?.toFloat() ?: 0f

        heelRaiseCounter = HeelRaiseCounter(
            maxCount = 10,
            baselineLeftHeelY = baselineLeftHeelY,
            baselineRightHeelY = baselineRightHeelY,
            baselineLeftEyeY = baselineLeftEyeY,
            baselineRightEyeY = baselineRightEyeY,
        )

        // 채널 설정
        setupMethodChannel()
        setupEventChannel()

        // 카메라 시작
        Handler(Looper.getMainLooper()).postDelayed({
            startCamera()
        }, 300)
    }


    override fun getView(): View = containerLayout

    private fun setupEventChannel() {
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                Log.d("NativeHeelRaiseView", "이벤트 채널 연결됨")
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
                Log.d("NativeHeelRaiseView", "이벤트 채널 연결 해제")
            }
        })
    }

    private fun setupMethodChannel() {
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    try {
                        val baselineValues = call.arguments as Map<String, Any>
                        val leftHeelY = (baselineValues["left_heel_y"] as Number).toFloat()
                        val rightHeelY = (baselineValues["right_heel_y"] as Number).toFloat()
                        val leftEyeY = (baselineValues["left_eye_y"] as? Number)?.toFloat() ?: 0f
                        val rightEyeY = (baselineValues["right_eye_y"] as? Number)?.toFloat() ?: 0f

                        Log.d("NativeHeelRaiseView", "기준값 수신: left=$leftHeelY, right=$rightHeelY")

                        heelRaiseCounter = HeelRaiseCounter(
                            maxCount = 10,
                            baselineLeftHeelY = leftHeelY,
                            baselineRightHeelY = rightHeelY,
                            baselineLeftEyeY = leftEyeY,
                            baselineRightEyeY = rightEyeY,
                        )
                        result.success(null)
                    } catch (e: Exception) {
                        Log.e("NativeHeelRaiseView", "초기화 실패", e)
                        result.error("INIT_ERROR", "데이터 형식 오류: ${e.message}", null)
                    }
                }
                "resetCount" -> {
                    heelRaiseCounter.reset()
                    result.success(null)
                    Log.d("NativeHeelRaiseView", "카운트 리셋됨")
                }
                "startCamera" -> {
                    startCamera()
                    result.success(null)
                }
                "flipCamera" -> {
                    switchCamera()
                    result.success(null)
                }
                "updateLensFacing" -> {
                    val newLensFacing = call.arguments as Int
                    updateLensFacing(newLensFacing)
                    result.success(null)
                }
                "reset" -> {
                    heelRaiseCounter.reset()
                    result.success(null)
                }
                "startRecording" -> {
                    Log.d("NativeHeelRaiseView", "startRecording 메서드 호출됨")
                    val outputPath = call.argument<String>("outputPath") ?: return@setMethodCallHandler
                    Log.d("NativeHeelRaiseView", "outputPath: $outputPath")
                    Log.d("NativeHeelRaiseView", "videoCapture is null? ${videoCapture == null}")
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

                val cameraSelector = CameraSelector.Builder()
                    .requireLensFacing(currentLensFacing)
                    .build()

                Log.d("NativeHeelRaiseView",
                    "실제 적용된 카메라: ${if (cameraSelector.lensFacing == CameraSelector.LENS_FACING_BACK) "후면" else "전면"}"
                )

                val preview = Preview.Builder()
                    .setTargetRotation(previewView.display.rotation)
                    .build()
                    .also { it.setSurfaceProvider(previewView.surfaceProvider) }

                val imageAnalysis = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()
                    .also { it.setAnalyzer(cameraExecutor, this) }

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

                // 1초 지연 후 videoCapture 상태 확인
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
                Log.e("NativeHeelRaiseView", "카메라 시작 실패", e)
                eventSink?.error("CAMERA_ERROR", e.message, null)
            }
        }, ContextCompat.getMainExecutor(activity))
    }



    fun updateLensFacing(newLensFacing: Int) {
        currentLensFacing = newLensFacing
        Log.d("NativeHeelRaiseView", "카메라 방향 업데이트: $newLensFacing")
        startCamera() // 카메라 재시작
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
                    Log.d("NativeHeelRaiseView", "포즈 감지 성공: ${pose.allPoseLandmarks.size}개 랜드마크")
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
        heelRaiseCounter.onPoseDetected(pose)

        // Flutter로 실시간 데이터 전송
        eventSink?.success(mapOf(
            "type" to "pose_update",
            "count" to heelRaiseCounter.getCount(),
            "status" to if (heelRaiseCounter.getCount() >= 10) "completed" else "active"
        ))

        methodChannel.invokeMethod("updateCount", heelRaiseCounter.getCount())
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
                cameraProvider.unbindAll()
                currentLensFacing = newLensFacing // 현재 방향 업데이트
                startCamera() // 새 방향으로 재시작
            } catch (e: Exception) {
                Log.e("NativeHeelRaiseView", "카메라 전환 실패", e)
            }
        }, ContextCompat.getMainExecutor(activity))
        updateLensFacing(newLensFacing)
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
        eventSink?.endOfStream()
        eventChannel.setStreamHandler(null)
        containerLayout.removeAllViews()
        Log.d("NativeHeelRaiseView", "리소스 해제 완료")
    }
}