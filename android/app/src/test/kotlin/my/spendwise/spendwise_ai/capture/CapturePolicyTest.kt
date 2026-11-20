package my.spendwise.spendwise_ai.capture

import javax.crypto.KeyGenerator
import org.junit.Assert.*
import org.junit.Test

class CapturePolicyTest {
    private fun event(body: String, title: String = "Synthetic notice") =
        CapturePayload("my.com.tngdigital.ewallet", "synthetic-key", 1, null, null, 1, title, body)

    @Test
    fun privacyScreeningOmitsCredentialsAndDoesNotClassifyPayments() {
        for (text in
            listOf(
                "OTP 123456",
                "Your TAC is 999999",
                "Password reset",
                "Kod pengesahan 1234",
                "验证码 123456",
                "123456",
                "١٢٣٤٥٦",
                "Login approved",
            )) {
            assertEquals(
                text,
                "sensitive_content_omitted",
                CapturePolicy.ignoredReason(event(text)),
            )
        }
        assertEquals(
            "sensitive_content_omitted",
            CapturePolicy.ignoredReason(event("Unrelated", "OTP")),
        )
        // All are merely raw capture candidates. There is no financial parser here.
        for (text in
            listOf(
                "Synthetic RM25.90 test",
                "Synthetic RM7,700.00 test",
                "Synthetic payment failed RM25.90",
                "Synthetic balance RM50.00",
            )) {
            assertNull(CapturePolicy.ignoredReason(event(text)))
        }
        assertEquals("no_readable_content", CapturePolicy.ignoredReason(event("", "")))
        assertEquals(
            "group_summary",
            CapturePolicy.ignoredReason(event("Synthetic").copy(groupSummary = true)),
        )
        assertEquals("content_too_large", CapturePolicy.ignoredReason(event("x".repeat(8193))))
    }

    @Test
    fun encryptionIsRandomizedAndAuthenticatedToCaptureIdentity() {
        val key = KeyGenerator.getInstance("AES").apply { init(256) }.generateKey()
        val cipher = AesGcmCaptureCipher { key }
        val plain = "Synthetic test content".toByteArray()
        val sealed = cipher.encrypt(plain, "capture-one")
        assertFalse(plain.contentEquals(sealed))
        assertFalse(sealed.contentEquals(cipher.encrypt(plain, "capture-one")))
        assertArrayEquals(plain, cipher.decrypt(sealed, "capture-one"))
        assertThrows(Exception::class.java) { cipher.decrypt(sealed, "capture-two") }
        sealed[sealed.lastIndex] = (sealed.last().toInt() xor 1).toByte()
        assertThrows(Exception::class.java) { cipher.decrypt(sealed, "capture-one") }
    }
}
