package com.iraqitube.app

import android.app.Activity
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.ui.res.stringResource
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Audiotrack
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.ContentPaste
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Download
import androidx.compose.material.icons.outlined.History
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.PlayArrow
import androidx.compose.material.icons.outlined.Share
import androidx.compose.material.icons.outlined.Videocam
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.window.DialogWindowProvider
import androidx.core.content.FileProvider
import coil.compose.AsyncImage
import coil.request.ImageRequest
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private val Bg = Color(0xFF0C0810)
private val Surface = Color(0xFF1A1320)
private val Surface2 = Color(0xFF251C2C)
private val Pink = Color(0xFFFF4D8D)
private val PinkSoft = Color(0x29FF4D8D)
private val Cream = Color(0xFFF7F1F4)
private val Muted = Color(0xFFB5A8B4)
private val Line = Color(0x22FFFFFF)
private val Crimson = Color(0xFFE23D4A)
private val Green = Color(0xFF3DDC97)

@Composable
fun IraqiTubeTheme(content: @Composable () -> Unit) {
    Box(Modifier.fillMaxSize().background(Bg), content = { content() })
}

@Composable
private fun LocalizedApp(language: String, content: @Composable () -> Unit) {
    val context = LocalContext.current
    val locale = SettingsStore.localeFor(language)
    val localized = remember(language, context) { context.withLocale(locale) }
    CompositionLocalProvider(
        LocalContext provides localized,
        LocalConfiguration provides localized.resources.configuration,
        LocalLayoutDirection provides if (locale.language == "ar") LayoutDirection.Rtl else LayoutDirection.Ltr,
    ) {
        content()
    }
}

