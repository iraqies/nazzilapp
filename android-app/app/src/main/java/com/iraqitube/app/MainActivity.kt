package com.iraqitube.app

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.FileProvider
import java.io.File

class MainActivity : ComponentActivity() {
    private var incomingUrl by mutableStateOf("")

    override fun attachBaseContext(newBase: Context) {
        super.attachBaseContext(SettingsStore.wrap(newBase))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        SettingsStore(this).applyLocale()
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        incomingUrl = readIncoming(intent)
        ClipWatch.sync(this)
        setContent {
            IraqiTubeTheme {
                IraqiTubeScreen(
                    incomingUrl = incomingUrl,
                    onShare = { uri, mime -> share(uri, mime) },
                    onView = { uri, mime -> view(uri, mime) },
                )
            }
        }
    }

    override fun onResume() {
        super.onResume()
        ClipWatch.appInFront = true
        OverlayPrompt.hide(this)
        ClipWatch.sync(this)
    }

    override fun onPause() {
        ClipWatch.appInFront = false
        super.onPause()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        incomingUrl = readIncoming(intent)
    }

    private fun readIncoming(intent: Intent?): String {
        if (intent == null) return ""
        val sent = intent.getStringExtra(Intent.EXTRA_TEXT).orEmpty()
        val viewed = intent.dataString.orEmpty()
        return LinkParser.extract(sent.ifBlank { viewed })
    }

    private fun share(uri: Uri, mime: String) {
        val send = Intent(Intent.ACTION_SEND).apply {
            type = mime
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(send, getString(R.string.share)))
    }

    private fun view(uri: Uri, mime: String) {
        val open = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mime)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        try {
            startActivity(open)
        } catch (_: ActivityNotFoundException) {
            Toast.makeText(this, getString(R.string.no_gallery), Toast.LENGTH_SHORT).show()
        }
    }

    companion object {
        fun fileUri(activity: MainActivity, file: File): Uri {
            return FileProvider.getUriForFile(activity, "${activity.packageName}.files", file)
        }
    }
}
