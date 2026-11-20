package my.spendwise.spendwise_ai.capture

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import org.json.JSONArray
import org.json.JSONObject

/** A transport inbox, never a financial ledger. Flutter need not exist to commit it. */
class CaptureStore(
    context: Context,
    private val cipher: CaptureCipher = KeystoreCaptureCipher(),
    private val clock: () -> Long = System::currentTimeMillis,
) :
    SQLiteOpenHelper(
        context,
        java.io.File(context.noBackupFilesDir, "notification-capture.db").absolutePath,
        null,
        1,
    ) {

    override fun onConfigure(db: SQLiteDatabase) {
        db.setForeignKeyConstraintsEnabled(true)
        db.rawQuery("PRAGMA secure_delete = ON", null).use { cursor ->
            check(cursor.moveToFirst() && cursor.getInt(0) == 1)
        }
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """CREATE TABLE capture_settings (
            singleton INTEGER PRIMARY KEY CHECK(singleton=1), enabled INTEGER NOT NULL DEFAULT 0,
            retention_days INTEGER NOT NULL DEFAULT 1 CHECK(retention_days IN (1,7,30)))"""
        )
        db.execSQL("INSERT INTO capture_settings(singleton) VALUES(1)")
        db.execSQL("CREATE TABLE selected_sources (package_name TEXT PRIMARY KEY)")
        db.execSQL(
            """CREATE TABLE captures (
            sequence INTEGER PRIMARY KEY AUTOINCREMENT, event_id TEXT NOT NULL UNIQUE,
            package_name TEXT NOT NULL, identity_hash TEXT NOT NULL,
            notification_id INTEGER NOT NULL, posted_at INTEGER NOT NULL,
            captured_at INTEGER NOT NULL, last_seen_at INTEGER NOT NULL,
            deliveries INTEGER NOT NULL DEFAULT 1, status TEXT NOT NULL CHECK(status IN ('captured','ignored')),
            reason TEXT, encrypted_content BLOB, raw_expires_at INTEGER,
            content_state TEXT NOT NULL CHECK(content_state IN ('retained','omitted','deleted','expired','unavailable')))
        """
        )
        db.execSQL("CREATE INDEX captures_sequence ON captures(sequence DESC)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // Add ordered migrations here when capture schema v2 is introduced.
        // Never reset the ledger or this inbox as a migration fallback.
        error("Unsupported capture schema upgrade")
    }

    @Synchronized
    fun configure(enabled: Boolean, packages: List<String>, retentionDays: Int) {
        require(packages.all { FinancialSources.applications.containsKey(it) })
        require(retentionDays in listOf(1, 7, 30))
        val db = writableDatabase
        db.beginTransaction()
        try {
            db.update(
                "capture_settings",
                ContentValues().apply {
                    put("enabled", if (enabled) 1 else 0)
                    put("retention_days", retentionDays)
                },
                "singleton=1",
                null,
            )
            db.delete("selected_sources", null, null)
            packages.distinct().forEach { pkg ->
                db.insertOrThrow(
                    "selected_sources",
                    null,
                    ContentValues().apply { put("package_name", pkg) },
                )
            }
            // Shortening retention applies to previously retained raw content too.
            db.execSQL(
                "UPDATE captures SET raw_expires_at = MIN(raw_expires_at, captured_at + ?) WHERE encrypted_content IS NOT NULL",
                arrayOf(retentionDays * DAY),
            )
            expire(db)
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    @Synchronized
    fun settings(): Map<String, Any> {
        val db = readableDatabase
        val values =
            db.rawQuery(
                    "SELECT enabled, retention_days FROM capture_settings WHERE singleton=1",
                    null,
                )
                .use {
                    it.moveToFirst()
                    it.getInt(0) to it.getInt(1)
                }
        val packages =
            db.rawQuery("SELECT package_name FROM selected_sources ORDER BY package_name", null)
                .use { buildList { while (it.moveToNext()) add(it.getString(0)) } }
        return mapOf(
            "enabled" to (values.first == 1),
            "retentionDays" to values.second,
            "packages" to packages,
        )
    }

    @Synchronized
    fun accepts(packageName: String): Boolean =
        FinancialSources.applications.containsKey(packageName) &&
            readableDatabase
                .rawQuery(
                    """SELECT 1 FROM capture_settings s JOIN selected_sources p
            ON p.package_name=? WHERE s.singleton=1 AND s.enabled=1""",
                    arrayOf(packageName),
                )
                .use { it.moveToFirst() }

    @Synchronized
    fun capture(payload: CapturePayload): String? {
        // Selection and insert share the monitor with configure: disabling wins
        // over work that was queued before the settings change.
        if (!accepts(payload.packageName)) return null
        val reason = CapturePolicy.ignoredReason(payload)
        val now = clock()
        val identity =
            CapturePolicy.digest(
                JSONArray(
                        listOf(
                            payload.packageName,
                            payload.notificationKey,
                            payload.notificationId,
                            payload.tag,
                        )
                    )
                    .toString()
            )
        val raw =
            if (reason == null)
                JSONObject()
                    .apply {
                        put("title", payload.title)
                        put("body", payload.body)
                        put("notificationKey", payload.notificationKey)
                        put("tag", payload.tag ?: JSONObject.NULL)
                        put("groupKey", payload.groupKey ?: JSONObject.NULL)
                        put("notificationWhen", payload.notificationWhen)
                    }
                    .toString()
            else null
        // This suppresses exact Android callback replays only. Revisions/new post
        // times stay separate. It is not financial transaction deduplication.
        val eventId =
            CapturePolicy.digest(
                JSONArray(listOf(identity, payload.postedAt, raw ?: reason)).toString()
            )
        val db = writableDatabase
        db.beginTransaction()
        try {
            expire(db)
            val previous =
                db.rawQuery("SELECT 1 FROM captures WHERE event_id=?", arrayOf(eventId)).use {
                    it.moveToFirst()
                }
            if (previous) {
                db.execSQL(
                    "UPDATE captures SET deliveries=deliveries+1,last_seen_at=? WHERE event_id=?",
                    arrayOf(now, eventId),
                )
            } else {
                val days =
                    db.rawQuery(
                            "SELECT retention_days FROM capture_settings WHERE singleton=1",
                            null,
                        )
                        .use {
                            it.moveToFirst()
                            it.getInt(0)
                        }
                // Encryption failure aborts the insert; there is no plaintext fallback.
                val encrypted = raw?.let { cipher.encrypt(it.toByteArray(Charsets.UTF_8), eventId) }
                db.insertOrThrow(
                    "captures",
                    null,
                    ContentValues().apply {
                        put("event_id", eventId)
                        put("package_name", payload.packageName)
                        put("identity_hash", identity)
                        put("notification_id", payload.notificationId)
                        put("posted_at", payload.postedAt)
                        put("captured_at", now)
                        put("last_seen_at", now)
                        put("status", if (reason == null) "captured" else "ignored")
                        put("reason", reason)
                        put("encrypted_content", encrypted)
                        if (encrypted != null) put("raw_expires_at", now + days * DAY)
                        put("content_state", if (encrypted == null) "omitted" else "retained")
                    },
                )
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
        return eventId
    }

    private fun expire(db: SQLiteDatabase) {
        db.execSQL(
            """UPDATE captures SET encrypted_content=NULL,raw_expires_at=NULL,content_state='expired'
            WHERE encrypted_content IS NOT NULL AND raw_expires_at<=?""",
            arrayOf(clock()),
        )
    }

    @Synchronized
    fun history(before: Long = Long.MAX_VALUE, limit: Int = 50): List<Map<String, Any?>> {
        val db = writableDatabase
        expire(db)
        return db.rawQuery(
                """SELECT sequence,event_id,package_name,notification_id,posted_at,captured_at,
            deliveries,status,reason,content_state FROM captures WHERE sequence<? ORDER BY sequence DESC LIMIT ?""",
                arrayOf(before.toString(), limit.coerceIn(1, 100).toString()),
            )
            .use { c ->
                buildList {
                    while (c.moveToNext()) add(
                        mapOf(
                            "sequence" to c.getLong(0),
                            "eventId" to c.getString(1),
                            "packageName" to c.getString(2),
                            "notificationId" to c.getInt(3),
                            "postedAt" to c.getLong(4),
                            "capturedAt" to c.getLong(5),
                            "deliveries" to c.getInt(6),
                            "status" to c.getString(7),
                            "reason" to c.getString(8),
                            "contentState" to c.getString(9),
                        )
                    )
                }
            }
    }

    @Synchronized
    fun content(eventId: String): Map<String, Any?>? {
        val db = writableDatabase
        expire(db)
        return db.rawQuery(
                "SELECT encrypted_content FROM captures WHERE event_id=?",
                arrayOf(eventId),
            )
            .use { c ->
                if (!c.moveToFirst() || c.isNull(0)) return@use null
                try {
                    val json =
                        JSONObject(String(cipher.decrypt(c.getBlob(0), eventId), Charsets.UTF_8))
                    mapOf(
                        "title" to json.optString("title"),
                        "body" to json.optString("body"),
                        "notificationKey" to json.optString("notificationKey"),
                        "tag" to if (json.isNull("tag")) null else json.getString("tag"),
                        "groupKey" to
                            if (json.isNull("groupKey")) null else json.getString("groupKey"),
                        "notificationWhen" to json.optLong("notificationWhen"),
                    )
                } catch (_: Exception) {
                    // A lost/invalid key never causes a database reset or plaintext fallback.
                    db.update(
                        "captures",
                        ContentValues().apply {
                            putNull("encrypted_content")
                            putNull("raw_expires_at")
                            put("content_state", "unavailable")
                        },
                        "event_id=?",
                        arrayOf(eventId),
                    )
                    null
                }
            }
    }

    @Synchronized
    fun eraseContent(eventId: String? = null) {
        writableDatabase.update(
            "captures",
            ContentValues().apply {
                putNull("encrypted_content")
                putNull("raw_expires_at")
                put("content_state", "deleted")
            },
            if (eventId == null) null else "event_id=?",
            eventId?.let { arrayOf(it) },
        )
    }

    companion object {
        const val DAY = 86_400_000L
    }
}
