package com.story.story_app

import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

private const val ONGOING_NOTIFICATION = 9412
private const val EXTRA_PEER = "peer"
private const val EXTRA_ID = "callId"

class CallService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val peer = intent?.getStringExtra(EXTRA_PEER) ?: "Call in progress"
        val callId = intent?.getStringExtra(EXTRA_ID) ?: ""
        CallUi.openChannel(this)

        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra(EXTRA_CALL_ID, callId)
                putExtra(EXTRA_CALL_ACTION, "show")
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = Notification.Builder(this, ONGOING_CHANNEL)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(peer)
            .setContentText("Ongoing call")
            .setCategory(Notification.CATEGORY_CALL)
            .setOngoing(true)
            .setContentIntent(open)
            .addAction(
                Notification.Action.Builder(null, "Leave call", hangUp(callId)).build(),
            )
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                ONGOING_NOTIFICATION,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
            )
        } else {
            startForeground(ONGOING_NOTIFICATION, notification)
        }

        return START_NOT_STICKY
    }

    private fun hangUp(callId: String): PendingIntent = PendingIntent.getActivity(
        this,
        "hangup".hashCode(),
        Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(EXTRA_CALL_ID, callId)
            putExtra(EXTRA_CALL_ACTION, "hangup")
        },
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    override fun onDestroy() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    companion object {
        fun start(context: Context, peer: String, callId: String) {
            val intent = Intent(context, CallService::class.java)
                .putExtra(EXTRA_PEER, peer)
                .putExtra(EXTRA_ID, callId)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, CallService::class.java))
        }
    }
}
