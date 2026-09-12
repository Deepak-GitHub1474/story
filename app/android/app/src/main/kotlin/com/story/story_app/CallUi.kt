package com.story.story_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

const val CALL_CHANNEL = "story_calls_v2"
const val ONGOING_CHANNEL = "story_call_ongoing_v2"
const val CALL_NOTIFICATION = 9411
const val EXTRA_CALL_ID = "call_id"
const val EXTRA_CALL_ACTION = "call_action"

object CallUi {
    fun openChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = context.getSystemService(NotificationManager::class.java)
        manager.deleteNotificationChannel("story_calls")
        manager.deleteNotificationChannel("story_call_ongoing")

        val ongoing = NotificationChannel(
            ONGOING_CHANNEL,
            "Ongoing calls",
            NotificationManager.IMPORTANCE_LOW,
        )
        ongoing.description = "Shown while a call is connected."
        ongoing.setSound(null, null)
        ongoing.enableVibration(false)
        ongoing.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        manager.createNotificationChannel(ongoing)

        val channel = NotificationChannel(
            CALL_CHANNEL,
            "Calls",
            NotificationManager.IMPORTANCE_HIGH,
        )
        channel.description = "Someone is calling you."
        channel.setSound(null, null)
        channel.enableVibration(false)
        channel.lockscreenVisibility = Notification.VISIBILITY_PUBLIC

        manager.createNotificationChannel(channel)
    }

    fun ring(context: Context, callId: String, caller: String) {
        openChannel(context)
        Ringer.start(context)

        val notification = Notification.Builder(context, CALL_CHANNEL)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(caller)
            .setContentText("Incoming call")
            .setCategory(Notification.CATEGORY_CALL)
            .setOngoing(true)
            .setAutoCancel(false)
            .setFullScreenIntent(open(context, callId, "show"), true)
            .setContentIntent(open(context, callId, "show"))
            .addAction(
                Notification.Action.Builder(
                    null,
                    "Decline",
                    open(context, callId, "decline"),
                ).build(),
            )
            .addAction(
                Notification.Action.Builder(
                    null,
                    "Answer",
                    open(context, callId, "answer"),
                ).build(),
            )
            .build()

        context.getSystemService(NotificationManager::class.java)
            .notify(CALL_NOTIFICATION, notification)
    }

    fun hideRingNotification(context: Context) {
        context.getSystemService(NotificationManager::class.java)
            .cancel(CALL_NOTIFICATION)
    }

    fun stopRinging(context: Context) {
        Ringer.stop()
        context.getSystemService(NotificationManager::class.java)
            .cancel(CALL_NOTIFICATION)
    }

    private fun open(context: Context, callId: String, action: String): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(EXTRA_CALL_ID, callId)
            putExtra(EXTRA_CALL_ACTION, action)
        }

        return PendingIntent.getActivity(
            context,
            action.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
