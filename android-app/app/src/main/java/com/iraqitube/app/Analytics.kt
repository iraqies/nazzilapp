package com.iraqitube.app

import android.content.Context
import android.os.Bundle
import android.util.Log
import com.google.firebase.FirebaseApp
import com.google.firebase.analytics.FirebaseAnalytics

object Analytics {
    private const val TAG = "NazzilAnalytics"
    private var analytics: FirebaseAnalytics? = null

    fun start(context: Context) {
        val app = context.applicationContext
        runCatching { FirebaseApp.initializeApp(app) }
            .onFailure { Log.e(TAG, "firebase init failed", it) }
        val instance = runCatching { FirebaseAnalytics.getInstance(app) }.getOrNull()
        if (instance == null) {
            Log.e(TAG, "firebase analytics missing")
            return
        }
        instance.setAnalyticsCollectionEnabled(true)
        analytics = instance
        instance.logEvent(FirebaseAnalytics.Event.APP_OPEN, null)
        event("nazzil_open")
    }

    fun videoSaved(platform: String, quality: String) {
        event(
            "video_saved",
            FirebaseAnalytics.Param.CONTENT_TYPE to platform,
            FirebaseAnalytics.Param.ITEM_VARIANT to quality,
        )
    }

    fun event(name: String, vararg params: Pair<String, String>) {
        val bundle = Bundle()
        params.forEach { (key, value) ->
            if (value.isNotBlank()) bundle.putString(key, value.take(100))
        }
        val instance = analytics
        if (instance == null) {
            Log.w(TAG, "drop $name — analytics not ready")
            return
        }
        instance.logEvent(name, bundle)
        Log.i(TAG, "logged $name")
    }
}
