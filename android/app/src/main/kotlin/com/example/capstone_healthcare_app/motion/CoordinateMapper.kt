package com.example.capstone_healthcare_app.motion

class CoordinateMapper(
    cameraWidth: Float,
    cameraHeight: Float,
    private val screenWidth: Float,
    private val screenHeight: Float,
    private val rotationDegrees: Int = 0
) {
    private val scale: Float = minOf(screenWidth / cameraWidth, screenHeight / cameraHeight)
    private val xOffset: Float = (screenWidth - (cameraWidth * scale)) / 2
    private val yOffset: Float = (screenHeight - (cameraHeight * scale)) / 2

    fun transposeX(x: Float): Float {
        return when (rotationDegrees) {
            90 -> screenWidth - (yOffset + x * scale)
            270 -> yOffset + x * scale
            else -> xOffset + x * scale
        }
    }

    fun transposeY(y: Float): Float {
        return when (rotationDegrees) {
            90 -> xOffset + y * scale
            270 -> screenWidth - (xOffset + y * scale)
            else -> yOffset + y * scale
        }
    }
}

