package com.iraqitube.app

import android.content.ClipboardManager
import android.content.Context
import android.net.Uri
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.material.icons.outlined.PhotoLibrary
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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.core.content.FileProvider
import coil.compose.AsyncImage
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
fun IraqiTubeScreen(
    incomingUrl: String,
    onShare: (Uri, String) -> Unit,
    onView: (Uri, String) -> Unit,
) {
    val context = LocalContext.current
    val app = context.applicationContext as IraqiTubeApp
    val store = remember { LibraryStore(context) }
    val scope = rememberCoroutineScope()

    var url by remember { mutableStateOf("") }
    var tab by remember { mutableStateOf(0) }
    var meta by remember { mutableStateOf<VideoMeta?>(null) }
    var selected by remember { mutableStateOf<QualityOption?>(null) }
    var loading by remember { mutableStateOf(false) }
    var downloading by remember { mutableStateOf(false) }
    var progress by remember { mutableFloatStateOf(0f) }
    var error by remember { mutableStateOf("") }
    var library by remember { mutableStateOf(store.all()) }
    var engine by remember { mutableStateOf(app.engineReady) }
    var saved by remember { mutableStateOf<SavedVideo?>(null) }

    val storagePermission = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { }

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
            error = "Paste a link first."
            return
        }
        url = cleaned
        error = ""
        saved = null
        loading = true
        meta = null
        tab = 0
        scope.launch {
            try {
                val result = withContext(Dispatchers.IO) { Downloader.fetch(cleaned) }
                meta = result
                selected = result.options.firstOrNull { it.kind == MediaKind.VIDEO }
                    ?: result.options.firstOrNull()
            } catch (e: Exception) {
                error = Downloader.shortMessage(e)
            } finally {
                loading = false
            }
        }
    }

    fun download() {
        val current = meta ?: return
        val option = selected ?: return
        if (Build.VERSION.SDK_INT < 29) {
            storagePermission.launch(android.Manifest.permission.WRITE_EXTERNAL_STORAGE)
        }
        downloading = true
        progress = 0.02f
        error = ""
        saved = null
        scope.launch {
            try {
                val file = withContext(Dispatchers.IO) {
                    Downloader.download(context, current.webpageUrl, option, current.title) {
                        progress = it.coerceAtMost(0.9f)
                    }
                }
                progress = 0.92f
                val gallery = withContext(Dispatchers.IO) {
                    GallerySaver.save(context, file, current.title)
                }
                val item = SavedVideo(
                    id = "${current.id}-${file.name}",
                    title = current.title,
                    author = current.author,
                    platform = current.platform,
                    path = file.absolutePath,
                    galleryUri = gallery.toString(),
                    quality = option.label,
                    createdAt = System.currentTimeMillis(),
                    thumbnail = current.thumbnail,
                )
                store.add(item)
                library = store.all()
                saved = item
                progress = 1f
            } catch (e: Exception) {
                error = Downloader.shortMessage(e)
            } finally {
                downloading = false
            }
        }
    }

    LaunchedEffect(Unit) {
        while (!app.engineReady && app.engineError == null) {
            kotlinx.coroutines.delay(250)
        }
        engine = app.engineReady
        if (app.engineError != null) error = "Engine failed to start: ${app.engineError}"
    }

    LaunchedEffect(incomingUrl, engine) {
        if (!engine) return@LaunchedEffect
        val link = LinkParser.extract(incomingUrl)
        if (link.isBlank()) return@LaunchedEffect
        url = link
        fetch(link)
    }

    Column(
        Modifier
            .fillMaxSize()
            .statusBarsPadding()
            .navigationBarsPadding()
            .imePadding(),
    ) {
        Column(
            Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 12.dp),
        ) {
            Header(engine)
            Spacer(Modifier.height(18.dp))

            if (tab == 0) {
                HomeBody(
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
                    error = error,
                    meta = meta,
                    selected = selected,
                    onSelect = { selected = it },
                    onDownload = { download() },
                    progress = progress,
                )
            } else {
                LibraryBody(
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

        TabBar(tab) { tab = it }
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

@Composable
private fun Header(engine: Boolean) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(
            Modifier
                .size(40.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(Pink),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Outlined.PlayArrow, contentDescription = null, tint = Color.White, modifier = Modifier.size(22.dp))
        }
        Spacer(Modifier.width(12.dp))
        Text("IraqiTube", color = Cream, fontSize = 20.sp, fontWeight = FontWeight.Black, modifier = Modifier.weight(1f))
        Text(
            if (engine) "Ready" else "Starting…",
            color = if (engine) Green else Muted,
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
        )
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
    error: String,
    meta: VideoMeta?,
    selected: QualityOption?,
    onSelect: (QualityOption) -> Unit,
    onDownload: () -> Unit,
    progress: Float,
) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        PlatformChip("YouTube", Color(0xFFFF3B30))
        PlatformChip("TikTok", Color(0xFF25F4EE))
        PlatformChip("Instagram", Color(0xFFE1306C))
        PlatformChip("Facebook", Color(0xFF1877F2))
    }
    Spacer(Modifier.height(16.dp))

    OutlinedTextField(
        value = url,
        onValueChange = onUrl,
        modifier = Modifier.fillMaxWidth(),
        placeholder = { Text("Paste or share a link", color = Muted) },
        colors = fieldColors(),
        minLines = 2,
        shape = RoundedCornerShape(18.dp),
    )
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
        TextButton(onClick = onPaste) {
            Icon(Icons.Outlined.ContentPaste, contentDescription = null, tint = Pink, modifier = Modifier.size(16.dp))
            Spacer(Modifier.width(6.dp))
            Text("Paste", color = Pink, fontWeight = FontWeight.Bold)
        }
        TextButton(onClick = onClear) {
            Icon(Icons.Outlined.Close, contentDescription = null, tint = Muted, modifier = Modifier.size(16.dp))
            Spacer(Modifier.width(6.dp))
            Text("Clear", color = Muted)
        }
    }
    PinkButton(
        label = if (loading) "Loading…" else "Fetch",
        icon = Icons.Outlined.PlayArrow,
        enabled = engine && !loading && !downloading,
        loading = loading,
        onClick = onFetch,
    )

    if (error.isNotBlank()) {
        Spacer(Modifier.height(12.dp))
        Text(error, color = Crimson, fontSize = 13.sp)
    }

    meta?.let { video ->
        Spacer(Modifier.height(20.dp))
        Box {
            if (video.thumbnail != null) {
                AsyncImage(
                    model = video.thumbnail,
                    contentDescription = null,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(190.dp)
                        .clip(RoundedCornerShape(20.dp)),
                    contentScale = ContentScale.Crop,
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
            Text(
                video.platform.uppercase(),
                color = Pink,
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.align(Alignment.BottomStart).padding(14.dp),
            )
        }
        Spacer(Modifier.height(12.dp))
        Text(video.title, color = Cream, fontSize = 20.sp, fontWeight = FontWeight.Bold)
        Text(listOfNotNull(video.author, video.platform).joinToString("  ·  "), color = Muted, fontSize = 13.sp)
        Spacer(Modifier.height(16.dp))

        val videos = video.options.filter { it.kind == MediaKind.VIDEO }
        val audios = video.options.filter { it.kind == MediaKind.AUDIO }

        if (videos.isNotEmpty()) {
            SectionLabel(Icons.Outlined.Videocam, "Video")
            videos.forEach { option ->
                OptionRow(option, option.id == selected?.id) { onSelect(option) }
            }
        }
        if (audios.isNotEmpty()) {
            Spacer(Modifier.height(12.dp))
            SectionLabel(Icons.Outlined.Audiotrack, "Audio")
            audios.forEach { option ->
                OptionRow(option, option.id == selected?.id) { onSelect(option) }
            }
        }

        Spacer(Modifier.height(14.dp))
        PinkButton(
            label = if (downloading) "Downloading…" else "Download",
            icon = Icons.Outlined.Download,
            enabled = !downloading,
            loading = downloading,
            onClick = onDownload,
        )
        if (downloading) {
            Spacer(Modifier.height(10.dp))
            LinearProgressIndicator(
                progress = { progress },
                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(8.dp)),
                color = Pink,
                trackColor = Surface,
            )
            Text("${(progress * 100).toInt()}%", color = Muted, fontSize = 12.sp, modifier = Modifier.padding(top = 6.dp))
        }
    }
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
    Row(
        Modifier
            .fillMaxWidth()
            .padding(top = 8.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(if (active) PinkSoft else Surface)
            .border(1.dp, if (active) Pink else Line, RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier
                .size(36.dp)
                .clip(CircleShape)
                .background(if (active) Pink else Surface2),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
        }
        Text(
            option.label,
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
    Dialog(onDismissRequest = onClose) {
        Column(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(28.dp))
                .background(Surface)
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
                Text("Downloaded", color = Cream, fontWeight = FontWeight.Bold, fontSize = 20.sp, modifier = Modifier.weight(1f))
                IconButton(onClick = onClose) {
                    Icon(Icons.Outlined.Close, contentDescription = "Close", tint = Muted)
                }
            }
            Spacer(Modifier.height(16.dp))
            ActionTile(Icons.Outlined.PlayArrow, "Play", onView)
            Spacer(Modifier.height(10.dp))
            ActionTile(Icons.Outlined.Share, "Share", onShare)
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
    Text("Download History", color = Cream, fontSize = 28.sp, fontWeight = FontWeight.Black)
    Spacer(Modifier.height(16.dp))
    if (items.isEmpty()) {
        Text("No downloads yet", color = Muted)
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
                AsyncImage(
                    model = item.thumbnail,
                    contentDescription = null,
                    modifier = Modifier.size(64.dp).clip(RoundedCornerShape(12.dp)),
                    contentScale = ContentScale.Crop,
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
                Text("${item.platform}  ·  ${item.quality}", color = Muted, fontSize = 12.sp)
            }
        }
        Row(Modifier.padding(bottom = 14.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SmallIconAction(Icons.Outlined.PlayArrow, "Play") { onView(item) }
            SmallIconAction(Icons.Outlined.Share, "Share") { onShare(item) }
            TextButton(onClick = { onDelete(item) }) {
                Icon(Icons.Outlined.Delete, contentDescription = null, tint = Crimson, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(6.dp))
                Text("Delete", color = Crimson)
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
private fun PlatformChip(label: String, color: Color) {
    Row(
        Modifier
            .clip(RoundedCornerShape(20.dp))
            .background(Surface)
            .border(1.dp, Line, RoundedCornerShape(20.dp))
            .padding(horizontal = 10.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(7.dp).clip(CircleShape).background(color))
        Text(label, color = Cream, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(start = 6.dp))
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
    val items = listOf("Home" to Icons.Outlined.Home, "History" to Icons.Outlined.History)
    Row(
        Modifier
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .clip(RoundedCornerShape(28.dp))
            .background(Color(0xFF161018))
            .padding(6.dp),
    ) {
        items.forEachIndexed { index, (label, icon) ->
            val active = tab == index
            Row(
                Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(22.dp))
                    .background(if (active) Pink else Color.Transparent)
                    .clickable { onChange(index) }
                    .padding(vertical = 10.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(icon, contentDescription = null, tint = if (active) Color.White else Muted, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(6.dp))
                Text(label, color = if (active) Color.White else Muted, fontWeight = FontWeight.Bold, fontSize = 13.sp)
            }
        }
    }
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
