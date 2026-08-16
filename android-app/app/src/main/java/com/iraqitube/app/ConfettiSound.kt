package com.iraqitube.app

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer

object ConfettiSound {
    fun play(context: Context) {
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        if (audio?.ringerMode == AudioManager.RINGER_MODE_SILENT) return
        runCatching {
            MediaPlayer.create(context.applicationContext, R.raw.confetti)?.apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                setOnCompletionListener { player ->
                    player.reset()
                    player.release()
                }
                setVolume(0.85f, 0.85f)
                start()
            }
        }
    }
}
