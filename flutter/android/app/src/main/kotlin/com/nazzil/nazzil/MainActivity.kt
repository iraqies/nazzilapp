package com.nazzil.nazzil

import android.app.UiModeManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val pending = mutableListOf<String>()
    private var sink: EventChannel.EventSink? = null
    private var lastSent: String? = null
    private var host: MethodChannel? = null
    private var pendingOpenLibrary = false
    private var pendingResume = false
    private var pendingCancel = false
    private var dartReady = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        EventChannel(messenger, CHANNEL_EVENTS).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    sink = events
                    pending.forEach { events.success(it) }
                    pending.clear()
                    readLink(intent)?.let(::emit)
                }

                override fun onCancel(arguments: Any?) {
                    sink = null
                }
            },
        )
        MethodChannel(messenger, CHANNEL_METHODS).setMethodCallHandler { call, result ->
            if (call.method == "initial") {
                result.success(readLink(intent))
            } else {
                result.notImplemented()
            }
        }
        host = MethodChannel(messenger, CHANNEL_HOST).also { channel ->
            HostBridge.channel = channel
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "drain" -> {
                        dartReady = true
                        result.success(
                            mapOf(
                                "library" to pendingOpenLibrary,
                                "resume" to pendingResume,
                                "cancel" to pendingCancel,
                            ),
                        )
                        pendingOpenLibrary = false
                        pendingResume = false
                        pendingCancel = false
                    }
                    "words" -> {
                        DownloadNotifier.setWords(this, call.arguments as? Map<*, *>)
                        result.success(null)
                    }
                    "theme" -> {
                        followTheme(call.argument<String>("theme"))
                        result.success(null)
                    }
                    "start" -> {
                        val title = call.argument<String>("title") ?: "Nazzil"
                        val percent = call.argument<Int>("percent") ?: 1
                        DownloadService.start(this, title, percent)
                        result.success(null)
                    }
                    "progress" -> {
                        val title = call.argument<String>("title") ?: "Nazzil"
                        val percent = call.argument<Int>("percent") ?: 0
                        DownloadNotifier.updateProgress(this, title, percent)
                        result.success(null)
                    }
                    "paused" -> {
                        val title = call.argument<String>("title") ?: "Nazzil"
                        val percent = call.argument<Int>("percent") ?: 0
                        DownloadNotifier.paused(this, title, percent)
                        result.success(null)
                    }
                    "done" -> {
                        val title = call.argument<String>("title") ?: "Nazzil"
                        val path = call.argument<String>("path")
                        DownloadNotifier.done(this, title, path)
                        result.success(null)
                    }
                    "failed" -> {
                        DownloadNotifier.failed(this, call.argument<String>("message") ?: "")
                        result.success(null)
                    }
                    "stop" -> {
                        DownloadService.stop(this)
                        result.success(null)
                    }
                    "openFile" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("missing", "No path", null)
                            return@setMethodCallHandler
                        }
                        val opened = openFile(path)
                        if (opened) result.success(null) else result.error("missing", "File is gone", null)
                    }
                    "tagAudio" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("missing", "No path", null)
                            return@setMethodCallHandler
                        }
                        val tagged = AudioTagger.apply(
                            File(path),
                            call.argument<String>("title") ?: "Nazzil",
                            call.argument<String>("author"),
                            call.argument<String>("coverPath"),
                            call.argument<String>("lyricsPlain"),
                            call.argument<String>("lyricsSynced"),
                        )
                        result.success(tagged.absolutePath)
                    }
                    "saveAudio" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("missing", "No path", null)
                            return@setMethodCallHandler
                        }
                        val main = Handler(Looper.getMainLooper())
                        Thread {
                            try {
                                val saved = MediaSaver.saveAudio(applicationContext, File(path))
                                main.post { result.success(saved) }
                            } catch (error: Exception) {
                                main.post { result.error("save", error.message, null) }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }
        }
        readLink(intent)?.let(::emit)
        maybeOpenFromNotification(intent)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        maybeOpenFromNotification(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        readLink(intent)?.let(::emit)
        maybeOpenFromNotification(intent)
    }

    private fun maybeOpenFromNotification(intent: Intent?) {
        if (intent == null) return
        val resume = intent.action == DownloadService.ACTION_RESUME ||
            intent.getBooleanExtra(DownloadNotifier.EXTRA_RESUME, false)
        val cancel = intent.action == DownloadService.ACTION_CANCEL ||
            intent.getBooleanExtra(DownloadNotifier.EXTRA_CANCEL, false)
        val open = intent.action == DownloadNotifier.ACTION_OPEN || resume || cancel
        if (!open) return
        val library = intent.getBooleanExtra(DownloadNotifier.EXTRA_OPEN_LIBRARY, resume || cancel)
        val channel = host
        if (channel != null && dartReady) {
            channel.invokeMethod("opened", mapOf("library" to library))
            if (resume) channel.invokeMethod("resume", null)
            if (cancel) channel.invokeMethod("cancel", null)
        } else {
            pendingOpenLibrary = library || pendingOpenLibrary
            pendingResume = resume || pendingResume
            pendingCancel = cancel || pendingCancel
        }
    }

    /**
     * The phone draws the launch screen before the app runs, so it has to be told beforehand
     * whether the app is set light or dark. Android 12 is the first that can be told; before
     * it the launch screen is the dark one (res/values).
     */
    private fun followTheme(theme: String?) {
        if (Build.VERSION.SDK_INT < 31) return
        val phone = getSystemService(UiModeManager::class.java) ?: return
        runCatching {
            phone.setApplicationNightMode(
                when (theme) {
                    "light" -> UiModeManager.MODE_NIGHT_NO
                    "dark" -> UiModeManager.MODE_NIGHT_YES
                    // Nothing of the app's own: day and night as the phone has them.
                    else -> UiModeManager.MODE_NIGHT_AUTO
                },
            )
        }
    }

    private fun openFile(path: String): Boolean {
        val file = File(path)
        if (!file.exists()) return false
        val uri = FileProvider.getUriForFile(this, "$packageName.files", file)
        val view = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, DownloadNotifier.mimeOf(file))
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return runCatching { startActivity(view) }.isSuccess
    }

    private fun emit(url: String) {
        if (url == lastSent) return
        lastSent = url
        val events = sink
        if (events != null) {
            events.success(url)
        } else {
            pending.add(url)
        }
    }

    private fun readLink(intent: Intent?): String? {
        if (intent == null) return null
        val chunks = ArrayList<String>()
        fun add(value: String?) {
            val text = value?.trim().orEmpty()
            if (text.isNotEmpty()) chunks.add(text)
        }
        add(intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString())
        add(intent.getStringExtra(Intent.EXTRA_TEXT))
        add(intent.getCharSequenceExtra(Intent.EXTRA_HTML_TEXT)?.toString())
        add(intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString())
        add(intent.getStringExtra(Intent.EXTRA_SUBJECT))
        add(intent.dataString)
        val clip = intent.clipData
        if (clip != null) {
            for (i in 0 until clip.itemCount) {
                val item = clip.getItemAt(i)
                add(item.coerceToText(this)?.toString())
                add(item.text?.toString())
                add(item.uri?.toString())
            }
        }
        if (Build.VERSION.SDK_INT >= 33) {
            intent.extras?.keySet()?.forEach { key ->
                val value = intent.extras?.get(key)
                if (value is CharSequence) add(value.toString())
            }
        }
        return chunks.firstOrNull { candidate ->
            candidate.contains("http", ignoreCase = true) ||
                candidate.contains("tiktok", ignoreCase = true) ||
                candidate.contains("youtu", ignoreCase = true) ||
                candidate.contains("instagram", ignoreCase = true) ||
                candidate.contains("facebook", ignoreCase = true) ||
                candidate.contains("fb.watch", ignoreCase = true)
        } ?: chunks.firstOrNull()
    }

    companion object {
        private const val CHANNEL_EVENTS = "nazzil/share"
        private const val CHANNEL_METHODS = "nazzil/share/methods"
        private const val CHANNEL_HOST = "nazzil/host"
    }
}