@Composable
fun IraqiTubeScreen(
    incomingUrl: String,
    focusDownload: Boolean = false,
    doneId: String = "",
    onFocusHandled: () -> Unit = {},
    onDoneHandled: () -> Unit = {},
    onShare: (Uri, String) -> Unit,
    onView: (Uri, String) -> Unit,
) {
    val context = LocalContext.current
    val app = context.applicationContext as IraqiTubeApp
    val store = remember { LibraryStore(context) }
    val settings = remember { SettingsStore(context) }
    val scope = rememberCoroutineScope()

    var url by remember { mutableStateOf("") }
    var tab by remember { mutableStateOf(0) }
    var showSettings by remember { mutableStateOf(settings.consumeStayInSettings()) }
    var language by remember { mutableStateOf(settings.language) }
    var meta by remember { mutableStateOf<VideoMeta?>(null) }
    var selected by remember { mutableStateOf<QualityOption?>(null) }
    var loading by remember { mutableStateOf(false) }
    var downloading by remember { mutableStateOf(false) }
    var progress by remember { mutableFloatStateOf(0f) }
    var error by remember { mutableStateOf("") }
    var library by remember { mutableStateOf(store.all()) }
    var engine by remember { mutableStateOf(app.engineReady) }
    var saved by remember { mutableStateOf<SavedVideo?>(null) }
    var siteVersion by remember { mutableStateOf<UpdateChecker.Remote?>(null) }
    var showUpdate by remember { mutableStateOf(false) }
    var updateBusy by remember { mutableStateOf(false) }
    var updateProgress by remember { mutableFloatStateOf(0f) }
    var updateError by remember { mutableStateOf("") }
    var pendingApk by remember { mutableStateOf<File?>(null) }
    var fetchGen by remember { mutableIntStateOf(0) }

    val storagePermission = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { }
    val installPermission = rememberLauncherForActivityResult(
        ActivityResultContracts.StartActivityForResult(),
    ) {
        pendingApk?.let { file -> runCatching { UpdateChecker.install(context, file) } }
    }
    val notifyPermission = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { }

    val dlBusy by DownloadBus.busy.collectAsState()
    val dlProgress by DownloadBus.progress.collectAsState()
    val dlError by DownloadBus.error.collectAsState()
    val dlSaved by DownloadBus.saved.collectAsState()
    val dlTitle by DownloadBus.title.collectAsState()

    fun mediaOf(item: SavedVideo): Pair<Uri, String> {
        val file = File(item.path)
        val mime = if (file.extension.lowercase() in setOf("m4a", "mp3", "aac")) "audio/*" else "video/mp4"
        val uri = item.galleryUri?.let { Uri.parse(it) }
            ?: FileProvider.getUriForFile(context, "${context.packageName}.files", file)
        return uri to mime
    }

    fun shareItem(item: SavedVideo) {
        val (uri, mime) = mediaOf(item)
        onShare(uri, mime)
    }

    fun viewItem(item: SavedVideo) {
        val (uri, mime) = mediaOf(item)
        onView(uri, mime)
    }

    fun fetch(link: String = url) {
        val cleaned = LinkParser.extract(link)
        if (cleaned.isEmpty()) {
            error = context.getString(R.string.paste_first)
            return
        }
        url = cleaned
        error = ""
        saved = null
        loading = true
        meta = null
        tab = 0
        val gen = fetchGen + 1
        fetchGen = gen
        scope.launch {
            try {
                val result = withContext(Dispatchers.IO) { Downloader.fetch(cleaned) }
                if (gen != fetchGen) return@launch
                error = ""
                meta = result
                selected = result.options.firstOrNull { it.kind == MediaKind.VIDEO }
                    ?: result.options.firstOrNull()
            } catch (e: Exception) {
                if (gen != fetchGen) return@launch
                meta = null
                error = Downloader.shortMessage(e)
            } finally {
                if (gen == fetchGen) loading = false
            }
        }
    }

    fun download() {
        val current = meta ?: return
        val option = selected ?: return
        if (dlBusy) return
        if (Build.VERSION.SDK_INT < 29) {
            storagePermission.launch(android.Manifest.permission.WRITE_EXTERNAL_STORAGE)
        }
        if (Build.VERSION.SDK_INT >= 33) {
            notifyPermission.launch(android.Manifest.permission.POST_NOTIFICATIONS)
        }
        error = ""
        saved = null
        showSettings = false
        tab = 0
        DownloadService.start(context, current, option)
    }

    fun applyUpdate(remote: UpdateChecker.Remote) {
        updateBusy = true
        updateError = ""
        updateProgress = 0.02f
        scope.launch {
            try {
                val apk = withContext(Dispatchers.IO) {
                    UpdateChecker.download(context, remote) { updateProgress = it }
                }
                pendingApk = apk
                if (UpdateChecker.needsInstallPermission(context)) {
                    installPermission.launch(UpdateChecker.installPermissionIntent(context))
                } else {
                    UpdateChecker.install(context, apk)
                }
                showUpdate = false
            } catch (e: Exception) {
                updateError = Downloader.shortMessage(e)
            } finally {
                updateBusy = false
            }
        }
    }

    LaunchedEffect(Unit) {
        val remote = withContext(Dispatchers.IO) {
            runCatching { UpdateChecker.fetch() }.getOrNull()
        }
        siteVersion = remote
        if (remote != null && UpdateChecker.isNewer(remote.version, UpdateChecker.current(context))) {
            showUpdate = true
        }
    }

    LaunchedEffect(Unit) {
        while (!app.engineReady && app.engineError == null) {
            kotlinx.coroutines.delay(250)
        }
        engine = app.engineReady
        if (app.engineError != null) {
            error = context.getString(R.string.engine_failed, app.engineError)
        }
    }

    LaunchedEffect(incomingUrl, engine) {
        if (!engine) return@LaunchedEffect
        val link = LinkParser.extract(incomingUrl)
        if (link.isBlank()) return@LaunchedEffect
        showSettings = false
        tab = 0
        url = link
        fetch(link)
    }

    LaunchedEffect(dlBusy, dlProgress) {
        downloading = dlBusy
        if (dlBusy) progress = dlProgress
    }
    LaunchedEffect(dlError) {
        if (dlError.isNotBlank()) error = dlError
    }
    LaunchedEffect(dlSaved?.id) {
        val item = dlSaved ?: return@LaunchedEffect
        library = store.all()
        saved = item
    }
    LaunchedEffect(focusDownload) {
        if (!focusDownload) return@LaunchedEffect
        showSettings = false
        tab = 0
        onFocusHandled()
    }
    LaunchedEffect(doneId) {
        if (doneId.isBlank()) return@LaunchedEffect
        showSettings = false
        tab = 0
        saved = store.all().firstOrNull { it.id == doneId } ?: dlSaved
        onDoneHandled()
    }

    fun goHome() {
        showSettings = false
        tab = 0
    }

    BackHandler(enabled = showSettings || tab != 0) {
        goHome()
    }

    LocalizedApp(language) {
    Column(
        Modifier
            .fillMaxSize()
            .statusBarsPadding()
            .navigationBarsPadding()
            .imePadding(),
    ) {
        Header(
            engine = engine,
            showSettings = showSettings,
            onSettings = {
                if (showSettings) goHome() else showSettings = true
            },
            modifier = Modifier.padding(horizontal = 20.dp, vertical = 12.dp),
        )
        val page = when {
            showSettings -> "settings"
            tab == 0 -> "home"
            else -> "history"
        }
        Box(
            Modifier
                .weight(1f)
                .fillMaxWidth(),
        ) {
            key(page) {
            Column(
                Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp)
                    .padding(bottom = 16.dp),
            ) {
                when (page) {
                    "settings" -> SettingsBody(
                        language = language,
                        onLanguage = {
                            settings.stayInSettings = true
                            language = it
                            settings.language = it
                            (context as? Activity)?.recreate()
                        },
                        siteVersion = siteVersion,
                        updateBusy = updateBusy,
                        updateProgress = updateProgress,
                        updateError = updateError,
                        onCheckUpdate = {
                            scope.launch {
                                updateError = ""
                                val remote = withContext(Dispatchers.IO) {
                                    runCatching { UpdateChecker.fetch() }.getOrElse {
                                        updateError = context.getString(R.string.update_failed)
                                        null
                                    }
                                }
                                siteVersion = remote
                                if (remote != null && UpdateChecker.isNewer(remote.version, UpdateChecker.current(context))) {
                                    showUpdate = true
                                }
                            }
                        },
                        onUpdate = { siteVersion?.let { applyUpdate(it) } },
                    )
                    "home" -> HomeBody(
                        url = url,
                        onUrl = { url = it; error = "" },
                        onPaste = {
                            val clip = (context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager)
                                .primaryClip?.getItemAt(0)?.text?.toString().orEmpty()
                            val link = LinkParser.extract(clip)
                            if (link.isNotBlank()) {
                                url = link
                                fetch(link)
                            }
                        },
                        onClear = { url = ""; meta = null; saved = null; error = "" },
                        onFetch = { fetch() },
                        engine = engine,
                        loading = loading,
                        downloading = downloading,
                        downloadTitle = dlTitle,
                        error = error,
                        meta = meta,
                        selected = selected,
                        onSelect = { selected = it },
                        onDownload = { download() },
                        progress = progress,
                    )
                    else -> LibraryBody(
                        items = library,
                        onView = { viewItem(it) },
                        onShare = { shareItem(it) },
                        onDelete = {
                            store.remove(it.id)
                            library = store.all()
                        },
                    )
                }
            }
            }
        }

        if (!showSettings) {
            TabBar(tab) { tab = it }
        }
    }

    if (showUpdate) {
        siteVersion?.let { remote ->
            UpdateDialog(
                remote = remote,
                local = UpdateChecker.current(context),
                busy = updateBusy,
                progress = updateProgress,
                error = updateError,
                onLater = { showUpdate = false },
                onUpdate = { applyUpdate(remote) },
            )
        }
    }

    saved?.let { item ->
        DoneDialog(
            onClose = { saved = null },
            onView = {
                viewItem(item)
                saved = null
            },
            onShare = {
                shareItem(item)
                saved = null
            },
        )
    }
    }
}

