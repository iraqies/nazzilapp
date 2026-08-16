package com.iraqitube.app

import android.app.Application
import android.content.Context
import android.content.Intent

class IraqiTubeApp : Application() {
    @Volatile
    var engineReady: Boolean = true
        private set

    @Volatile
    var engineError: String? = null
        private set

    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(SettingsStore.wrap(base))
    }

    override fun onCreate() {
        super.onCreate()
        Analytics.start(this)
        SettingsStore(this).applyLocale()
        runCatching {
            stopService(Intent().setClassName(this, "com.iraqitube.app.ClipWatchService"))
        }
    }
}
