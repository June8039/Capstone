package com.example.capstone_healthcare_app.motion

import android.util.Log
import com.google.mlkit.vision.pose.Pose
import com.google.mlkit.vision.pose.PoseLandmark
import kotlin.math.abs
import kotlin.math.max

class SquatCounter(private val maxCount: Int) : MotionCounter {
    private var squatCount = 0
    private var wasSquatting = false
    private var fullyStood = true
    private var listener: OnCountListener? = null

    private var baselineDistance: Float? = null
    private var initializationStartTime: Long = 0
    private val initializationDuration = 5000L // 5초
    private val distanceSamples = mutableListOf<Float>()

    private val squatThresholdRatio = 0.6f
    private val standThresholdRatio = 0.9f

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

        val leftHipToKnee = abs(leftHip.position.y - leftKnee.position.y)
        val rightHipToKnee = abs(rightHip.position.y - rightKnee.position.y)
        val currentDistance = (leftHipToKnee + rightHipToKnee) / 2

        if (baselineDistance == null) {
            if (initializationStartTime == 0L) {
                initializationStartTime = System.currentTimeMillis()
                Log.d("SquatCounter", "기준값 측정 시작")
            }

            val elapsedTime = System.currentTimeMillis() - initializationStartTime
            if (elapsedTime < initializationDuration) {
                distanceSamples.add(currentDistance)
                Log.d("SquatCounter", "기준값 측정 중(${elapsedTime / 1000}초)")
                return
            } else {
                baselineDistance = distanceSamples.average().toFloat()
                Log.d("SquatCounter", "기준값 설정 완료: ${"%.1f".format(baselineDistance)}px")
            }
        }

        val squatThreshold = baselineDistance!! * squatThresholdRatio
        val standThreshold = baselineDistance!! * standThresholdRatio

        val isSquatting = currentDistance < squatThreshold
        val isStanding = currentDistance > standThreshold

        val areArmsExtended = areArmsExtendedForward(pose)

        val countCondition = !wasSquatting && isSquatting && fullyStood && areArmsExtended

        if (countCondition) {
            squatCount++
            listener?.onCountChanged(squatCount)
            fullyStood = false
            Log.d("SquatCounter", """
                카운트 증가: $squatCount
                [현재] ${"%.1f".format(currentDistance)}px 
                [임계값] ${"%.1f".format(squatThreshold)}px
            """.trimIndent())
        } else {
            Log.d("SquatCounter", """
                카운트 실패 사유:
                ${if (baselineDistance == null) "기준값 측정 미완료" else ""}
                ${if (wasSquatting) "이미 앉은 상태에서 시작" else ""}
                ${if (!isSquatting) "스쿼트 깊이 부족 (${"%.1f".format(currentDistance)}px > ${"%.1f".format(squatThreshold)}px)" else ""}
                ${if (!fullyStood) "완전히 일어서지 않음 (${"%.1f".format(currentDistance)}px < ${"%.1f".format(standThreshold)}px)" else ""}
                ${if (!areArmsExtended) "팔을 앞으로 뻗지 않음" else ""}
            """.trimIndent().replace(Regex("\\s+\n"), "\n"))
        }

        wasSquatting = isSquatting
        if (isStanding) fullyStood = true

        Log.d("SquatCounter", """
            [상태] ${if (isSquatting) "앉음" else "서있음"}
            [거리] 현재: ${"%.1f".format(currentDistance)}px / 기준: ${"%.1f".format(baselineDistance!!)}px
            [임계값] 앉음: ${"%.1f".format(squatThreshold)}px / 일어섬: ${"%.1f".format(standThreshold)}px
            [팔 상태] ${if (areArmsExtended) "앞으로 뻗음" else "미확인"}
        """.trimIndent())
    }

    // 팔이 앞으로 뻗었는지 단순히 손목이 어깨보다 위에 있는지로 확인
    private fun areArmsExtendedForward(pose: Pose): Boolean {
        val leftWrist = pose.getPoseLandmark(PoseLandmark.LEFT_WRIST)
        val leftShoulder = pose.getPoseLandmark(PoseLandmark.LEFT_SHOULDER)
        val rightWrist = pose.getPoseLandmark(PoseLandmark.RIGHT_WRIST)
        val rightShoulder = pose.getPoseLandmark(PoseLandmark.RIGHT_SHOULDER)

        if (leftWrist == null || leftShoulder == null || rightWrist == null || rightShoulder == null) return false

        val leftExtended = leftWrist.position.y < leftShoulder.position.y
        val rightExtended = rightWrist.position.y < rightShoulder.position.y

        return leftExtended && rightExtended
    }

    override fun reset() {
        squatCount = 0
        wasSquatting = false
        fullyStood = true
        baselineDistance = null
        initializationStartTime = 0
        distanceSamples.clear()
        Log.d("SquatCounter", "카운트 리셋: 기준값 초기화됨")
    }

    override fun getCount(): Int = squatCount
}
