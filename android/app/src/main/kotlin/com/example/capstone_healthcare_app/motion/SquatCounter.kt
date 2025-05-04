package com.example.capstone_healthcare_app.motion

import android.util.Log
import android.graphics.PointF
import com.google.mlkit.vision.pose.Pose
import com.google.mlkit.vision.pose.PoseLandmark

class SquatCounter(private val maxCount: Int) : MotionCounter {
    private var squatCount = 0
    private var wasSquatting = false
    private var fullyStood = true
    private var listener: OnCountListener? = null

    // 스쿼트 판단 엉덩이 위치 임계값
    private val SQUAT_THRESHOLD = 110.0

    // 팔 위치 판단 임계값
    private val ARM_ANGLE_TARGET = 80.0
    private val MAX_ARM_DEVIATION = 45.0

    override fun setOnCountListener(listener: OnCountListener?) {
        this.listener = listener
    }

    override fun onPoseDetected(pose: Pose) {
        if (squatCount >= maxCount) return

        val leftHip = pose.getPoseLandmark(PoseLandmark.LEFT_HIP)
        val leftKnee = pose.getPoseLandmark(PoseLandmark.LEFT_KNEE)
        val rightHip = pose.getPoseLandmark(PoseLandmark.RIGHT_HIP)
        val rightKnee = pose.getPoseLandmark(PoseLandmark.RIGHT_KNEE)

        val leftShoulder = pose.getPoseLandmark(PoseLandmark.LEFT_SHOULDER)
        val leftElbow = pose.getPoseLandmark(PoseLandmark.LEFT_ELBOW)
        val leftWrist = pose.getPoseLandmark(PoseLandmark.LEFT_WRIST)
        val rightShoulder = pose.getPoseLandmark(PoseLandmark.RIGHT_SHOULDER)
        val rightElbow = pose.getPoseLandmark(PoseLandmark.RIGHT_ELBOW)
        val rightWrist = pose.getPoseLandmark(PoseLandmark.RIGHT_WRIST)

        if (leftHip == null || leftKnee == null || rightHip == null || rightKnee == null ||
            leftShoulder == null || leftElbow == null || leftWrist == null ||
            rightShoulder == null || rightElbow == null || rightWrist == null
        ) return

        val leftHipToKnee = Math.abs(leftHip.position.y - leftKnee.position.y)
        val rightHipToKnee = Math.abs(rightHip.position.y - rightKnee.position.y)
        val averageDistance = (leftHipToKnee + rightHipToKnee) / 2

        val isSquatting = averageDistance < SQUAT_THRESHOLD
        val armsExtended = areArmsInFront(pose)

        if (!wasSquatting && isSquatting && fullyStood && armsExtended) {
            squatCount++
            listener?.onCountChanged(squatCount)
            fullyStood = false
        }

        if (averageDistance > SQUAT_THRESHOLD * 1.35f) {
            fullyStood = true
        }

        wasSquatting = isSquatting

        Log.d("SquatCounter",
            "횟수: $squatCount, 평균거리: $averageDistance, 팔상태: ${if(armsExtended) "OK" else "Bad"}"
        )
    }

    private fun areArmsInFront(pose: Pose): Boolean {
        val leftShoulder = pose.getPoseLandmark(PoseLandmark.LEFT_SHOULDER)
        val leftElbow = pose.getPoseLandmark(PoseLandmark.LEFT_ELBOW)
        val rightShoulder = pose.getPoseLandmark(PoseLandmark.RIGHT_SHOULDER)
        val rightElbow = pose.getPoseLandmark(PoseLandmark.RIGHT_ELBOW)
        val leftHip = pose.getPoseLandmark(PoseLandmark.LEFT_HIP)
        val rightHip = pose.getPoseLandmark(PoseLandmark.RIGHT_HIP)

        if (leftHip == null || rightHip == null ||
            leftShoulder == null || leftElbow == null ||
            rightShoulder == null || rightElbow == null
        ) return false

        val spineMid = PointF(
            (leftHip.position.x + rightHip.position.x) / 2,
            (leftHip.position.y + rightHip.position.y) / 2
        )

        val leftAngle = calculateAngle(spineMid, leftShoulder.position, leftElbow.position)
        val rightAngle = calculateAngle(spineMid, rightShoulder.position, rightElbow.position)

        return Math.abs(leftAngle - ARM_ANGLE_TARGET) < MAX_ARM_DEVIATION &&
                Math.abs(rightAngle - ARM_ANGLE_TARGET) < MAX_ARM_DEVIATION
    }

    private fun calculateAngle(a: PointF, b: PointF, c: PointF): Double {
        val angle = Math.toDegrees(
            Math.atan2(c.y.toDouble() - b.y, c.x.toDouble() - b.x) -
                    Math.atan2(a.y.toDouble() - b.y, a.x.toDouble() - b.x)
        )
        return if (angle > 180) 360 - angle else angle
    }

    override fun reset() {
        squatCount = 0
        wasSquatting = false
        fullyStood = true
    }

    override fun getCount(): Int = squatCount
}
