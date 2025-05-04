package com.example.capstone_healthcare_app.native

import android.content.Context
import com.example.capstone_healthcare_app.native.NativeCalibrationView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class CalibrationViewFactory(
    private val messenger: BinaryMessenger,
    private val activity: FlutterActivity
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val methodChannel = MethodChannel(
            messenger,
            "com.example.capstone_healthcare_app/calibration_method_channel"
        )
        val eventChannel = EventChannel(
            messenger,
            "com.example.capstone_healthcare_app/calibration_events"
        )

        return NativeCalibrationView(
            activity, // FlutterActivity
            methodChannel, // MethodChannel
            eventChannel, // EventChannel
        )
    }
}