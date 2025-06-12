package com.example.capstone_healthcare_app

import android.media.MediaRecorder
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import com.example.capstone_healthcare_app.native.CalibrationViewFactory
import com.example.capstone_healthcare_app.native.SquatViewFactory
import com.example.capstone_healthcare_app.native.HeelRaiseViewFactory
import java.io.File

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.example.capstone_healthcare_app/heel_raise"
    private var mediaRecorder: MediaRecorder? = null
    private var outputFilePath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 기존 플랫폼뷰 팩토리 등록
        flutterEngine.platformViewsController.registry.apply {
            registerViewFactory(
                "NativeCalibrationView",
                CalibrationViewFactory(
                    flutterEngine.dartExecutor.binaryMessenger,
                    this@MainActivity
                )
            )
            registerViewFactory(
                "NativeHeelRaiseView",
                HeelRaiseViewFactory(
                    flutterEngine.dartExecutor.binaryMessenger,
                    this@MainActivity
                )
            )
            registerViewFactory(
                "NativeSquatView",
                SquatViewFactory(
                    flutterEngine.dartExecutor.binaryMessenger,
                    this@MainActivity
                )
            )
        }
    }
}
