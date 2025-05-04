package com.example.capstone_healthcare_app.motion

import com.google.mlkit.vision.pose.Pose
import com.google.mlkit.vision.pose.PoseLandmark
import kotlin.math.abs

class HeelRaiseCounter(
    private val maxCount: Int,
    private val baselineLeftHeelY: Float, // 캘리브레이션에서 측정된 초기 값
    private val baselineRightHeelY: Float,
    private val raiseRatio: Float = 0.3f // 엉덩이-발 길이 대비 30% 들림
) : MotionCounter {

    private var count = 0
    private var wasRaised = false
    private var fullyLowered = true
    private var listener: OnCountListener? = null
    private val minConfidence = 0.3f // 관절 신뢰도 최소값

    override fun setOnCountListener(listener: OnCountListener?) {
        this.listener = listener
    }

    override fun onPoseDetected(pose: Pose) {
        if (count >= maxCount) return

        val leftHeel = pose.getPoseLandmark(PoseLandmark.LEFT_HEEL)
        val rightHeel = pose.getPoseLandmark(PoseLandmark.RIGHT_HEEL)
        val leftHip = pose.getPoseLandmark(PoseLandmark.LEFT_HIP)
        val rightHip = pose.getPoseLandmark(PoseLandmark.RIGHT_HIP)

        // 필수 관절 신뢰도 검증 (화면 내 정확한 위치 파악)
        if (leftHeel?.inFrameLikelihood ?: 0f < minConfidence ||
            rightHeel?.inFrameLikelihood ?: 0f < minConfidence ||
            leftHip?.inFrameLikelihood ?: 0f < minConfidence ||
            rightHip?.inFrameLikelihood ?: 0f < minConfidence) return

        // 관절 위치 추출
        val currentLeftY = leftHeel!!.position.y
        val currentRightY = rightHeel!!.position.y

        // 동적 임계값 계산 (엉덩이-발 길이 기반)
        val hipToHeelLength = (abs(leftHip!!.position.y - currentLeftY) +
                abs(rightHip!!.position.y - currentRightY)) / 2
        val raiseThreshold = hipToHeelLength * raiseRatio

        // 1. 양발 들림 판단
        val leftRaised = (baselineLeftHeelY - currentLeftY) > raiseThreshold
        val rightRaised = (baselineRightHeelY - currentRightY) > raiseThreshold
        val isRaised = leftRaised && rightRaised

        // 2. 복귀 판단 (기준 위치 ±10% 이내)
        val lowerThreshold = hipToHeelLength * 0.1f
        val leftLowered = abs(currentLeftY - baselineLeftHeelY) < lowerThreshold
        val rightLowered = abs(currentRightY - baselineRightHeelY) < lowerThreshold
        val isLowered = leftLowered && rightLowered // 양발 모두 복귀

        // 3. 카운트 로직
        if (!wasRaised && isRaised && fullyLowered) {
            count++
            listener?.onCountChanged(count)
            fullyLowered = false
        }
        if (isLowered) fullyLowered = true
        wasRaised = isRaised
    }

    override fun reset() {
        count = 0
        wasRaised = false
        fullyLowered = true
    }

    override fun getCount(): Int = count
}
