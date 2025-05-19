package com.example.capstone_healthcare_app.motion

import android.util.Log
import com.google.mlkit.vision.pose.Pose
import com.google.mlkit.vision.pose.PoseLandmark
import kotlin.math.abs

class HeelRaiseCounter(
    private val maxCount: Int,
    private val baselineLeftHeelY: Float,
    private val baselineRightHeelY: Float,
    private val raiseRatio: Float = 0.03f,
    private val returnThresholdRatio: Float = 0.12f
) : MotionCounter {

    private var count = 0
    private var isRaised = false // 양발 들림 후 복귀를 기다리는 상태
    private var listener: OnCountListener? = null
    private val minConfidence = 0.4f

    // 쿨다운 (1초)
    private val cooldownInterval = 1000L
    private var lastCountTime = 0L

    override fun setOnCountListener(listener: OnCountListener?) {
        this.listener = listener
    }

    override fun onPoseDetected(pose: Pose) {
        if (count >= maxCount) return

        val leftHeel = pose.getPoseLandmark(PoseLandmark.LEFT_HEEL)
        val rightHeel = pose.getPoseLandmark(PoseLandmark.RIGHT_HEEL)
        if (!isValidLandmark(leftHeel) || !isValidLandmark(rightHeel)) return

        val currentLeftY = leftHeel!!.position.y
        val currentRightY = rightHeel!!.position.y

        if (count == 0) {
            Log.d("HeelRaise", """
            [초기 발 위치]
            Left: $currentLeftY (기준: $baselineLeftHeelY)
            Right: $currentRightY (기준: $baselineRightHeelY)
        """.trimIndent())
        }

        val raiseThreshold = baselineLeftHeelY * raiseRatio
        val returnThreshold = baselineLeftHeelY * returnThresholdRatio

        val leftDiff = baselineLeftHeelY - currentLeftY
        val rightDiff = baselineRightHeelY - currentRightY

        val bothRaised = leftDiff > raiseThreshold && rightDiff > raiseThreshold
        val bothReturned = abs(currentLeftY - baselineLeftHeelY) < returnThreshold &&
                abs(currentRightY - baselineRightHeelY) < returnThreshold

        val currentTime = System.currentTimeMillis()

        when {
            // 1. 복귀 → 들림: 카운트 증가
            !isRaised && bothRaised -> {
                if (currentTime - lastCountTime > cooldownInterval) {
                    count++
                    lastCountTime = currentTime
                    listener?.onCountChanged(count)
                    Log.d("HeelRaise", "카운트 증가: $count")
                } else {
                    Log.d("HeelRaise", "쿨다운 남음: ${cooldownInterval - (currentTime - lastCountTime)}ms")
                }
                isRaised = true
            }
            // 2. 들림 → 복귀: 상태 리셋
            isRaised && bothReturned -> {
                isRaised = false
                Log.d("HeelRaise", "발 복귀 인식")
            }
        }

        Log.d("HeelRaise", """
        [기준] Left: ${baselineLeftHeelY.toInt()}, Right: ${baselineRightHeelY.toInt()}
        [현재] Left: ${currentLeftY.toInt()}, Right: ${currentRightY.toInt()}
        [들림] Left: ${leftDiff.toInt()} > ${raiseThreshold.toInt()}? → ${leftDiff > raiseThreshold}
        [복귀] Left: ${abs(currentLeftY - baselineLeftHeelY).toInt()} < ${returnThreshold.toInt()}? → ${abs(currentLeftY - baselineLeftHeelY) < returnThreshold}
        [상태] ${if (isRaised) "들림 중" else "복귀 상태"}
    """.trimIndent())
    }

    private fun isValidLandmark(landmark: PoseLandmark?): Boolean {
        return landmark?.inFrameLikelihood ?: 0f >= minConfidence
    }

    override fun reset() {
        count = 0
        isRaised = false
        lastCountTime = 0L
        Log.d("HeelRaise", "카운트 리셋: 0")
    }

    override fun getCount(): Int = count
}