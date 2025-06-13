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

    fun transposeX(x: Float): Float = xOffset + x * scale
    fun transposeY(y: Float): Float = yOffset + y * scale
}
