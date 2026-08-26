package com.story.story_app

import android.app.Activity
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.PowerManager

object CallAudio {
    private var focus: AudioFocusRequest? = null
    private var previousMode = AudioManager.MODE_NORMAL
    private var proximity: PowerManager.WakeLock? = null

    private fun audio(context: Context) =
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    fun start(activity: Activity) {
        val manager = audio(activity)
        previousMode = manager.mode

        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = AudioFocusRequest
                .Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
                .setAudioAttributes(attributes)
                .build()
            manager.requestAudioFocus(request)
            focus = request
        } else {
            @Suppress("DEPRECATION")
            manager.requestAudioFocus(
                null,
                AudioManager.STREAM_VOICE_CALL,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE,
            )
        }

        manager.mode = AudioManager.MODE_IN_COMMUNICATION
        manager.isSpeakerphoneOn = false

        activity.volumeControlStream = AudioManager.STREAM_VOICE_CALL
        activity.window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        holdProximity(activity)
    }

    fun stop(activity: Activity) {
        val manager = audio(activity)

        manager.isSpeakerphoneOn = false
        manager.mode = previousMode

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focus?.let { manager.abandonAudioFocusRequest(it) }
            focus = null
        } else {
            @Suppress("DEPRECATION")
            manager.abandonAudioFocus(null)
        }

        activity.volumeControlStream = AudioManager.USE_DEFAULT_STREAM_TYPE
        activity.window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        releaseProximity()
    }

    fun setSpeaker(context: Context, on: Boolean) {
        val manager = audio(context)
        manager.mode = AudioManager.MODE_IN_COMMUNICATION
        manager.isSpeakerphoneOn = on
        if (on) releaseProximity()
    }

    fun isSpeakerOn(context: Context): Boolean = audio(context).isSpeakerphoneOn

    private fun holdProximity(context: Context) {
        if (proximity != null) return

        val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        if (!power.isWakeLockLevelSupported(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK)) return

        val lock = power.newWakeLock(
            PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK,
            "story:call",
        )
        lock.setReferenceCounted(false)
        lock.acquire(60 * 60 * 1000L)
        proximity = lock
    }

    private fun releaseProximity() {
        proximity?.let { if (it.isHeld) it.release() }
        proximity = null
    }
}
