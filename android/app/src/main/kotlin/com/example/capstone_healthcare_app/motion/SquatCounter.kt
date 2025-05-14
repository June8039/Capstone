package com.example.capstone_healthcare_app.motion

import android.util.Log
import com.google.mlkit.vision.pose.Pose
import com.google.mlkit.vision.pose.PoseLandmark
import kotlin.math.abs

class SquatCounter(private val maxCount: Int) : MotionCounter {
    private var squatCount = 0
    private var wasSquatting = false
    private var fullyStood = true
    private var listener: OnCountListener? = null

    // 스쿼트 판단 엉덩이 위치 임계값 (앉았을 때 이 값보다 작아야 함)
    private val SQUAT_THRESHOLD = 120.0

    override fun setOnCountListener(listener: OnCountListener?) {
        this.listener = listener
    }

    override fun onPoseDetected(pose: Pose) {
        if (squatCount >= maxCount) return

        val leftHip = pose.getPoseLandmark(PoseLandmark.LEFT_HIP)
        val leftKnee = pose.getPoseLandmark(PoseLandmark.LEFT_KNEE)
        val rightHip = pose.getPoseLandmark(PoseLandmark.RIGHT_HIP)
        val rightKnee = pose.getPoseLandmark(PoseLandmark.RIGHT_KNEE)

        if (leftHip == null || leftKnee == null || rightHip == null || rightKnee == null) return

        // 엉덩이-무릎 거리 계산
        val leftHipToKnee = abs(leftHip.position.y - leftKnee.position.y)
        val rightHipToKnee = abs(rightHip.position.y - rightKnee.position.y)
        val averageDistance = (leftHipToKnee + rightHipToKnee) / 2

        // 스쿼트 상태 판정
        val isSquatting = averageDistance < SQUAT_THRESHOLD
        val isStanding = averageDistance > SQUAT_THRESHOLD * 1.35f

        // 상태 전이 및 실패 원인 상세 로그
        val countCondition = !wasSquatting && isSquatting && fullyStood
        if (countCondition) {
            squatCount++
            listener?.onCountChanged(squatCount)
            fullyStood = false
            Log.d("SquatCounter", """
                카운트 증가: $squatCount
                [좌표] LH=${leftHip.position.y.toInt()}, LK=${leftKnee.position.y.toInt()}
                      RH=${rightHip.position.y.toInt()}, RK=${rightKnee.position.y.toInt()}
            """.trimIndent())
        } else {
            Log.d("SquatCounter", """
                카운트 실패 사유:
                ${if (wasSquatting) "▸ 이미 앉은 상태에서 시작" else ""}
                ${if (!isSquatting) "▸ 스쿼트 깊이 부족 (현재: ${"%.1f".format(averageDistance)} < 임계값: $SQUAT_THRESHOLD)" else ""}
                ${if (!fullyStood) "▸ 완전히 일어서지 않음" else ""}
            """.trimIndent().replace(Regex("\\s+\n"), "\n"))
        }

        // 상태 업데이트
        wasSquatting = isSquatting
        if (isStanding) fullyStood = true

        // 매 프레임 상태 로그
        Log.d("SquatCounter", """
            [현재 상태] ${if (isSquatting) "⬇앉음" else "서있음"}
            평균 거리: ${"%.1f".format(averageDistance)} 
            이전 상태: ${if (wasSquatting) "앉음" else "서있음"}
            완전 복귀: $fullyStood
        """.trimIndent())
    }

    override fun reset() {
        squatCount = 0
        wasSquatting = false
        fullyStood = true
        Log.d("SquatCounter", "카운트 리셋: 0")
    }

    override fun getCount(): Int = squatCount
}