@Composable
private fun Header(engine: Boolean, showSettings: Boolean, onSettings: () -> Unit, modifier: Modifier = Modifier) {
    Row(modifier, verticalAlignment = Alignment.CenterVertically) {
        Box(
            Modifier
                .size(40.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(Color(0xFF140C12)),
            contentAlignment = Alignment.Center,
        ) {
            Text("N", color = Pink, fontSize = 22.sp, fontWeight = FontWeight.Black)
        }
        Spacer(Modifier.width(12.dp))
        Text(
            if (showSettings) stringResource(R.string.settings) else stringResource(R.string.app_name),
            color = Cream,
            fontSize = 20.sp,
            fontWeight = FontWeight.Black,
            maxLines = 1,
            modifier = Modifier.weight(1f),
        )
        Text(
            if (engine) stringResource(R.string.ready) else stringResource(R.string.starting),
            color = if (engine) Green else Muted,
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
        )
        IconButton(onClick = onSettings) {
            Icon(
                if (showSettings) Icons.AutoMirrored.Outlined.ArrowBack else Icons.Outlined.Settings,
                contentDescription = stringResource(if (showSettings) R.string.back else R.string.settings),
                tint = Cream,
            )
        }
    }
}

@Composable
private fun HomeBody(
    url: String,
    onUrl: (String) -> Unit,
    onPaste: () -> Unit,
    onClear: () -> Unit,
    onFetch: () -> Unit,
    engine: Boolean,
    loading: Boolean,
    downloading: Boolean,
    downloadTitle: String = "",
    error: String,
    meta: VideoMeta?,
    selected: QualityOption?,
    onSelect: (QualityOption) -> Unit,
    onDownload: () -> Unit,
    progress: Float,
) {
    OutlinedTextField(
        value = url,
        onValueChange = onUrl,
        modifier = Modifier.fillMaxWidth(),
        placeholder = { Text(stringResource(R.string.paste_or_share), color = Muted) },
        colors = fieldColors(),
        minLines = 2,
        shape = RoundedCornerShape(18.dp),
    )
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
        TextButton(onClick = onPaste) {
            Icon(Icons.Outlined.ContentPaste, contentDescription = null, tint = Pink, modifier = Modifier.size(16.dp))
            Spacer(Modifier.width(6.dp))
            Text(stringResource(R.string.paste), color = Pink, fontWeight = FontWeight.Bold)
        }
        TextButton(onClick = onClear) {
            Icon(Icons.Outlined.Close, contentDescription = null, tint = Muted, modifier = Modifier.size(16.dp))
            Spacer(Modifier.width(6.dp))
            Text(stringResource(R.string.clear), color = Muted)
        }
    }
    PinkButton(
        label = if (loading) stringResource(R.string.loading) else stringResource(R.string.fetch),
        icon = Icons.Outlined.PlayArrow,
        enabled = engine && !loading && !downloading,
        loading = loading,
        onClick = onFetch,
    )

    if (error.isNotBlank()) {
        Text(
            error,
            color = Crimson,
            fontSize = 13.sp,
            maxLines = 3,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(top = 12.dp).fillMaxWidth(),
        )
    }

    meta?.let { video ->
        Spacer(Modifier.height(20.dp))
        Box {
            if (video.thumbnail != null) {
                RemoteThumb(
                    url = video.thumbnail,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(190.dp)
                        .clip(RoundedCornerShape(20.dp)),
                )
            } else {
                Box(
                    Modifier
                        .fillMaxWidth()
                        .height(190.dp)
                        .clip(RoundedCornerShape(20.dp))
                        .background(Surface2),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Outlined.Videocam, contentDescription = null, tint = Pink, modifier = Modifier.size(36.dp))
                }
            }
            Box(
                Modifier
                    .matchParentSize()
                    .clip(RoundedCornerShape(20.dp))
                    .background(Brush.verticalGradient(listOf(Color.Transparent, Color(0xCC0C0810)))),
            )
        }
        Spacer(Modifier.height(12.dp))
        Text(video.title, color = Cream, fontSize = 20.sp, fontWeight = FontWeight.Bold)
        if (!video.author.isNullOrBlank()) {
            Text(video.author, color = Muted, fontSize = 13.sp)
        }
        Spacer(Modifier.height(16.dp))

        val videos = video.options.filter { it.kind == MediaKind.VIDEO }
        val audios = video.options.filter { it.kind == MediaKind.AUDIO }

        if (videos.isNotEmpty()) {
            SectionLabel(Icons.Outlined.Videocam, stringResource(R.string.video))
            videos.forEach { option ->
                OptionRow(option, option.id == selected?.id) { onSelect(option) }
            }
        }
        if (audios.isNotEmpty()) {
            Spacer(Modifier.height(12.dp))
            SectionLabel(Icons.Outlined.Audiotrack, stringResource(R.string.audio))
            audios.forEach { option ->
                OptionRow(option, option.id == selected?.id) { onSelect(option) }
            }
        }

        Spacer(Modifier.height(14.dp))
        PinkButton(
            label = if (downloading) stringResource(R.string.downloading) else stringResource(R.string.download),
            icon = Icons.Outlined.Download,
            enabled = !downloading,
            loading = downloading,
            onClick = onDownload,
        )
        if (downloading) {
            DownloadBar(progress)
        }
    }

    if (downloading && meta == null) {
        Spacer(Modifier.height(20.dp))
        if (downloadTitle.isNotBlank()) {
            Text(downloadTitle, color = Cream, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(10.dp))
        }
        DownloadBar(progress)
    }
}

