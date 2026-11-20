package my.spendwise.spendwise_ai.capture

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

open class SpendWiseNotificationListener : NotificationListenerService() {
    protected open fun captureStore(): CaptureStore = CaptureRuntime.store(applicationContext)

    override fun onListenerConnected() {
        CaptureRuntime.listenerConnected = true
        CaptureRuntime.signal()
        // Only call activeNotifications once Android has connected the listener.
        // This recovers still-visible events, not notifications missed/dismissed by Android.
        try {
            activeNotifications?.forEach(::onNotificationPosted)
        } catch (_: Exception) {
            CaptureRuntime.failure(this, "active_notifications_unavailable")
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (!FinancialSources.applications.containsKey(sbn.packageName)) return
        val context = applicationContext
        CaptureRuntime.executor.execute {
            try {
                val store = captureStore()
                // Do not even read notification text for unselected applications.
                if (!store.accepts(sbn.packageName)) return@execute
                val n = sbn.notification
                val extras = n.extras
                val text =
                    buildList {
                            extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.let(::add)
                            extras
                                .getCharSequence(Notification.EXTRA_BIG_TEXT)
                                ?.toString()
                                ?.let(::add)
                            extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)?.forEach {
                                add(it.toString())
                            }
                        }
                        .distinct()
                        .joinToString("\n")
                val event =
                    CapturePayload(
                        sbn.packageName,
                        sbn.key,
                        sbn.id,
                        sbn.tag,
                        sbn.groupKey,
                        sbn.postTime,
                        extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: "",
                        text,
                        n.flags and Notification.FLAG_GROUP_SUMMARY != 0,
                        n.`when`,
                    )
                if (store.capture(event) != null) {
                    // The SQLite transaction has committed before Flutter is signalled.
                    CaptureRuntime.signal()
                }
            } catch (_: Exception) {
                // No exception messages, packages, titles, bodies or credentials in logs.
                CaptureRuntime.failure(context, "capture_write_failed")
            }
        }
    }

    override fun onListenerDisconnected() {
        CaptureRuntime.listenerConnected = false
        CaptureRuntime.signal()
        CaptureRuntime.executor.execute { CaptureRuntime.reconnect(applicationContext) }
    }

    override fun onDestroy() {
        CaptureRuntime.listenerConnected = false
        CaptureRuntime.signal()
        super.onDestroy()
    }
}
