package my.spendwise.spendwise_ai.capture

import android.app.Notification
import android.content.ComponentName
import android.content.Context
import android.os.Process
import android.provider.Settings
import android.service.notification.StatusBarNotification
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import javax.crypto.KeyGenerator
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class CaptureStoreTest {
    private lateinit var context: Context
    private lateinit var store: CaptureStore
    private var now = 1_800_000_000_000L
    private val pkg = "my.com.tngdigital.ewallet"
    private val cipher = AesGcmCaptureCipher { testKey }
    private val testKey = KeyGenerator.getInstance("AES").apply { init(256) }.generateKey()

    private fun event() =
        CapturePayload(
            pkg,
            "synthetic-notification-key",
            42,
            "synthetic-tag",
            "synthetic-group",
            now - 10,
            "Synthetic test",
            "Synthetic RM25.90 fixture",
        )

    @Before
    fun before() {
        context = RuntimeEnvironment.getApplication()
        File(context.noBackupFilesDir, "notification-capture.db").delete()
        store = CaptureStore(context, cipher) { now }
    }

    @After
    fun after() {
        store.close()
    }

    private fun enable() = store.configure(true, listOf(pkg), 1)

    @Test
    fun selectionDefaultsOffAndOnlyExplicitAllowedPackagesAreCaptured() {
        assertFalse(store.settings()["enabled"] as Boolean)
        assertNull(store.capture(event()))
        store.configure(true, emptyList(), 1)
        assertNull(store.capture(event()))
        enable()
        assertNotNull(store.capture(event()))
        assertNull(store.capture(event().copy(packageName = "com.unselected.app")))
        assertThrows(IllegalArgumentException::class.java) {
            store.configure(true, listOf("com.unselected.app"), 1)
        }
        store.configure(false, listOf(pkg), 1)
        assertNull(store.capture(event().copy(postedAt = now + 1)))
        assertEquals(1, store.history().size)
    }

    @Test
    fun exactReplayIsIdempotentButChangedContentAndNewPostTimesAreRetained() {
        enable()
        val first = store.capture(event())!!
        assertEquals(first, store.capture(event()))
        assertEquals(2, store.history().single()["deliveries"])
        store.capture(event().copy(body = "Synthetic revised RM26.90 fixture"))
        store.capture(event().copy(postedAt = now + 1))
        assertEquals(3, store.history().size)
        assertEquals(1, store.history().map { it["notificationId"] }.distinct().size)
    }

    @Test
    fun concurrentReplaysCommitOnlyOneDurableCapture() {
        enable()
        val pool = Executors.newFixedThreadPool(4)
        try {
            val tasks = (1..20).map { pool.submit<String?> { store.capture(event()) } }
            assertEquals(1, tasks.map { it.get(5, TimeUnit.SECONDS) }.distinct().size)
            assertEquals(20, store.history().single()["deliveries"])
        } finally {
            pool.shutdownNow()
        }
    }

    @Test
    fun restartKeepsInboxAndDeletingRawContentDoesNotRecaptureItOrCreateLedger() {
        enable()
        val id = store.capture(event())!!
        store.close()
        store = CaptureStore(context, cipher) { now }
        assertEquals(id, store.history().single()["eventId"])
        assertEquals("Synthetic RM25.90 fixture", store.content(id)!!["body"])
        assertEquals("synthetic-tag", store.content(id)!!["tag"])
        assertEquals("synthetic-notification-key", store.content(id)!!["notificationKey"])
        store.eraseContent(id)
        assertNull(store.content(id))
        store.capture(event())
        assertNull(store.content(id))
        assertEquals("deleted", store.history().single()["contentState"])
        assertFalse(context.getDatabasePath("spendwise.db").exists())
    }

    @Test
    fun retentionShorteningAppliesToExistingContentAndExpiryIsEnforcedBeforeRead() {
        store.configure(true, listOf(pkg), 7)
        val id = store.capture(event())!!
        now += 2 * CaptureStore.DAY
        assertNotNull(store.content(id))
        store.configure(true, listOf(pkg), 1)
        assertNull(store.content(id))
        assertEquals("expired", store.history().single()["contentState"])
        assertEquals(1, store.history().size)
    }

    @Test
    fun sensitiveNotificationHasNoPersistedRawContentAndEncryptionFailureDoesNotFallBack() {
        enable()
        val id = store.capture(event().copy(body = "Synthetic OTP 123456"))!!
        assertEquals("ignored", store.history().single()["status"])
        assertNull(store.content(id))
        val badCipher =
            object : CaptureCipher {
                override fun encrypt(plain: ByteArray, identity: String): ByteArray =
                    error("synthetic failure")

                override fun decrypt(sealed: ByteArray, identity: String): ByteArray =
                    error("synthetic failure")
            }
        val failing = CaptureStore(context, badCipher) { now }
        try {
            assertThrows(IllegalStateException::class.java) { failing.capture(event()) }
        } finally {
            failing.close()
        }
        assertEquals(1, store.history().size)
        val bytes = File(context.noBackupFilesDir, "notification-capture.db").readBytes()
        assertFalse(String(bytes, Charsets.ISO_8859_1).contains("123456"))
        assertFalse(String(bytes, Charsets.ISO_8859_1).contains("Synthetic OTP"))
    }

    @Test
    fun failedDecryptionDoesNotResetOrDeleteCaptureMetadata() {
        enable()
        val id = store.capture(event())!!
        store.close()
        val other = KeyGenerator.getInstance("AES").apply { init(256) }.generateKey()
        store = CaptureStore(context, AesGcmCaptureCipher { other }) { now }
        assertNull(store.content(id))
        assertEquals("unavailable", store.history().single()["contentState"])
        assertEquals(id, store.history().single()["eventId"])
    }

    @Test
    fun paginationRecoversAllEventsAcrossReopenWithoutDeletingPendingCaptures() {
        enable()
        repeat(55) { store.capture(event().copy(notificationId = it, postedAt = now + it)) }
        val first = store.history()
        val rest = store.history(first.last()["sequence"] as Long)
        assertEquals(50, first.size)
        assertEquals(5, rest.size)
        assertEquals(55, (first + rest).map { it["eventId"] }.distinct().size)
    }

    @Test
    fun serviceCommitsWhileNoFlutterActivityOrChannelExists() {
        enable()
        TestCaptureListener.inbox = store
        val controller = Robolectric.buildService(TestCaptureListener::class.java).create()
        val listener = controller.get()
        val notification =
            Notification.Builder(context, "synthetic-channel")
                .setContentTitle("Synthetic test")
                .setContentText("Synthetic RM25.90 fixture")
                .build()
        val sbn =
            StatusBarNotification(
                pkg,
                pkg,
                42,
                "synthetic-tag",
                Process.myUid(),
                0,
                0,
                notification,
                Process.myUserHandle(),
                now,
            )
        listener.onNotificationPosted(sbn)
        CaptureRuntime.executor.submit {}.get(5, TimeUnit.SECONDS)
        assertEquals(1, store.history().size)
        assertEquals("captured", store.history().single()["status"])
        assertNotNull(store.content(store.history().single()["eventId"] as String))
        controller.destroy()
    }

    @Test
    @Config(sdk = [24])
    fun permissionStatusTracksRevocationWithoutCachedPermission() {
        val component = ComponentName(context, SpendWiseNotificationListener::class.java)
        Settings.Secure.putString(
            context.contentResolver,
            "enabled_notification_listeners",
            component.flattenToString(),
        )
        assertTrue(CaptureRuntime.permissionGranted(context))
        Settings.Secure.putString(context.contentResolver, "enabled_notification_listeners", "")
        assertFalse(CaptureRuntime.permissionGranted(context))
    }
}

class TestCaptureListener : SpendWiseNotificationListener() {
    override fun captureStore(): CaptureStore = inbox

    companion object {
        lateinit var inbox: CaptureStore
    }
}