@Composable
private fun DownloadBar(progress: Float) {
    Spacer(Modifier.height(10.dp))
    LinearProgressIndicator(
        progress = { progress },
        modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(8.dp)),
        color = Pink,
        trackColor = Surface,
    )
    Text("${(progress * 100).toInt()}%", color = Muted, fontSize = 12.sp, modifier = Modifier.padding(top = 6.dp))
}

@Composable
private fun SectionLabel(icon: ImageVector, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(bottom = 8.dp)) {
        Icon(icon, contentDescription = null, tint = Pink, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(8.dp))
        Text(label, color = Cream, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun OptionRow(option: QualityOption, active: Boolean, onClick: () -> Unit) {
    val icon = if (option.kind == MediaKind.AUDIO) Icons.Outlined.Audiotrack else Icons.Outlined.Videocam
    val bg by animateColorAsState(if (active) PinkSoft else Surface, tween(220), label = "opt-bg")
    val stroke by animateColorAsState(if (active) Pink else Line, tween(220), label = "opt-line")
    val badge by animateColorAsState(if (active) Pink else Surface2, tween(220), label = "opt-badge")
    Row(
        Modifier
            .fillMaxWidth()
            .padding(top = 8.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(bg)
            .border(1.dp, stroke, RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier
                .size(36.dp)
                .clip(CircleShape)
                .background(badge),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
        }
        Text(
            qualityLabel(option),
            color = Cream,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(start = 12.dp).weight(1f),
        )
        if (active) {
            Icon(Icons.Outlined.Download, contentDescription = null, tint = Pink, modifier = Modifier.size(18.dp))
        }
    }
}

@Composable
private fun DoneDialog(onClose: () -> Unit, onView: () -> Unit, onShare: () -> Unit) {
    Dialog(
        onDismissRequest = onClose,
        properties = DialogProperties(usePlatformDefaultWidth = false),
    ) {
        val window = (LocalView.current.parent as? DialogWindowProvider)?.window
        SideEffect {
            window?.setBackgroundDrawableResource(android.R.color.transparent)
            window?.setLayout(
                android.view.ViewGroup.LayoutParams.MATCH_PARENT,
                android.view.ViewGroup.LayoutParams.MATCH_PARENT,
            )
            window?.setDimAmount(0.55f)
        }
        Box(Modifier.fillMaxSize()) {
            ConfettiBurst(active = true)
            Column(
                Modifier
                    .align(Alignment.Center)
                    .padding(horizontal = 20.dp)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(28.dp))
                    .background(Surface)
                    .clickable(enabled = false) {}
                    .padding(20.dp),
            ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    Modifier
                        .size(40.dp)
                        .clip(CircleShape)
                        .background(PinkSoft),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Outlined.Download, contentDescription = null, tint = Pink, modifier = Modifier.size(20.dp))
                }
                Spacer(Modifier.width(12.dp))
                Text(stringResource(R.string.downloaded), color = Cream, fontWeight = FontWeight.Bold, fontSize = 20.sp, modifier = Modifier.weight(1f))
                IconButton(onClick = onClose) {
                    Icon(Icons.Outlined.Close, contentDescription = stringResource(R.string.close), tint = Muted)
                }
            }
            Spacer(Modifier.height(16.dp))
            ActionTile(Icons.Outlined.PlayArrow, stringResource(R.string.play), onView)
            Spacer(Modifier.height(10.dp))
            ActionTile(Icons.Outlined.Share, stringResource(R.string.share), onShare)
            }
        }
    }
}

