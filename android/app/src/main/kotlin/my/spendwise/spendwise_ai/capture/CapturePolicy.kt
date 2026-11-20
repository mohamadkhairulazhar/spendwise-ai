package my.spendwise.spendwise_ai.capture

import java.security.MessageDigest

/** Package identities verified from publisher Google Play listings, not parser integrations. */
object FinancialSources {
    val applications =
        linkedMapOf(
            "my.com.tngdigital.ewallet" to "Touch 'n Go eWallet",
            "com.maybank2u.life" to "MAE by Maybank2u",
            "my.com.hongleongconnect.mobileconnect" to "HLB Connect",
            "com.rhbgroup.rhbmobilebanking" to "RHB Mobile Banking",
            "com.personal.adb" to "AEON Bank",
            "com.alliance.AOPMobileApp" to "allianceonline Mobile",
        )
}

data class CapturePayload(
    val packageName: String,
    val notificationKey: String,
    val notificationId: Int,
    val tag: String?,
    val groupKey: String?,
    val postedAt: Long,
    val title: String,
    val body: String,
    val groupSummary: Boolean = false,
    val notificationWhen: Long = postedAt,
)

object CapturePolicy {
    private val credentials =
        Regex(
            "(?i)\\b(otp|tac|pin|password|passcode|verification|authentication|code|kod|login|approval|authoris(?:e|ation)|" +
                "authoriz(?:e|ation)|one[ -]?time|security code|secure\\s*2u|secure\\s*plus|" +
                "kata laluan|kod keselamatan|pengesahan)\\b|验证码|驗證碼|密码|密碼"
        )
    // Conservative: unlabelled standalone codes are not retained either. Decimal
    // amounts are excluded from this check; this is privacy screening, not parsing.
    private val possibleCode = Regex("(?<![\\p{L}\\p{N}.,])\\p{Nd}{4,8}(?![\\p{L}\\p{N}.,])")

    fun ignoredReason(payload: CapturePayload): String? =
        when {
            payload.title.length > 256 || payload.body.length > 8192 -> "content_too_large"
            payload.notificationKey.length > 1024 ||
                (payload.tag?.length ?: 0) > 1024 ||
                (payload.groupKey?.length ?: 0) > 1024 -> "identifiers_too_large"
            payload.groupSummary -> "group_summary"
            payload.title.isBlank() && payload.body.isBlank() -> "no_readable_content"
            credentials.containsMatchIn(payload.title + "\n" + payload.body) ||
                possibleCode.containsMatchIn(payload.title + "\n" + payload.body) ->
                "sensitive_content_omitted"
            else -> null
        }

    fun digest(value: String): String =
        MessageDigest.getInstance("SHA-256").digest(value.toByteArray(Charsets.UTF_8)).joinToString(
            ""
        ) {
            "%02x".format(it)
        }
}
