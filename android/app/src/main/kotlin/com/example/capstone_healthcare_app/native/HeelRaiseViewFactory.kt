package com.example.capstone_healthcare_app.native

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class HeelRaiseViewFactory(
    private val messenger: BinaryMessenger,
    private val activity: FlutterActivity
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        // creationParams를 NativeHeelRaiseView에 전달
        return NativeHeelRaiseView(
            activity,
            messenger,
            viewId,
            args as? Map<String, Any> // Flutter에서 전달된 creationParams
        )
    }
}