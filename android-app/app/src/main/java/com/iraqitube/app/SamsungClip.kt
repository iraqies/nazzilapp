package com.iraqitube.app

import android.content.Context
import java.lang.reflect.Proxy

object SamsungClip {
    fun listen(context: Context, onChange: () -> Unit): Boolean {
        val app = context.applicationContext
        val manager = runCatching { app.getSystemService("semclipboard") }.getOrNull() ?: return false
        manager.javaClass.methods
            .filter { it.name in setOf("registerClipboardEventListener", "getLatestClip", "getClip") }
            .forEach { method ->
                ClipLog.write(app, "samsung ${method.name}(${method.parameterTypes.joinToString { it.name }})")
            }
        val register = manager.javaClass.methods.firstOrNull { it.name == "registerClipboardEventListener" }
        if (register == null) {
            ClipLog.write(app, "samsung register missing")
            return false
        }
        ClipLog.write(
            app,
            "samsung register ${register.parameterTypes.joinToString { it.name }}",
        )
        val type = register.parameterTypes.firstOrNull { it.isInterface } ?: register.parameterTypes.first()
        val listener = Proxy.newProxyInstance(type.classLoader, arrayOf(type)) { _, method, _ ->
            when (method.name) {
                "equals" -> false
                "hashCode" -> 0
                "toString" -> "NazzilSamsungClip"
                else -> {
                    ClipLog.write(app, "samsung event ${method.name}")
                    onChange()
                    null
                }
            }
        }
        return runCatching {
            if (register.parameterTypes.size == 1) {
                register.invoke(manager, listener)
            } else {
                register.invoke(manager, listener, *Array(register.parameterTypes.size - 1) { null })
            }
            ClipLog.write(app, "samsung hooked ${type.name}")
            true
        }.getOrElse {
            ClipLog.write(app, "samsung hook fail ${it.message}")
            false
        }
    }

    fun readLatest(context: Context): String {
        val app = context.applicationContext
        val manager = runCatching { app.getSystemService("semclipboard") }.getOrNull() ?: return ""
        val latest = manager.javaClass.methods.firstOrNull { it.name == "getLatestClip" } ?: return ""
        val types = intArrayOf(1, 2, 16, 0, -1)
        for (type in types) {
            val raw = try {
                latest.invoke(manager, type)
            } catch (error: Exception) {
                ClipLog.write(app, "samsung latest($type) fail ${error.message}")
                null
            } ?: continue
            val link = textOf(raw)
            if (link.isNotBlank()) return link
        }
        return ""
    }

    private fun textOf(value: Any): String {
        val bits = mutableListOf<String>()
        bits += value.toString()
        value.javaClass.methods
            .filter { it.parameterTypes.isEmpty() && (it.name.startsWith("get") || it.name.startsWith("is")) }
            .forEach { method ->
                runCatching { method.invoke(value)?.toString() }.getOrNull()
                    ?.takeIf { it.isNotBlank() && it != "null" }
                    ?.let { bits += it }
            }
        for (bit in bits) {
            val link = LinkParser.extract(bit)
            if (link.isNotBlank() && Downloader.looksSupported(link)) return link
        }
        return ""
    }
}
