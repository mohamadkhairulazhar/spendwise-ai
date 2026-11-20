package my.spendwise.spendwise_ai.capture

import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.service.notification.NotificationListenerService
import java.util.concurrent.Executors

/** No Flutter engine and no foreground service are required to use this runtime. */
object CaptureRuntime {
    val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var inbox: CaptureStore? = null
    @Volatile var listenerConnected = false
    @Volatile var onChanged: (() -> Unit)? = null

    @Synchronized
    fun store(context: Context): CaptureStore =
        inbox ?: CaptureStore(context.applicationContext).also { inbox = it }

    fun permissionGranted(context: Context): Boolean {
        val component = ComponentName(context, SpendWiseNotificationListener::class.java)
        return if (Build.VERSION.SDK_INT >= 27) {
            context
                .getSystemService(NotificationManager::class.java)
                .isNotificationListenerAccessGranted(component)
        } else {
            Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners")
                ?.split(':')
                ?.any { ComponentName.unflattenFromString(it) == component } == true
        }
    }

    fun reconnect(context: Context) {
        if (permissionGranted(context) && store(context).settings()["enabled"] == true) {
            try {
                NotificationListenerService.requestRebind(
                    ComponentName(context, SpendWiseNotificationListener::class.java)
                )
            } catch (_: Exception) {
                failure(context, "listener_rebind_failed")
            }
        }
    }

    fun failure(context: Context, code: String, notify: Boolean = true) {
        val prefs = context.getSharedPreferences("capture_diagnostics", Context.MODE_PRIVATE)
        prefs
            .edit()
            .putString("lastError", code)
            .putLong("lastErrorAt", System.currentTimeMillis())
            .putLong("failures", prefs.getLong("failures", 0) + 1)
            .commit()
        if (notify) signal()
    }

    fun diagnostics(context: Context): Map<String, Any?> {
        val prefs = context.getSharedPreferences("capture_diagnostics", Context.MODE_PRIVATE)
        return mapOf(
            "lastError" to prefs.getString("lastError", null),
            "lastErrorAt" to prefs.getLong("lastErrorAt", 0),
            "failures" to prefs.getLong("failures", 0),
        )
    }

    fun signal() {
        main.post { onChanged?.invoke() }
    }
}
