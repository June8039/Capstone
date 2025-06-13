package com.example.capstone_healthcare_app.motion

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.AttributeSet
import android.view.View
import com.google.mlkit.vision.pose.Pose
import com.google.mlkit.vision.pose.PoseLandmark

class PosePainter @JvmOverloads constructor(
    context: Context, attrs: AttributeSet? = null
) : View(context, attrs) {

    private val paint = Paint().apply {
    }

    private val bodyConnections = arrayOf(
        intArrayOf(PoseLandmark.NOSE, PoseLandmark.LEFT_EYE),
        intArrayOf(PoseLandmark.NOSE, PoseLandmark.RIGHT_EYE),
        intArrayOf(PoseLandmark.LEFT_EYE, PoseLandmark.LEFT_EAR),
        intArrayOf(PoseLandmark.RIGHT_EYE, PoseLandmark.RIGHT_EAR),
        intArrayOf(PoseLandmark.LEFT_SHOULDER, PoseLandmark.RIGHT_SHOULDER),
        intArrayOf(PoseLandmark.LEFT_SHOULDER, PoseLandmark.LEFT_ELBOW),
        intArrayOf(PoseLandmark.RIGHT_SHOULDER, PoseLandmark.RIGHT_ELBOW),
        intArrayOf(PoseLandmark.LEFT_ELBOW, PoseLandmark.LEFT_WRIST),
        intArrayOf(PoseLandmark.RIGHT_ELBOW, PoseLandmark.RIGHT_WRIST),
        intArrayOf(PoseLandmark.LEFT_SHOULDER, PoseLandmark.LEFT_HIP),
        intArrayOf(PoseLandmark.RIGHT_SHOULDER, PoseLandmark.RIGHT_HIP),
        intArrayOf(PoseLandmark.LEFT_HIP, PoseLandmark.RIGHT_HIP),
        intArrayOf(PoseLandmark.LEFT_HIP, PoseLandmark.LEFT_KNEE),
        intArrayOf(PoseLandmark.RIGHT_HIP, PoseLandmark.RIGHT_KNEE),
        intArrayOf(PoseLandmark.LEFT_KNEE, PoseLandmark.LEFT_ANKLE),
        intArrayOf(PoseLandmark.RIGHT_KNEE, PoseLandmark.RIGHT_ANKLE),
        intArrayOf(PoseLandmark.LEFT_ANKLE, PoseLandmark.LEFT_HEEL),
        intArrayOf(PoseLandmark.RIGHT_ANKLE, PoseLandmark.RIGHT_HEEL),
        intArrayOf(PoseLandmark.LEFT_HEEL, PoseLandmark.LEFT_FOOT_INDEX),
        intArrayOf(PoseLandmark.RIGHT_HEEL, PoseLandmark.RIGHT_FOOT_INDEX)
    )

    private var currentPose: Pose? = null
    private var isReversed = false
    private var imageWidth: Int = 0
    private var imageHeight: Int = 0

    fun setPose(
        pose: Pose,
        imageWidth: Int,
        imageHeight: Int,
        isReversed: Boolean,
        rotationDegrees: Int = 0
    ) {
        this.currentPose = pose
        this.isReversed = isReversed
        this.imageWidth = imageWidth
        this.imageHeight = imageHeight
        invalidate()
    }

    fun setPose(pose: Pose, isReversed: Boolean) {
        this.currentPose = pose
        this.isReversed = isReversed
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val pose = currentPose ?: return
        val landmarks = pose.allPoseLandmarks
        if (landmarks.isEmpty() || imageWidth == 0 || imageHeight == 0) return

        // 1. scale & offset 계산 (centerCrop 방식)
        val viewRatio = width.toFloat() / height
        val imageRatio = imageWidth.toFloat() / imageHeight

        val scale: Float
        val dx: Float
        val dy: Float

        if (viewRatio > imageRatio) {
            // View가 더 넓음: 이미지 높이를 맞추고 좌우를 crop
            scale = height.toFloat() / imageHeight
            dx = (width - imageWidth * scale) / 2
            dy = 0f
        } else {
            // View가 더 높음: 이미지 너비를 맞추고 상하를 crop
            scale = width.toFloat() / imageWidth
            dx = 0f
            dy = (height - imageHeight * scale) / 2
        }

        // 2. 연결선 그리기


        // 3. 랜드마크 점 그리기

    }
}
