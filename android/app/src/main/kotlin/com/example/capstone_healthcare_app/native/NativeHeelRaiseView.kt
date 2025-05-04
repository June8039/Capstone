package com.example.capstone_healthcare_app.native

import android.content.Context
import android.graphics.Color
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.example.capstone_healthcare_app.motion.CoordinateMapper
import com.example.capstone_healthcare_app.motion.PosePainter
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.pose.Pose
import com.google.mlkit.vision.pose.PoseLandmark
import com.google.mlkit.vision.pose.PoseDetection
import com.google.mlkit.vision.pose.defaults.PoseDetectorOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class NativeHeelRaiseView(
    private val activity: FlutterActivity,
    private val messenger: BinaryMessenger,
    viewId: Int
) : PlatformView {

    private val methodChannel = MethodChannel(messenger, "com.example.capstone_healthcare_app/heel_raise")
    private val eventChannel = EventChannel(messenger, "com.example.capstone_healthcare_app/heel_raise_events")
    private val cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val cameraProviderFuture = ProcessCameraProvider.getInstance(activity)

    // 뷰 계층 구조
    private val containerLayout = FrameLayout(activity).apply {
        layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
    }

    private val previewView = PreviewView(activity).apply {
        layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
    }

    private val posePainter = PosePainter(activity).apply {
        layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
        setBackgroundColor(Color.TRANSPARENT)
    }

    private var eventSink: EventChannel.EventSink? = null
    private var currentLensFacing = CameraSelector.LENS_FACING_BACK
    private var heelRaiseCount = 0
    private var isHeelUp = false

    init {
        containerLayout.addView(previewView)
        containerLayout.addView(posePainter)
        setupMethodChannel()
        setupEventChannel()
        startCamera()
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
                "flipCamera" -> {
                    switchCamera()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startCamera() {
        cameraProviderFuture.addListener({
            try {
                val cameraProvider = cameraProviderFuture.get()
                val preview = Preview.Builder().build().also {
                    it.setSurfaceProvider(previewView.surfaceProvider)
                }
                val cameraSelector = CameraSelector.Builder()
                    .requireLensFacing(currentLensFacing)
                    .build()

                cameraProvider.unbindAll()
                cameraProvider.bindToLifecycle(
                    activity as LifecycleOwner,
                    cameraSelector,
                    preview
                )
                bindImageAnalysis(cameraProvider, cameraSelector)
            } catch (e: Exception) {
                Log.e("NativeHeelRaiseView", "카메라 시작 실패", e)
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

        imageAnalysis.setAnalyzer(cameraExecutor, { imageProxy ->
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
                        handlePose(pose)
                        posePainter.setPose(
                            pose,
                            mediaImage.width,
                            mediaImage.height,
                            currentLensFacing == CameraSelector.LENS_FACING_FRONT,
                            imageProxy.imageInfo.rotationDegrees
                        )
                    }
                    .addOnCompleteListener {
                        imageProxy.close()
                    }
            } else {
                imageProxy.close()
            }
        })

        cameraProvider.bindToLifecycle(
            activity as LifecycleOwner,
            cameraSelector,
            imageAnalysis
        )
    }

    private fun handlePose(pose: Pose) {
        val leftHeel = pose.getPoseLandmark(PoseLandmark.LEFT_HEEL)
        val rightHeel = pose.getPoseLandmark(PoseLandmark.RIGHT_HEEL)
        val leftHip = pose.getPoseLandmark(PoseLandmark.LEFT_HIP)
        val rightHip = pose.getPoseLandmark(PoseLandmark.RIGHT_HIP)

        if (leftHeel == null || rightHeel == null || leftHip == null || rightHip == null) return

        // 발뒤꿈치-엉덩이 거리 계산
        val avgHeelHeight = (leftHeel.position.y + rightHeel.position.y) / 2
        val avgHipHeight = (leftHip.position.y + rightHip.position.y) / 2
        val heelLiftRatio = (avgHipHeight - avgHeelHeight) / avgHipHeight

        // 동작 판단 로직
        if (heelLiftRatio > 0.15 && !isHeelUp) {
            heelRaiseCount++
            isHeelUp = true
            sendCountUpdate()
        } else if (heelLiftRatio < 0.05) {
            isHeelUp = false
        }
    }

    private fun sendCountUpdate() {
        activity.runOnUiThread {
            eventSink?.success(mapOf(
                "type" to "count",
                "value" to heelRaiseCount
            ))
            methodChannel.invokeMethod("updateCount", heelRaiseCount)
        }
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
                Log.e("NativeHeelRaiseView", "카메라 전환 실패", e)
            }
        }, ContextCompat.getMainExecutor(activity))
    }

    override fun dispose() {
        cameraExecutor.shutdown()
        eventSink?.endOfStream()
        eventChannel.setStreamHandler(null)
        containerLayout.removeAllViews()
    }
}
