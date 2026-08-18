package com.story.story_app

import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val SECURE_CHANNEL = "story/secure_screen"
private const val FILES_CHANNEL = "story/files"
private const val PICK_REQUEST = 8411
private const val NOTIFICATION_CHANNEL = "story_default"

class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        openNotificationChannel()
    }

    private fun openNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL,
            "Story",
            NotificationManager.IMPORTANCE_HIGH,
        )
        channel.description = "Likes, comments, replies, follows and messages."
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enable" -> {
                        window.setFlags(
                            WindowManager.LayoutParams.FLAG_SECURE,
                            WindowManager.LayoutParams.FLAG_SECURE,
                        )
                        result.success(null)
                    }
                    "disable" -> {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILES_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pick" -> pick(call.argument<List<String>>("mimeTypes"), result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun pick(mimeTypes: List<String>?, result: MethodChannel.Result) {
        if (pending != null) {
            result.error("busy", "A picker is already open.", null)
            return
        }
        pending = result

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            if (!mimeTypes.isNullOrEmpty()) {
                putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes.toTypedArray())
            }
        }

        try {
            startActivityForResult(intent, PICK_REQUEST)
        } catch (error: Exception) {
            pending = null
            result.error("unavailable", "No file picker on this device.", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != PICK_REQUEST) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }

        val result = pending
        pending = null
        if (result == null) return

        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }

        try {
            result.success(mapOf("name" to displayName(uri), "bytes" to readBytes(uri)))
        } catch (error: Exception) {
            result.error("unreadable", "That file could not be read.", null)
        }
    }

    private fun displayName(uri: Uri): String {
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val column = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (column >= 0 && cursor.moveToFirst()) {
                return cursor.getString(column)
            }
        }
        return uri.lastPathSegment ?: "file"
    }

    private fun readBytes(uri: Uri): ByteArray =
        contentResolver.openInputStream(uri)?.use { it.readBytes() }
            ?: throw IllegalStateException("Could not open $uri")
}
