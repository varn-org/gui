package dev.varn.gui

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * What an application must find again next time it is opened, kept where the phone keeps a secret.
 *
 * The values are encrypted with a key the system holds and this process can use but never read: it is
 * generated inside the keystore, backed by hardware where the phone has it, and what is written to disk
 * is the cipher text. A file of plain preferences is readable off a backup and by anything with the
 * device unlocked, which is not what a token belongs in.
 */
object VarnPreferences {
    private const val FILE = "dev.varn.gui.preferences"
    private const val ALIAS = "dev.varn.gui.preferences.key"
    private const val TRANSFORM = "AES/GCM/NoPadding"
    private const val NONCE = 12
    private const val TAG = 128

    fun set(context: Context, name: String, value: String) {
        val cipher = Cipher.getInstance(TRANSFORM)

        cipher.init(Cipher.ENCRYPT_MODE, key())

        val sealed = cipher.doFinal(value.toByteArray())
        val carried = cipher.iv + sealed

        store(context).edit().putString(name, Base64.encodeToString(carried, Base64.NO_WRAP)).apply()
    }

    fun get(context: Context, name: String): String? {
        val held = store(context).getString(name, null) ?: return null
        val carried = Base64.decode(held, Base64.NO_WRAP)

        if (carried.size <= NONCE) {
            throw VarnRendererException("the preference was not written by this application")
        }

        val cipher = Cipher.getInstance(TRANSFORM)

        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(TAG, carried, 0, NONCE))

        return String(cipher.doFinal(carried, NONCE, carried.size - NONCE))
    }

    fun remove(context: Context, name: String) {
        store(context).edit().remove(name).apply()
    }

    fun clear(context: Context) {
        store(context).edit().clear().apply()
    }

    fun names(context: Context): List<String> = store(context).all.keys.sorted()

    private fun store(context: Context) = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    /**
     * Answers the key the values are sealed with, making one the first time it is asked for.
     *
     * It never leaves the keystore, so a copy of the file is worth nothing without the phone it was
     * written on, and removing the application takes the key with it.
     */
    private fun key(): SecretKey {
        val keystore = KeyStore.getInstance("AndroidKeyStore")

        keystore.load(null)

        val held = keystore.getEntry(ALIAS, null) as? KeyStore.SecretKeyEntry

        if (held != null) {
            return held.secretKey
        }

        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")

        generator.init(
            KeyGenParameterSpec.Builder(
                ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .build(),
        )

        return generator.generateKey()
    }
}
