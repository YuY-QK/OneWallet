package app.onewallet.onewallet

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.view.WindowManager
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class MainActivity : FlutterFragmentActivity() {
    private val biometricsChannelName = "ow.platform/biometrics"
    private val screenGuardChannelName = "ow.platform/screen_guard"
    private val hardwareKeyStoreChannelName = "ow.platform/hardware_key_store"
    private val deviceIntegrityChannelName = "ow.platform/device_integrity"
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

        // 2. Biometrics (真实使用 BiometricPrompt 与 BIOMETRIC_STRONG)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, biometricsChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAvailable" -> {
                        val biometricManager = BiometricManager.from(this)
                        val canAuthenticate = biometricManager.canAuthenticate(BIOMETRIC_STRONG)
                        result.success(canAuthenticate == BiometricManager.BIOMETRIC_SUCCESS)
                    }
                    "authenticate" -> {
                        val biometricManager = BiometricManager.from(this)
                        if (biometricManager.canAuthenticate(BIOMETRIC_STRONG) != BiometricManager.BIOMETRIC_SUCCESS) {
                            result.error("NOT_AVAILABLE", "Strong biometric not available", null)
                            return@setMethodCallHandler
                        }

                        val reason = call.argument<String>("reason") ?: "解锁 OneWallet"
                        val executor = ContextCompat.getMainExecutor(this)
                        val promptInfo = BiometricPrompt.PromptInfo.Builder()
                            .setTitle(reason)
                            .setNegativeButtonText("取消")
                            .setAllowedAuthenticators(BIOMETRIC_STRONG)
                            .build()

                        val prompt = BiometricPrompt(this, executor, object : BiometricPrompt.AuthenticationCallback() {
                            override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                                result.success(true)
                            }

                            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                                if (errorCode == BiometricPrompt.ERROR_USER_CANCELED ||
                                    errorCode == BiometricPrompt.ERROR_NEGATIVE_BUTTON
                                ) {
                                    result.success(false)
                                } else {
                                    result.error("AUTH_ERROR", errString.toString(), null)
                                }
                            }

                            override fun onAuthenticationFailed() {
                                // 识别不匹配，等待用户重试或点击取消
                            }
                        })
                        prompt.authenticate(promptInfo)
                    }
                    else -> result.notImplemented()
                }
            }

        // 3. HardwareKeyStore (使用 BiometricPrompt.CryptoObject 保护密钥解包裹)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, hardwareKeyStoreChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAvailable" -> {
                        val biometricManager = BiometricManager.from(this)
                        val canBio = biometricManager.canAuthenticate(BIOMETRIC_STRONG) == BiometricManager.BIOMETRIC_SUCCESS
                        result.success(canBio)
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

                            val executor = ContextCompat.getMainExecutor(this)
                            val promptInfo = BiometricPrompt.PromptInfo.Builder()
                                .setTitle("开启保险库生物识别")
                                .setSubtitle("请验证面容或指纹以绑定硬件保护")
                                .setNegativeButtonText("取消")
                                .setAllowedAuthenticators(BIOMETRIC_STRONG)
                                .build()

                            val prompt = BiometricPrompt(this, executor, object : BiometricPrompt.AuthenticationCallback() {
                                override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                                    try {
                                        val authenticatedCipher = authResult.cryptoObject?.cipher ?: cipher
                                        val iv = authenticatedCipher.iv
                                        val ciphertext = authenticatedCipher.doFinal(plaintext)

                                        val wrapped = ByteArray(iv.size + ciphertext.size)
                                        System.arraycopy(iv, 0, wrapped, 0, iv.size)
                                        System.arraycopy(ciphertext, 0, wrapped, iv.size, ciphertext.size)
                                        result.success(wrapped)
                                    } catch (e: Exception) {
                                        result.error("WRAP_FAILED", e.message, null)
                                    }
                                }

                                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                                    if (errorCode == BiometricPrompt.ERROR_USER_CANCELED ||
                                        errorCode == BiometricPrompt.ERROR_NEGATIVE_BUTTON
                                    ) {
                                        result.error("USER_CANCELED", errString.toString(), null)
                                    } else {
                                        result.error("BIOMETRIC_UNAVAILABLE", errString.toString(), null)
                                    }
                                }

                                override fun onAuthenticationFailed() {
                                    // 识别不匹配，等待重试
                                }
                            })
                            prompt.authenticate(promptInfo, BiometricPrompt.CryptoObject(cipher))
                        } catch (e: KeyPermanentlyInvalidatedException) {
                            result.error("KEY_PERMANENTLY_INVALIDATED", "Biometrics changed", null)
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
                            val reason = call.argument<String>("reason") ?: "解锁保险库"

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

                            val executor = ContextCompat.getMainExecutor(this)
                            val promptInfo = BiometricPrompt.PromptInfo.Builder()
                                .setTitle(reason)
                                .setSubtitle("请验证面容或指纹以解锁保险库")
                                .setNegativeButtonText("取消")
                                .setAllowedAuthenticators(BIOMETRIC_STRONG)
                                .build()

                            val prompt = BiometricPrompt(this, executor, object : BiometricPrompt.AuthenticationCallback() {
                                override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                                    try {
                                        val authenticatedCipher = authResult.cryptoObject?.cipher ?: cipher
                                        val plaintext = authenticatedCipher.doFinal(ciphertext)
                                        result.success(plaintext)
                                    } catch (e: Exception) {
                                        result.error("UNWRAP_FAILED", e.message, null)
                                    }
                                }

                                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                                    if (errorCode == BiometricPrompt.ERROR_USER_CANCELED ||
                                        errorCode == BiometricPrompt.ERROR_NEGATIVE_BUTTON
                                    ) {
                                        result.error("USER_CANCELED", errString.toString(), null)
                                    } else {
                                        result.error("BIOMETRIC_UNAVAILABLE", errString.toString(), null)
                                    }
                                }

                                override fun onAuthenticationFailed() {
                                    // 识别不匹配，等待重试
                                }
                            })
                            prompt.authenticate(promptInfo, BiometricPrompt.CryptoObject(cipher))
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

        // 4. DeviceIntegrity (M3-08 设备完整性检查)
        // 未编译：需在真机或配置好原生编译工具链的环境中构建验证
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceIntegrityChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "looksCompromised" -> {
                        val compromised = isRooted() || isDebuggingOrAdb()
                        result.success(compromised)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // M3-08 设备完整性检查辅助方法（未编译）
    private fun isRooted(): Boolean {
        val buildTags = Build.TAGS
        if (buildTags != null && buildTags.contains("test-keys")) {
            return true
        }

        val commonPaths = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su"
        )
        for (path in commonPaths) {
            try {
                if (java.io.File(path).exists()) {
                    return true
                }
            } catch (_: Exception) {
                // 忽略权限或读取异常
            }
        }
        return false
    }

    private fun isDebuggingOrAdb(): Boolean {
        if (android.os.Debug.isDebuggerConnected() || android.os.Debug.waitingForDebugger()) {
            return true
        }

        if ((applicationContext.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0) {
            return true
        }

        try {
            val adbEnabled = android.provider.Settings.Global.getInt(
                contentResolver,
                android.provider.Settings.Global.ADB_ENABLED,
                0
            )
            if (adbEnabled != 0) {
                return true
            }
        } catch (_: Exception) {
            // 忽略读取异常
        }

        return false
    }
}
