package com.iraqitube.app

import android.content.Context
import android.util.Log
import java.io.File

object ClipLog {
    private const val TAG = "NazzilClip"

    fun write(context: Context, message: String) {
        Log.e(TAG, message)
        runCatching {
            val file = File(context.applicationContext.filesDir, "clip.log")
            file.appendText("${System.currentTimeMillis()} $message\n")
        }
    }
}
