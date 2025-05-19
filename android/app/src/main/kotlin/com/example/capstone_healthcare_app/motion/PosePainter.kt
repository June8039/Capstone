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
        color = Color.WHITE
        style = Paint.Style.FILL
        strokeWidth = 10f
        isAntiAlias = true
    }

    // 신체 부위 연결선 정의 (ML Kit 33개 랜드마크 기준)
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
    private var coordinateMapper: CoordinateMapper? = null

    fun setPose(pose: Pose, imageWidth: Int, imageHeight: Int, isReversed: Boolean, rotationDegrees: Int = 0) {
        this.currentPose = pose
        this.isReversed = isReversed

        // 화면이 회전되었을 경우 너비와 높이 교체
        val finalImageWidth = if (rotationDegrees == 90 || rotationDegrees == 270) imageHeight else imageWidth
        val finalImageHeight = if (rotationDegrees == 90 || rotationDegrees == 270) imageWidth else imageHeight

        this.coordinateMapper = CoordinateMapper(
            finalImageWidth.toFloat(),
            finalImageHeight.toFloat(),
            width.toFloat(),
            height.toFloat(),
            rotationDegrees
        )
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val pose = currentPose ?: return
        val mapper = coordinateMapper ?: return

        // 연결선 그리기
        for (connection in bodyConnections) {
            val start = pose.getPoseLandmark(connection[0])
            val end = pose.getPoseLandmark(connection[1])
            if (start != null && end != null) {
                var startX = mapper.transposeX(start.position.x)
                var startY = mapper.transposeY(start.position.y)
                var endX = mapper.transposeX(end.position.x)
                var endY = mapper.transposeY(end.position.y)
                if (isReversed) {
                    startX = width - startX
                    endX = width - endX
                }
                canvas.drawLine(startX, startY, endX, endY, paint)
            }
        }
        // 랜드마크 점 그리기
        for (landmark in pose.allPoseLandmarks) {
            var x = mapper.transposeX(landmark.position.x)
            var y = mapper.transposeY(landmark.position.y)
            if (isReversed) x = width - x
            canvas.drawCircle(x, y, 10f, paint)
        }
    }
}