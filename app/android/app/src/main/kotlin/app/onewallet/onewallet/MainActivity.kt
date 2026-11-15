package app.onewallet.onewallet

import android.app.KeyguardManager
import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class MainActivity : FlutterActivity() {
    private val biometricsChannelName = "ow.platform/biometrics"
    private val screenGuardChannelName = "ow.platform/screen_guard"
    private val hardwareKeyStoreChannelName = "ow.platform/hardware_key_store"
    private val androidKeystore = "AndroidKeyStore"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. ScreenGuard: FLAG_SECURE
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, screenGuardChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enable" -> {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    "disable" -> {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // 2. Biometrics
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, biometricsChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAvailable" -> {
                        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
                        val isSecure = keyguardManager?.isDeviceSecure ?: false
                        result.success(isSecure)
                    }
                    "authenticate" -> {
                        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
                        if (keyguardManager?.isDeviceSecure == true) {
                            result.success(true)
                        } else {
                            result.error("NOT_AVAILABLE", "Device lock not configured", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // 3. HardwareKeyStore
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, hardwareKeyStoreChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAvailable" -> {
                        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
                        result.success(keyguardManager?.isDeviceSecure ?: false)
                    }
                    "wrap" -> {
                        try {
                            val alias = call.argument<String>("alias")
                                ?: return@setMethodCallHandler result.error("INVALID_ARGS", "Missing alias", null)
                            val plaintext = call.argument<ByteArray>("plaintext")
                                ?: return@setMethodCallHandler result.error("INVALID_ARGS", "Missing plaintext", null)

                            val keyStore = KeyStore.getInstance(androidKeystore).apply { load(null) }
                            if (!keyStore.containsAlias(alias)) {
                                val keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, androidKeystore)
                                val builder = KeyGenParameterSpec.Builder(
                                    alias,
                                    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
                                )
                                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                                    .setKeySize(256)
                                    .setUserAuthenticationRequired(true)

                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                                    builder.setInvalidatedByBiometricEnrollment(true)
                                }
                                keyGenerator.init(builder.build())
                                keyGenerator.generateKey()
                            }

                            val secretKey = keyStore.getKey(alias, null) as SecretKey
                            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                            cipher.init(Cipher.ENCRYPT_MODE, secretKey)
                            val iv = cipher.iv
                            val ciphertext = cipher.doFinal(plaintext)

                            val wrapped = ByteArray(iv.size + ciphertext.size)
                            System.arraycopy(iv, 0, wrapped, 0, iv.size)
                            System.arraycopy(ciphertext, 0, wrapped, iv.size, ciphertext.size)

                            result.success(wrapped)
                        } catch (e: Exception) {
                            result.error("WRAP_FAILED", e.message, null)
                        }
                    }
                    "unwrap" -> {
                        try {
                            val alias = call.argument<String>("alias")
                                ?: return@setMethodCallHandler result.error("INVALID_ARGS", "Missing alias", null)
                            val wrapped = call.argument<ByteArray>("wrapped")
                                ?: return@setMethodCallHandler result.error("INVALID_ARGS", "Missing wrapped", null)

                            if (wrapped.size < 12) {
                                return@setMethodCallHandler result.error("INVALID_DATA", "Wrapped data too short", null)
                            }

                            val keyStore = KeyStore.getInstance(androidKeystore).apply { load(null) }
                            if (!keyStore.containsAlias(alias)) {
                                return@setMethodCallHandler result.error("KEY_NOT_FOUND", "Key not found", null)
                            }

                            val secretKey = keyStore.getKey(alias, null) as SecretKey
                            val iv = ByteArray(12)
                            System.arraycopy(wrapped, 0, iv, 0, 12)
                            val ciphertext = ByteArray(wrapped.size - 12)
                            System.arraycopy(wrapped, 12, ciphertext, 0, ciphertext.size)

                            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                            val spec = GCMParameterSpec(128, iv)
                            cipher.init(Cipher.DECRYPT_MODE, secretKey, spec)
                            val plaintext = cipher.doFinal(ciphertext)

                            result.success(plaintext)
                        } catch (e: KeyPermanentlyInvalidatedException) {
                            result.error("KEY_PERMANENTLY_INVALIDATED", "Biometrics changed", null)
                        } catch (e: Exception) {
                            result.error("UNWRAP_FAILED", e.message, null)
                        }
                    }
                    "delete" -> {
                        try {
                            val alias = call.argument<String>("alias")
                                ?: return@setMethodCallHandler result.error("INVALID_ARGS", "Missing alias", null)
                            val keyStore = KeyStore.getInstance(androidKeystore).apply { load(null) }
                            if (keyStore.containsAlias(alias)) {
                                keyStore.deleteEntry(alias)
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("DELETE_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
