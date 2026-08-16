package com.iraqitube.app

import android.app.Application
import android.content.Context
import android.content.Intent
import android.util.Log
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL

class IraqiTubeApp : Application() {
    @Volatile
    var engineReady: Boolean = false
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
        Thread {
            try {
                YoutubeDL.getInstance().init(this)
                FFmpeg.getInstance().init(this)
                try {
                    YoutubeDL.getInstance().updateYoutubeDL(this, YoutubeDL.UpdateChannel.NIGHTLY)
                } catch (updateError: Exception) {
                    Log.w(TAG, "yt-dlp update skipped", updateError)
                }
                engineReady = true
            } catch (error: Exception) {
                engineError = error.message
                Log.e(TAG, "engine init failed", error)
            }
        }.start()
    }

    companion object {
        private const val TAG = "IraqiTube"
    }
}
