package com.iraqitube.app

import android.content.ActivityNotFoundException
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

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        incomingUrl = readIncoming(intent)
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
        startActivity(Intent.createChooser(send, "Share"))
    }

    private fun view(uri: Uri, mime: String) {
        val open = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mime)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        try {
            startActivity(open)
        } catch (_: ActivityNotFoundException) {
            Toast.makeText(this, "No gallery app found", Toast.LENGTH_SHORT).show()
        }
    }

    companion object {
        fun fileUri(activity: MainActivity, file: File): Uri {
            return FileProvider.getUriForFile(activity, "${activity.packageName}.files", file)
        }
    }
}
