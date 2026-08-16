package com.iraqitube.app

import android.content.Context
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager

object OverlayFocus {
    private val main = Handler(Looper.getMainLooper())

    fun grab(context: Context, onResult: (String) -> Unit) {
        val app = context.applicationContext
        val windowManager = app.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val probe = View(app).apply {
            isFocusable = true
            isFocusableInTouchMode = true
        }
        val type = if (Build.VERSION.SDK_INT >= 26) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val params = WindowManager.LayoutParams(
            1,
            1,
            type,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 0
            y = 0
            title = "nazzil-clip"
        }
        var finished = false
        fun done(link: String) {
            if (finished) return
            finished = true
            if (probe.isAttachedToWindow) {
                runCatching { windowManager.removeView(probe) }
            }
            onResult(link)
        }
        probe.viewTreeObserver.addOnWindowFocusChangeListener { hasFocus ->
            if (hasFocus) {
                probe.post {
                    val link = ClipWatch.readSupportedLink(app)
                    if (link.isNotBlank()) done(link)
                }
            }
        }
        val added = runCatching { windowManager.addView(probe, params) }
        if (added.isFailure) {
            android.util.Log.e("NazzilClip", "focus probe failed", added.exceptionOrNull())
            onResult("")
            return
        }
        probe.post {
            probe.requestFocus()
            val link = ClipWatch.readSupportedLink(app)
            if (link.isNotBlank()) done(link)
        }
        main.postDelayed({
            val link = ClipWatch.readSupportedLink(app)
            done(link)
        }, 450)
    }
}
