package com.cleanshare.cleanshare

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val secureChannel = "com.cleanshare.cleanshare/secure_store"
    private val engineChannel = "com.cleanshare.cleanshare/engine"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val store = SecureStoreHelper(applicationContext)
        val integrity = DeviceIntegrityHelper(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, secureChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(true)
                    "read" -> {
                        val key = call.argument<String>("key")
                        if (key.isNullOrBlank()) {
                            result.error("invalid", "Missing key", null)
                        } else {
                            result.success(store.read(key))
                        }
                    }
                    "write" -> {
                        val key = call.argument<String>("key")
                        val value = call.argument<String>("value")
                        if (key.isNullOrBlank() || value == null) {
                            result.error("invalid", "Missing key or value", null)
                        } else {
                            store.write(key, value)
                            result.success(null)
                        }
                    }
                    "delete" -> {
                        val key = call.argument<String>("key")
                        if (key.isNullOrBlank()) {
                            result.error("invalid", "Missing key", null)
                        } else {
                            store.delete(key)
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, engineChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "nativeEngineLibPath" -> {
                        val libDir = applicationInfo.nativeLibraryDir
                        result.success("$libDir/libzerotrace_engine.so")
                    }
                    "deviceIntegrityReport" -> result.success(integrity.report())
                    else -> result.notImplemented()
                }
            }
    }
}
