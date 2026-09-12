package com.story.story_app

import android.content.Context
import android.util.Log
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

private const val TAG = "StoryRinger"

private val PATTERN = longArrayOf(0, 900, 900)

object Ringer {
    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var ringback: MediaPlayer? = null

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

    fun startRingback(context: Context) {
        if (ringback != null) return

        val uri = RingtoneManager.getActualDefaultRingtoneUri(
            context,
            RingtoneManager.TYPE_RINGTONE,
        )
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

        if (uri == null) {
            Log.w(TAG, "no ringtone on this device, ringback skipped")
            return
        }

        try {
            ringback = MediaPlayer().apply {
                setDataSource(context, uri)
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                isLooping = true
                setVolume(1.0f, 1.0f)
                prepare()
                start()
            }
            Log.i(TAG, "ringback started from $uri")
        } catch (error: Exception) {
            Log.w(TAG, "ringback failed: ${error.message}")
            ringback = null
        }
    }

    fun stopRingback() {
        ringback?.let {
            if (it.isPlaying) it.stop()
            it.release()
        }
        ringback = null
    }

    fun stop() {
        stopRingback()
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
