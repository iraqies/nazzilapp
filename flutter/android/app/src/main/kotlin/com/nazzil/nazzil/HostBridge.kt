package com.nazzil.nazzil

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel

object HostBridge {
    @Volatile
    var channel: MethodChannel? = null

    fun emit(method: String) {
        val target = channel ?: return
        Handler(Looper.getMainLooper()).post {
            target.invokeMethod(method, null)
        }
    }
}
