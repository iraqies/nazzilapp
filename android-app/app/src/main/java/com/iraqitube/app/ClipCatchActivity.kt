package com.iraqitube.app

import android.app.Activity
import android.content.Intent
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView

class ClipCatchActivity : Activity() {
    private var handled = false

    override fun attachBaseContext(newBase: android.content.Context) {
        super.attachBaseContext(SettingsStore.wrap(newBase))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        overridePendingTransition(0, 0)
        window.setBackgroundDrawableResource(android.R.color.transparent)
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (!hasFocus || handled) return
        handled = true
        if (!SettingsStore(this).watchClipboard) {
            finishQuiet()
            return
        }
        ClipLog.write(this, "catcher focused")
        tryOffer(0)
    }

    private fun tryOffer(attempt: Int) {
        val link = ClipWatch.readSupportedLink(this)
        ClipLog.write(this, "catcher attempt=$attempt link='$link'")
        if (link.isNotBlank()) {
            if (!ClipWatch.shouldShow(this, link)) {
                finishQuiet()
                return
            }
            setContentView(card(link))
            return
        }
        if (attempt >= 6) {
            finishQuiet()
            return
        }
        window.decorView.postDelayed({ tryOffer(attempt + 1) }, 120)
    }

    override fun finish() {
        super.finish()
        overridePendingTransition(0, 0)
    }

    private fun finishQuiet() {
        finish()
    }

    private fun card(link: String): FrameLayout {
        val title = TextView(this).apply {
            text = getString(R.string.clip_prompt_title)
            setTextColor(0xFFF7F1F4.toInt())
            textSize = 18f
            typeface = Typeface.DEFAULT_BOLD
        }
        val body = TextView(this).apply {
            text = getString(R.string.clip_prompt_body, Downloader.platformOf(link))
            setTextColor(0xFFB5A8B4.toInt())
            textSize = 14f
            setPadding(0, dp(8), 0, dp(8))
        }
        val url = TextView(this).apply {
            text = link
            setTextColor(0xFFF7F1F4.toInt())
            textSize = 12f
            maxLines = 3
        }
        val yes = TextView(this).apply {
            text = getString(R.string.yes)
            setTextColor(0xFFFFFFFF.toInt())
            textSize = 16f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(dp(16), dp(14), dp(16), dp(14))
            background = rounded(0xFFFF4D8D.toInt(), dp(22).toFloat())
            setOnClickListener {
                startActivity(
                    Intent(this@ClipCatchActivity, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP
                        putExtra(Intent.EXTRA_TEXT, link)
                    },
                )
                finishQuiet()
            }
        }
        val no = TextView(this).apply {
            text = getString(R.string.no)
            setTextColor(0xFFB5A8B4.toInt())
            gravity = Gravity.CENTER
            setPadding(0, dp(12), 0, 0)
            setOnClickListener { finishQuiet() }
        }
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(20), dp(20), dp(16))
            background = rounded(0xFF1A1320.toInt(), dp(28).toFloat())
            addView(title)
            addView(body)
            addView(url)
            addView(
                yes,
                LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                ).apply { topMargin = dp(16) },
            )
            addView(no)
        }
        return FrameLayout(this).apply {
            setBackgroundColor(0x99000000.toInt())
            setPadding(dp(20), dp(20), dp(20), dp(20))
            setOnClickListener { finishQuiet() }
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
    }

    private fun rounded(color: Int, radius: Float) = GradientDrawable().apply {
        shape = GradientDrawable.RECTANGLE
        setColor(color)
        cornerRadius = radius
    }

    private fun dp(value: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            resources.displayMetrics,
        ).toInt()
    }
}