@Composable
private fun UpdateDialog(
    remote: UpdateChecker.Remote,
    local: String,
    busy: Boolean,
    progress: Float,
    error: String,
    onLater: () -> Unit,
    onUpdate: () -> Unit,
) {
    Dialog(onDismissRequest = { if (!busy) onLater() }) {
        Column(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(28.dp))
                .background(Surface)
                .padding(20.dp),
        ) {
            Text(stringResource(R.string.update_available, remote.version), color = Cream, fontWeight = FontWeight.Bold, fontSize = 20.sp)
            Spacer(Modifier.height(8.dp))
            Text(stringResource(R.string.update_body, local, remote.version), color = Muted, fontSize = 14.sp)
            if (error.isNotBlank()) {
                Spacer(Modifier.height(8.dp))
                Text(error, color = Crimson, fontSize = 13.sp)
            }
            if (busy) {
                Spacer(Modifier.height(14.dp))
                Text(stringResource(R.string.update_downloading), color = Muted, fontSize = 13.sp)
                Spacer(Modifier.height(8.dp))
                LinearProgressIndicator(
                    progress = { progress },
                    modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(8.dp)),
                    color = Pink,
                    trackColor = Surface2,
                )
            } else {
                Spacer(Modifier.height(16.dp))
                PinkButton(
                    label = stringResource(R.string.update_now),
                    icon = Icons.Outlined.Download,
                    enabled = true,
                    loading = false,
                    onClick = onUpdate,
                )
                TextButton(onClick = onLater, modifier = Modifier.fillMaxWidth()) {
                    Text(stringResource(R.string.update_later), color = Muted)
                }
            }
        }
    }
}

