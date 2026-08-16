package com.iraqitube.app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File
import java.net.URL
import org.json.JSONObject

object UpdateChecker {
    const val SITE = "https://iraqies.github.io/Nazzil/"
    private const val MANIFEST = SITE + "versions.json"

    data class Remote(val version: String, val apkUrl: String)

    fun current(context: Context): String {
        return runCatching {
            context.packageManager.getPackageInfo(context.packageName, 0).versionName
        }.getOrNull().orEmpty().ifBlank { "0" }
    }

    fun fetch(): Remote {
        val json = JSONObject(DirectHttp.get(MANIFEST))
        val releases = json.optJSONArray("releases")
        val latest = json.optString("latest").ifBlank {
            releases?.optJSONObject(0)?.optString("version").orEmpty()
        }
        var apk = ""
        if (releases != null) {
            for (i in 0 until releases.length()) {
                val rel = releases.optJSONObject(i) ?: continue
                if (rel.optString("version") == latest) {
                    apk = rel.optString("apk")
                    break
                }
            }
            if (apk.isBlank()) apk = releases.optJSONObject(0)?.optString("apk").orEmpty()
        }
        require(latest.isNotBlank() && apk.isNotBlank()) { "No version on the site" }
        val url = if (apk.startsWith("http")) apk else URL(URL(SITE), apk).toString()
        return Remote(latest, url)
    }

    fun isNewer(remote: String, local: String): Boolean = compare(remote, local) > 0

    fun download(context: Context, remote: Remote, onProgress: (Float) -> Unit): File {
        val dir = File(context.cacheDir, "updates").apply { mkdirs() }
        val dest = File(dir, "nazzil-${remote.version}.apk")
        if (dest.exists()) dest.delete()
        return DirectHttp.save(remote.apkUrl, dest, SITE, onProgress)
    }

    fun install(context: Context, apk: File) {
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", apk)
        context.startActivity(
            Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
            },
        )
    }

    fun needsInstallPermission(context: Context): Boolean {
        return Build.VERSION.SDK_INT >= 26 && !context.packageManager.canRequestPackageInstalls()
    }

    fun installPermissionIntent(context: Context): Intent {
        return Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:${context.packageName}"),
        )
    }

    private fun compare(left: String, right: String): Int {
        val a = parts(left)
        val b = parts(right)
        val n = maxOf(a.size, b.size)
        for (i in 0 until n) {
            val av = a.getOrElse(i) { 0 }
            val bv = b.getOrElse(i) { 0 }
            if (av != bv) return av.compareTo(bv)
        }
        return 0
    }

    private fun parts(value: String): List<Int> {
        return value.trim().removePrefix("v").split('.', '-', ' ')
            .mapNotNull { it.filter(Char::isDigit).toIntOrNull() }
    }
}
