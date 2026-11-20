package my.spendwise.spendwise_ai.capture

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** UI transport only: the listener does not depend on this channel existing. */
class CaptureBridge(private val activity: Activity, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val methods = MethodChannel(messenger, "spendwise/notification_capture")
    private val events = EventChannel(messenger, "spendwise/notification_capture_changes")
    private val main = Handler(Looper.getMainLooper())
    private var active = true

    init {
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "openAccessSettings") {
            try {
                activity.startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                result.success(null)
            } catch (_: ActivityNotFoundException) {
                result.error(
                    "settings_unavailable",
                    "Open Notification Access in Android settings.",
                    null,
                )
            }
            return
        }
        if (
            call.method !in
                setOf("snapshot", "configure", "history", "content", "eraseContent", "reconnect")
        ) {
            result.notImplemented()
            return
        }
        CaptureRuntime.executor.execute {
            try {
                val store = CaptureRuntime.store(activity.applicationContext)
                val value: Any? =
                    when (call.method) {
                        "snapshot" ->
                            store.settings() +
                                mapOf(
                                    "permissionGranted" to
                                        CaptureRuntime.permissionGranted(activity),
                                    "listenerConnected" to CaptureRuntime.listenerConnected,
                                    "diagnostics" to CaptureRuntime.diagnostics(activity),
                                    "sources" to
                                        FinancialSources.applications.map { (pkg, name) ->
                                            mapOf("packageName" to pkg, "name" to name)
                                        },
                                )
                        "configure" -> {
                            val enabled =
                                call.argument<Boolean>("enabled") ?: error("enabled required")
                            val packages =
                                call.argument<List<String>>("packages")
                                    ?: error("packages required")
                            val days =
                                call.argument<Int>("retentionDays") ?: error("retention required")
                            store.configure(enabled, packages, days)
                            CaptureRuntime.reconnect(activity)
                            CaptureRuntime.signal()
                            null
                        }
                        "history" ->
                            store.history(
                                call.argument<Number>("before")?.toLong() ?: Long.MAX_VALUE
                            )
                        "content" ->
                            store.content(
                                call.argument<String>("eventId") ?: error("event ID required")
                            )
                        "eraseContent" -> {
                            store.eraseContent(call.argument<String>("eventId"))
                            CaptureRuntime.signal()
                            null
                        }
                        "reconnect" -> {
                            CaptureRuntime.reconnect(activity)
                            null
                        }
                        else -> null
                    }
                main.post { if (active) result.success(value) }
            } catch (_: Exception) {
                CaptureRuntime.failure(activity, "capture_storage_unavailable", notify = false)
                main.post {
                    if (active)
                        result.error(
                            "capture_unavailable",
                            "Could not access local capture storage. Retry; data was not reset.",
                            null,
                        )
                }
            }
        }
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        CaptureRuntime.onChanged = { if (active) sink.success(null) }
    }

    override fun onCancel(arguments: Any?) {
        CaptureRuntime.onChanged = null
    }

    fun close() {
        active = false
        CaptureRuntime.onChanged = null
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
    }
}
