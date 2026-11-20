package my.spendwise.spendwise_ai.capture

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

interface CaptureCipher {
    fun encrypt(plain: ByteArray, identity: String): ByteArray

    fun decrypt(sealed: ByteArray, identity: String): ByteArray
}

/** Raw content is authenticated to its capture ID. No plaintext/key logging. */
class KeystoreCaptureCipher : CaptureCipher {
    private val alias = "spendwise.notification.capture.v1"

    @Synchronized
    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(alias, null) as? SecretKey)?.let {
            return it
        }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
            .apply {
                init(
                    KeyGenParameterSpec.Builder(
                            alias,
                            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                        )
                        .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                        .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                        .setKeySize(256)
                        .build()
                )
            }
            .generateKey()
    }

    private val encryption = AesGcmCaptureCipher(::key)

    override fun encrypt(plain: ByteArray, identity: String) = encryption.encrypt(plain, identity)

    override fun decrypt(sealed: ByteArray, identity: String) = encryption.decrypt(sealed, identity)
}

class AesGcmCaptureCipher(private val keyProvider: () -> SecretKey) : CaptureCipher {
    override fun encrypt(plain: ByteArray, identity: String): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, keyProvider())
        cipher.updateAAD(identity.toByteArray(Charsets.UTF_8))
        return cipher.iv + cipher.doFinal(plain)
    }

    override fun decrypt(sealed: ByteArray, identity: String): ByteArray {
        require(sealed.size >= 28)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(
            Cipher.DECRYPT_MODE,
            keyProvider(),
            GCMParameterSpec(128, sealed.copyOfRange(0, 12)),
        )
        cipher.updateAAD(identity.toByteArray(Charsets.UTF_8))
        return cipher.doFinal(sealed.copyOfRange(12, sealed.size))
    }
}
