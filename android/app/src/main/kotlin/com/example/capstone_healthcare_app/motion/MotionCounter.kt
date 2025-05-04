package com.example.capstone_healthcare_app.motion

import com.google.mlkit.vision.pose.Pose

interface MotionCounter {
    fun setOnCountListener(listener: OnCountListener?)
    fun onPoseDetected(pose: Pose)
    fun reset()
    fun getCount(): Int
}
