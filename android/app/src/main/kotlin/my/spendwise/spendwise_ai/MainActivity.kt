package my.spendwise.spendwise_ai

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import my.spendwise.spendwise_ai.capture.CaptureBridge
import my.spendwise.spendwise_ai.capture.CaptureRuntime

class MainActivity : FlutterActivity() {
    private var captureBridge: CaptureBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        captureBridge = CaptureBridge(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onResume() {
        super.onResume()
        // Fresh permission status is queried by Flutter on resume, never cached.
        CaptureRuntime.signal()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        captureBridge?.close()
        captureBridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
