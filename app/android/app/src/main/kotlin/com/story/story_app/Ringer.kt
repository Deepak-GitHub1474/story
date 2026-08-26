package com.story.story_app

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

private val PATTERN = longArrayOf(0, 900, 900)

object Ringer {
    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null

    fun start(context: Context) {
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

        when (audio.ringerMode) {
            AudioManager.RINGER_MODE_SILENT -> return
            AudioManager.RINGER_MODE_VIBRATE -> buzz(context)
            else -> {
                buzz(context)
                play(context)
            }
        }
    }

    fun stop() {
        player?.let {
            if (it.isPlaying) it.stop()
            it.release()
        }
        player = null

        vibrator?.cancel()
        vibrator = null
    }

    private fun play(context: Context) {
        if (player != null) return

        val uri = RingtoneManager.getActualDefaultRingtoneUri(
            context,
            RingtoneManager.TYPE_RINGTONE,
        ) ?: return

        try {
            player = MediaPlayer().apply {
                setDataSource(context, uri)
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                isLooping = true
                prepare()
                start()
            }
        } catch (error: Exception) {
            player = null
        }
    }

    private fun buzz(context: Context) {
        if (vibrator != null) return

        val device = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager =
                context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            manager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

        if (!device.hasVibrator()) return

        device.vibrate(VibrationEffect.createWaveform(PATTERN, 0))
        vibrator = device
    }
}
