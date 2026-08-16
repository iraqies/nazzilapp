package com.iraqitube.app

import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.util.TypedValue
import android.view.Gravity
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import android.view.View

object OverlayPrompt {
    private var card: View? = null

    fun show(context: Context, link: String) {
        hide(context)
        val app = context.applicationContext
        val windowManager = app.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val title = TextView(app).apply {
            text = app.getString(R.string.clip_prompt_title)
            setTextColor(0xFFF7F1F4.toInt())
            textSize = 18f
            typeface = Typeface.DEFAULT_BOLD
        }
        val body = TextView(app).apply {
            text = app.getString(R.string.clip_prompt_body, Downloader.platformOf(link))
            setTextColor(0xFFB5A8B4.toInt())
            textSize = 14f
            setPadding(0, dp(app, 8), 0, dp(app, 8))
        }
        val url = TextView(app).apply {
            text = link
            setTextColor(0xFFF7F1F4.toInt())
            textSize = 12f
            maxLines = 3
        }
        val yes = TextView(app).apply {
            text = app.getString(R.string.yes)
            setTextColor(0xFFFFFFFF.toInt())
            textSize = 16f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(dp(app, 16), dp(app, 14), dp(app, 16), dp(app, 14))
            background = rounded(0xFFFF4D8D.toInt(), dp(app, 22).toFloat())
            setOnClickListener {
                hide(app)
                app.startActivity(
                    Intent(app, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP
                        putExtra(Intent.EXTRA_TEXT, link)
                    },
                )
            }
        }
        val no = TextView(app).apply {
            text = app.getString(R.string.no)
            setTextColor(0xFFB5A8B4.toInt())
            gravity = Gravity.CENTER
            setPadding(0, dp(app, 12), 0, 0)
            setOnClickListener { hide(app) }
        }
        val column = LinearLayout(app).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(app, 20), dp(app, 20), dp(app, 20), dp(app, 16))
            background = rounded(0xFF1A1320.toInt(), dp(app, 28).toFloat())
            addView(title)
            addView(body)
            addView(url)
            addView(
                yes,
                LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                ).apply { topMargin = dp(app, 16) },
            )
            addView(no)
        }
        val wrap = FrameLayout(app).apply {
            setBackgroundColor(0x99000000.toInt())
            setPadding(dp(app, 20), dp(app, 20), dp(app, 20), dp(app, 20))
            setOnClickListener { hide(app) }
            addView(
                column,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    Gravity.CENTER,
                ),
            )
            column.setOnClickListener { }
        }
        val type = if (Build.VERSION.SDK_INT >= 26) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        )
        card = wrap
        runCatching { windowManager.addView(wrap, params) }
            .onFailure { android.util.Log.e("NazzilClip", "overlay show failed", it) }
    }

    fun hide(context: Context) {
        val view = card ?: return
        val windowManager = context.applicationContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        if (view.isAttachedToWindow) {
            runCatching { windowManager.removeView(view) }
        }
        card = null
    }

    private fun rounded(color: Int, radius: Float) = GradientDrawable().apply {
        shape = GradientDrawable.RECTANGLE
        setColor(color)
        cornerRadius = radius
    }

    private fun dp(context: Context, value: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            context.resources.displayMetrics,
        ).toInt()
    }
}
