package com.cleanshare.cleanshare

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Debug
import java.io.ByteArrayInputStream
import java.io.File
import java.security.MessageDigest
import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate

class DeviceIntegrityHelper(private val context: Context) {

    fun report(): Map<String, Any?> {
        return mapOf(
            "signingCertSha256" to signingCertSha256(),
            "debuggerAttached" to Debug.isDebuggerConnected(),
            "emulator" to isEmulator(),
            "rootSuspected" to isRootSuspected(),
            "fridaSuspected" to isFridaSuspected(),
        )
    }

    fun signingCertSha256(): String? {
        return try {
            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                context.packageManager.getPackageInfo(
                    context.packageName,
                    PackageManager.GET_SIGNING_CERTIFICATES,
                )
            } else {
                @Suppress("DEPRECATION")
                context.packageManager.getPackageInfo(
                    context.packageName,
                    PackageManager.GET_SIGNATURES,
                )
            }

            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageInfo.signingInfo?.apkContentsSigners
            } else {
                @Suppress("DEPRECATION")
                packageInfo.signatures
            } ?: return null

            if (signatures.isEmpty()) return null
            certSha256FromSignerBytes(signatures[0].toByteArray())
        } catch (_: Exception) {
            null
        }
    }

    /// SHA-256 of the X.509 certificate DER — matches `apksigner verify --print-certs`.
    private fun certSha256FromSignerBytes(signerBytes: ByteArray): String? {
        return try {
            val cert = CertificateFactory.getInstance("X509")
                .generateCertificate(ByteArrayInputStream(signerBytes)) as X509Certificate
            sha256Hex(cert.encoded)
        } catch (_: Exception) {
            sha256Hex(signerBytes)
        }
    }

    private fun sha256Hex(bytes: ByteArray): String {
        val hash = MessageDigest.getInstance("SHA-256").digest(bytes)
        return hash.joinToString("") { "%02x".format(it) }
    }

    private fun isEmulator(): Boolean {
        val fingerprint = Build.FINGERPRINT.lowercase()
        val model = Build.MODEL.lowercase()
        val manufacturer = Build.MANUFACTURER.lowercase()
        val brand = Build.BRAND.lowercase()
        val device = Build.DEVICE.lowercase()
        val product = Build.PRODUCT.lowercase()
        return fingerprint.contains("generic") ||
            fingerprint.contains("emulator") ||
            fingerprint.contains("sdk_gphone") ||
            model.contains("emulator") ||
            model.contains("android sdk built for") ||
            manufacturer.contains("genymotion") ||
            brand.startsWith("generic") ||
            device.startsWith("generic") ||
            product.contains("sdk") ||
            Build.HARDWARE.lowercase().contains("goldfish") ||
            Build.HARDWARE.lowercase().contains("ranchu")
    }

    private fun isRootSuspected(): Boolean {
        val tags = Build.TAGS?.lowercase() ?: ""
        if (tags.contains("test-keys")) return true

        val suPaths = listOf(
            "/system/app/Superuser.apk",
            "/system/xbin/su",
            "/system/bin/su",
            "/sbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/data/local/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/su/bin/su",
            "/magisk/.core/bin/su",
        )
        if (suPaths.any { File(it).exists() }) return true

        return try {
            val process = Runtime.getRuntime().exec(arrayOf("which", "su"))
            val output = process.inputStream.bufferedReader().readText().trim()
            process.waitFor()
            output.isNotEmpty()
        } catch (_: Exception) {
            false
        }
    }

    private fun isFridaSuspected(): Boolean {
        val maps = File("/proc/self/maps")
        if (!maps.exists()) return false
        return try {
            maps.useLines { lines ->
                lines.any { line ->
                    val lower = line.lowercase()
                    lower.contains("frida") ||
                        lower.contains("gum-js-loop") ||
                        lower.contains("gmain") && lower.contains("frida")
                }
            }
        } catch (_: Exception) {
            false
        }
    }
}
