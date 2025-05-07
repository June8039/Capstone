package com.example.capstone_healthcare_app.motion

import android.util.Log
import com.google.mlkit.vision.pose.Pose
import com.google.mlkit.vision.pose.PoseLandmark
import kotlin.math.abs

class HeelRaiseCounter(
    private val maxCount: Int,
    private val baselineLeftHeelY: Float,
    private val baselineRightHeelY: Float,
    private val raiseRatio: Float = 0.15f,      // 15% 들림
    private val returnThresholdRatio: Float = 0.25f // 25% 복귀
) : MotionCounter {

    private var count = 0
    private var leftRaised = false
    private var rightRaised = false
    private var listener: OnCountListener? = null
    private val minConfidence = 0.4f

    override fun setOnCountListener(listener: OnCountListener?) {
        this.listener = listener
    }

    override fun onPoseDetected(pose: Pose) {
        if (count >= maxCount) return

        // 관절 추출 및 신뢰도 검증
        val leftHeel = pose.getPoseLandmark(PoseLandmark.LEFT_HEEL)
        val rightHeel = pose.getPoseLandmark(PoseLandmark.RIGHT_HEEL)
        val leftHip = pose.getPoseLandmark(PoseLandmark.LEFT_HIP)
        val rightHip = pose.getPoseLandmark(PoseLandmark.RIGHT_HIP)
        if (!isValidLandmark(leftHeel) || !isValidLandmark(rightHeel) ||
            !isValidLandmark(leftHip) || !isValidLandmark(rightHip)) return

        // 현재 위치 (Y축: 위→아래 증가)
        val currentLeftY = leftHeel!!.position.y
        val currentRightY = rightHeel!!.position.y

        // 임계값 재설정 (기준값 대비 절대값 사용)
        val raiseThreshold = baselineLeftHeelY * raiseRatio
        val returnThreshold = baselineLeftHeelY * returnThresholdRatio

        // 1. 들림/복귀 상태 판단
        val isLeftRaisedNow = (baselineLeftHeelY - currentLeftY) > raiseThreshold
        val isRightRaisedNow = (baselineRightHeelY - currentRightY) > raiseThreshold

        val isLeftReturned = abs(currentLeftY - baselineLeftHeelY) < returnThreshold
        val isRightReturned = abs(currentRightY - baselineRightHeelY) < returnThreshold

        // 2. 상태 전이 로직
        when {
            // 양발 복귀 + 이전에 들린 적 있음
            (isLeftReturned && isRightReturned) && (leftRaised || rightRaised) -> {
                count++
                listener?.onCountChanged(count)
                leftRaised = false
                rightRaised = false
                Log.d("HeelRaise", "카운트 증가: $count")
            }

            // 부분 복귀 허용 (발 상태 업데이트)
            isLeftReturned -> leftRaised = false
            isRightReturned -> rightRaised = false

            // 발 들림 상태 업데이트
            isLeftRaisedNow -> leftRaised = true
            isRightRaisedNow -> rightRaised = true
        }

        Log.d("HeelRaise", """
            [기준] Left: ${baselineLeftHeelY.toInt()} (±${returnThreshold.toInt()})
                   Right: ${baselineRightHeelY.toInt()} (±${returnThreshold.toInt()})
            [현재] Left: ${currentLeftY.toInt()} (${if (isLeftReturned) "O" else "X"}) 
                   Right: ${currentRightY.toInt()} (${if (isRightReturned) "O" else "X"})
            [상태] L: ${if (leftRaised) "↑" else "↓"} R: ${if (rightRaised) "↑" else "↓"}
        """.trimIndent())
    }

    private fun isValidLandmark(landmark: PoseLandmark?): Boolean {
        return landmark?.inFrameLikelihood ?: 0f >= minConfidence
    }

    override fun reset() {
        count = 0
        leftRaised = false
        rightRaised = false
        Log.d("HeelRaise", "카운트 리셋: 0")
    }

    override fun getCount(): Int = count
}
