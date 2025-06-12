package com.example.capstone_healthcare_app.motion

import android.util.Log
import com.google.mlkit.vision.pose.Pose
import com.google.mlkit.vision.pose.PoseLandmark
import kotlin.math.abs

class HeelRaiseCounter(
    private val maxCount: Int,
    private val baselineLeftHeelY: Float,
    private val baselineRightHeelY: Float,
    private val baselineLeftEyeY: Float,
    private val baselineRightEyeY: Float,
    private val raiseRatio: Float = 0.01f,
    private val returnThresholdRatio: Float = 0.12f,
    private val eyeRaiseThreshold: Float = 8f
) : MotionCounter {

    private enum class State { IDLE, LIFTED }
    private var state = State.IDLE
    private var lastHeelRaisedTime = 0L

    private var count = 0
    private var listener: OnCountListener? = null
    private val minConfidence = 0.4f
    private val cooldownInterval = 1500L
    private var lastCountTime = 0L

    override fun setOnCountListener(listener: OnCountListener?) {
        this.listener = listener
    }

    override fun onPoseDetected(pose: Pose) {
        if (count >= maxCount) return

        val leftHeel = pose.getPoseLandmark(PoseLandmark.LEFT_HEEL)
        val rightHeel = pose.getPoseLandmark(PoseLandmark.RIGHT_HEEL)
        val leftEye = pose.getPoseLandmark(PoseLandmark.LEFT_EYE)
        val rightEye = pose.getPoseLandmark(PoseLandmark.RIGHT_EYE)
        if (!isValidLandmark(leftHeel) || !isValidLandmark(rightHeel)
            || !isValidLandmark(leftEye) || !isValidLandmark(rightEye)) return

        val currentLeftY = leftHeel!!.position.y
        val currentRightY = rightHeel!!.position.y
        val currentLeftEyeY = leftEye!!.position.y
        val currentRightEyeY = rightEye!!.position.y

        val raiseThreshold = baselineLeftHeelY * raiseRatio
        val returnThreshold = baselineLeftHeelY * returnThresholdRatio

        val leftDiff = baselineLeftHeelY - currentLeftY
        val rightDiff = baselineRightHeelY - currentRightY
        val leftEyeDiff = baselineLeftEyeY - currentLeftEyeY
        val rightEyeDiff = baselineRightEyeY - currentRightEyeY

        val bothHeelsRaised = leftDiff > raiseThreshold && rightDiff > raiseThreshold
        val oneHeelRaised = leftDiff > raiseThreshold || rightDiff > raiseThreshold
        val bothEyesRaised = leftEyeDiff > eyeRaiseThreshold && rightEyeDiff > eyeRaiseThreshold
        val bothReturned = abs(currentLeftY - baselineLeftHeelY) < returnThreshold &&
                abs(currentRightY - baselineRightHeelY) < returnThreshold

        val currentTime = System.currentTimeMillis()

        when (state) {
            State.IDLE -> {
                // 1. 발이 완전히 들렸을 때만 상태 전환
                if ((bothHeelsRaised || (oneHeelRaised && bothEyesRaised))
                    && currentTime - lastCountTime > cooldownInterval) {
                    state = State.LIFTED
                    lastHeelRaisedTime = currentTime
                    Log.d("HeelRaise", "LIFTED 상태 진입 - 발 들림")
                }
            }
            State.LIFTED -> {
                // 2. 발이 완전히 내려오고 쿨다운 시간이 지났을 때만 카운트
                if (bothReturned) {
                    if (currentTime - lastHeelRaisedTime > 300) {  // 최소 0.3초 유지
                        if (currentTime - lastCountTime > cooldownInterval) {
                            count++
                            lastCountTime = currentTime
                            listener?.onCountChanged(count)
                            Log.d("HeelRaise", "카운트 증가: $count")
                        } else {
                            Log.d("HeelRaise", "쿨다운 남음: ${cooldownInterval - (currentTime - lastCountTime)}ms")
                        }
                        state = State.IDLE
                    }
                } else if (currentTime - lastHeelRaisedTime > 8000) {
                    state = State.IDLE
                    Log.d("HeelRaise", "장시간 들림 상태 초기화")
                }
            }
        }

        Log.d("HeelRaise", """
            [상태] ${state.name}
            [발 위치] L: ${currentLeftY.toInt()}, R: ${currentRightY.toInt()}
            [들림] L: ${leftDiff.toInt()} > ${raiseThreshold.toInt()}, R: ${rightDiff.toInt()} > ${raiseThreshold.toInt()}
            [복귀] L: ${abs(currentLeftY - baselineLeftHeelY).toInt()} < ${returnThreshold.toInt()}, R: ${abs(currentRightY - baselineRightHeelY).toInt()} < ${returnThreshold.toInt()}
        """.trimIndent())
    }

    private fun isValidLandmark(landmark: PoseLandmark?): Boolean {
        return landmark?.inFrameLikelihood ?: 0f >= minConfidence
    }

    override fun reset() {
        count = 0
        state = State.IDLE
        lastCountTime = 0L
        Log.d("HeelRaise", "카운트 리셋")
    }

    override fun getCount(): Int = count
}
