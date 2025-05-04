package com.example.capstone_healthcare_app.native

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.embedding.android.FlutterActivity

class SquatViewFactory(
    private val messenger: BinaryMessenger,
    private val activity: FlutterActivity
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return NativeSquatView(activity, messenger, viewId)
    }
}