@Composable
private fun ActionTile(icon: ImageVector, label: String, onClick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(Surface2)
            .clickable(onClick = onClick)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier
                .size(44.dp)
                .clip(CircleShape)
                .background(Pink),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = Color.White, modifier = Modifier.size(22.dp))
        }
        Text(label, color = Cream, fontWeight = FontWeight.Bold, fontSize = 16.sp, modifier = Modifier.padding(start = 14.dp))
    }
}

@Composable
private fun LibraryBody(
    items: List<SavedVideo>,
    onView: (SavedVideo) -> Unit,
    onShare: (SavedVideo) -> Unit,
    onDelete: (SavedVideo) -> Unit,
) {
    Text(stringResource(R.string.download_history), color = Cream, fontSize = 28.sp, fontWeight = FontWeight.Black)
    Spacer(Modifier.height(16.dp))
    if (items.isEmpty()) {
        Text(stringResource(R.string.no_downloads), color = Muted)
        return
    }
    items.forEach { item ->
        Row(
            Modifier
                .fillMaxWidth()
                .padding(bottom = 8.dp)
                .clip(RoundedCornerShape(18.dp))
                .background(Surface)
                .clickable { onView(item) }
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (item.thumbnail != null) {
                RemoteThumb(
                    url = item.thumbnail,
                    modifier = Modifier.size(64.dp).clip(RoundedCornerShape(12.dp)),
                )
            } else {
                Box(
                    Modifier
                        .size(64.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(Surface2),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Outlined.Videocam, contentDescription = null, tint = Pink)
                }
            }
            Column(Modifier.weight(1f).padding(horizontal = 12.dp)) {
                Text(item.title, color = Cream, fontWeight = FontWeight.Bold, maxLines = 2)
                Text(qualityName(item.quality), color = Muted, fontSize = 12.sp)
            }
        }
        Row(Modifier.padding(bottom = 14.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SmallIconAction(Icons.Outlined.PlayArrow, stringResource(R.string.play)) { onView(item) }
            SmallIconAction(Icons.Outlined.Share, stringResource(R.string.share)) { onShare(item) }
            TextButton(onClick = { onDelete(item) }) {
                Icon(Icons.Outlined.Delete, contentDescription = null, tint = Crimson, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(6.dp))
                Text(stringResource(R.string.delete), color = Crimson)
            }
        }
    }
}

@Composable
private fun SmallIconAction(icon: ImageVector, label: String, onClick: () -> Unit) {
    TextButton(onClick = onClick) {
        Icon(icon, contentDescription = null, tint = Cream, modifier = Modifier.size(16.dp))
        Spacer(Modifier.width(6.dp))
        Text(label, color = Cream)
    }
}


@Composable
private fun PinkButton(
    label: String,
    icon: ImageVector,
    enabled: Boolean,
    loading: Boolean,
    onClick: () -> Unit,
) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier.fillMaxWidth().height(54.dp),
        colors = ButtonDefaults.buttonColors(containerColor = Pink, contentColor = Color.White, disabledContainerColor = Color(0xFF4A2A38)),
        shape = RoundedCornerShape(28.dp),
    ) {
        if (loading) {
            CircularProgressIndicator(Modifier.size(18.dp), color = Color.White, strokeWidth = 2.dp)
        } else {
            Icon(icon, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
            Text(label, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun TabBar(tab: Int, onChange: (Int) -> Unit) {
    val items = listOf(
        stringResource(R.string.home) to Icons.Outlined.Home,
        stringResource(R.string.history) to Icons.Outlined.History,
    )
    Row(
        Modifier
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .clip(RoundedCornerShape(28.dp))
            .background(Color(0xFF161018))
            .padding(6.dp),
    ) {
        items.forEachIndexed { index, (label, icon) ->
            val active = tab == index
            val bg by animateColorAsState(if (active) Pink else Color.Transparent, tween(220), label = "tab-bg")
            val tint by animateColorAsState(if (active) Color.White else Muted, tween(220), label = "tab-tint")
            Row(
                Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(22.dp))
                    .background(bg)
                    .clickable { onChange(index) }
                    .padding(vertical = 10.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(6.dp))
                Text(label, color = tint, fontWeight = FontWeight.Bold, fontSize = 13.sp)
            }
        }
    }
}

@Composable
private fun RemoteThumb(url: String, modifier: Modifier) {
    val context = LocalContext.current
    AsyncImage(
        model = ImageRequest.Builder(context)
            .data(url)
            .crossfade(true)
            .addHeader("User-Agent", InstagramDownloader.BOT_UA)
            .addHeader("Referer", "https://www.instagram7.com/")
            .build(),
        contentDescription = null,
        modifier = modifier,
        contentScale = ContentScale.Crop,
    )
}

@Composable
private fun SettingsBody(
    language: String,
    onLanguage: (String) -> Unit,
    siteVersion: UpdateChecker.Remote?,
    updateBusy: Boolean,
    updateProgress: Float,
    updateError: String,
    onCheckUpdate: () -> Unit,
    onUpdate: () -> Unit,
) {
    val context = LocalContext.current
    Text(stringResource(R.string.language), color = Cream, fontWeight = FontWeight.Bold)
    Spacer(Modifier.height(8.dp))
    LanguageRow(stringResource(R.string.language_system), language == SettingsStore.LANG_SYSTEM) {
        onLanguage(SettingsStore.LANG_SYSTEM)
    }
    LanguageRow(stringResource(R.string.language_en), language == SettingsStore.LANG_EN) {
        onLanguage(SettingsStore.LANG_EN)
    }
    LanguageRow(stringResource(R.string.language_ar), language == SettingsStore.LANG_AR) {
        onLanguage(SettingsStore.LANG_AR)
    }
    Spacer(Modifier.height(28.dp))
    Text(stringResource(R.string.about_title), color = Cream, fontWeight = FontWeight.Bold)
    Spacer(Modifier.height(8.dp))
    Text(stringResource(R.string.about_body), color = Muted, fontSize = 14.sp)
    Spacer(Modifier.height(28.dp))
    Text(stringResource(R.string.credits), color = Cream, fontWeight = FontWeight.Bold)
    Spacer(Modifier.height(8.dp))
    CreditRow(
        icon = R.mipmap.ic_launcher,
        label = stringResource(R.string.credit_iraqies),
        handle = "github.com/iraqies",
        url = "https://github.com/iraqies",
        circleIcon = true,
    )
    CreditRow(
        icon = R.drawable.ic_telegram,
        label = stringResource(R.string.credit_telegram),
        handle = "t.me/auratistic",
        url = "https://t.me/auratistic",
        circleIcon = true,
    )
    CreditRow(
        icon = R.drawable.ic_stalk,
        label = stringResource(R.string.credit_stalk),
        handle = "stalk.gg/x",
        url = "https://stalk.gg/x",
    )
    Spacer(Modifier.height(16.dp))
    val versionName = remember { UpdateChecker.current(context) }
    Text(stringResource(R.string.version, versionName), color = Muted, fontSize = 13.sp)
    val remote = siteVersion
    when {
        updateBusy -> {
            Spacer(Modifier.height(8.dp))
            Text(stringResource(R.string.update_downloading), color = Muted, fontSize = 13.sp)
            Spacer(Modifier.height(8.dp))
            LinearProgressIndicator(
                progress = { updateProgress },
                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(99.dp)),
                color = Pink,
                trackColor = Surface2,
            )
        }
        updateError.isNotBlank() -> {
            Spacer(Modifier.height(8.dp))
            Text(updateError, color = Crimson, fontSize = 13.sp)
        }
        remote != null && UpdateChecker.isNewer(remote.version, versionName) -> {
            Spacer(Modifier.height(8.dp))
            Text(stringResource(R.string.update_available, remote.version), color = Pink, fontSize = 13.sp)
            TextButton(onClick = onUpdate) {
                Text(stringResource(R.string.update_now), color = Pink, fontWeight = FontWeight.Bold)
            }
        }
        remote != null -> {
            Spacer(Modifier.height(8.dp))
            Text(stringResource(R.string.update_current), color = Muted, fontSize = 13.sp)
        }
        else -> {
            Spacer(Modifier.height(8.dp))
            TextButton(onClick = onCheckUpdate) {
                Text(stringResource(R.string.update_check), color = Pink, fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
private fun LanguageRow(label: String, active: Boolean, onClick: () -> Unit) {
    val bg by animateColorAsState(if (active) PinkSoft else Surface, tween(220), label = "lang-bg")
    val stroke by animateColorAsState(if (active) Pink else Line, tween(220), label = "lang-line")
    Row(
        Modifier
            .fillMaxWidth()
            .padding(top = 8.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(bg)
            .border(1.dp, stroke, RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, color = Cream, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
        if (active) {
            Box(Modifier.size(10.dp).clip(CircleShape).background(Pink))
        }
    }
}

@Composable
private fun CreditRow(
    icon: Int,
    label: String,
    handle: String,
    url: String,
    circleIcon: Boolean = false,
) {
    val context = LocalContext.current
    Row(
        Modifier
            .fillMaxWidth()
            .padding(top = 8.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(Surface)
            .clickable {
                runCatching {
                    context.startActivity(
                        Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                }
            }
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Image(
            painter = painterResource(icon),
            contentDescription = label,
            modifier = Modifier
                .size(36.dp)
                .clip(if (circleIcon) CircleShape else RoundedCornerShape(10.dp)),
            contentScale = if (circleIcon) ContentScale.Crop else ContentScale.Fit,
        )
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(label, color = Cream, fontWeight = FontWeight.SemiBold)
            Text(handle, color = Muted, fontSize = 13.sp)
        }
    }
}

@Composable
private fun qualityLabel(option: QualityOption) = qualityName(option.label)

@Composable
private fun qualityName(label: String): String = when (label) {
    "HD" -> stringResource(R.string.quality_hd)
    "SD" -> stringResource(R.string.quality_sd)
    "Audio" -> stringResource(R.string.quality_audio)
    else -> label
}

@Composable
private fun fieldColors() = OutlinedTextFieldDefaults.colors(
    focusedBorderColor = Pink,
    unfocusedBorderColor = Line,
    focusedTextColor = Cream,
    unfocusedTextColor = Cream,
    cursorColor = Pink,
    focusedContainerColor = Surface,
    unfocusedContainerColor = Surface,
)
