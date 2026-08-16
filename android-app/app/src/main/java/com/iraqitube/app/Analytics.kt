package com.iraqitube.app

import android.content.Context
import android.os.Bundle
import com.google.firebase.analytics.FirebaseAnalytics

object Analytics {
    private var analytics: FirebaseAnalytics? = null

    fun start(context: Context) {
        analytics = FirebaseAnalytics.getInstance(context.applicationContext)
        event("app_open")
    }

    fun videoSaved(platform: String, quality: String) {
        event(
            "video_saved",
            "platform" to platform,
            "quality" to quality,
        )
    }

    fun event(name: String, vararg params: Pair<String, String>) {
        val bundle = Bundle()
        params.forEach { (key, value) -> bundle.putString(key, value) }
        analytics?.logEvent(name, bundle)
    }
}
