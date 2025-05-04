package com.example.capstone_healthcare_app

import com.example.capstone_healthcare_app.native.CalibrationViewFactory
import com.example.capstone_healthcare_app.native.SquatViewFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine


class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        flutterEngine.platformViewsController.registry.apply {
            //캘리브레이션 뷰
            registerViewFactory(
                "NativeCalibrationView",
                CalibrationViewFactory(
                    flutterEngine.dartExecutor.binaryMessenger,
                    this@MainActivity
                )
            )
            //발 뒤꿈치 들기 뷰
            registerViewFactory(
                "NativeHeelRaiseView",
                SquatViewFactory(
                    flutterEngine.dartExecutor.binaryMessenger,
                    this@MainActivity
                )
            )
            //스쿼트 뷰
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
