import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/downloader.dart';
import '../data/extractor.dart';
import '../data/gallery.dart';
import '../data/host.dart';
import '../data/inbound_share.dart';
import '../data/library_store.dart';
import '../data/link_parser.dart';
import '../data/net.dart';
import '../data/platforms.dart';
import '../data/settings_store.dart';
import '../data/update_checker.dart';
import '../l10n/strings.dart';
import '../models/media.dart';

class NazzilController extends ChangeNotifier {
  NazzilController() {
    _init();
  }

  final extractor = MediaExtractor();
  late final downloadNet = NetClient();
  late final downloader = MediaDownloader(
    extractor: extractor,
    gallery: GalleryService(),
    net: downloadNet,
  );
  final libraryStore = LibraryStore();
  final settingsStore = SettingsStore();
  final updates = UpdateChecker();

  AppSettings settings = const AppSettings();
  List<LibraryItem> library = [];
  String url = '';
  MediaInfo? media;
  QualityOption? selected;
  int photoIndex = 0;
  bool loading = false;
  bool downloading = false;

  /// True once the pieces are in and the file is being put together.
  bool converting = false;
  double progress = 0;
  Failure failure = Failure.none;
  LibraryItem? doneItem;
  LibraryItem? duplicate;
  RemoteVersion? remote;
  String localVersion = '1.3';
  int tab = 0;
  String? clipOffer;
  String libraryKind = 'all';
  String libraryPlatform = 'all';
  String? activeJobId;
  int _fetchGen = 0;
  String? _lastIngest;
  String? _lastClip;
  bool _pumping = false;
  StreamSubscription<String>? _shareSub;

  S get s {
    final lang = settings.language == 'ar'
        ? 'ar'
        : settings.language == 'en'
            ? 'en'
            : PlatformDispatcher.instance.locale.languageCode;
    return S(lang.startsWith('ar') ? 'ar' : 'en');
  }

  ThemeMode get themeMode => switch (settings.theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Locale get locale => Locale(s.lang);

  /// Worded at read time, so it follows a language switch.
  String get error => s.failureLine(failure);

  int get queuedCount => library.where((e) => e.status == LibraryItem.statusQueued).length;

  List<LibraryItem> get visibleLibrary {
    return library.where((item) {
      final kindOk = switch (libraryKind) {
        'photos' => item.kind == MediaKind.photo,
        'videos' => item.kind == MediaKind.video,
        'audio' => item.kind == MediaKind.audio,
        _ => true,
      };
      final platformOk = libraryPlatform == 'all' || item.platform.name == libraryPlatform;
      return kindOk && platformOk;
    }).toList();
  }

  /// The apps that have something in the library, in a fixed order.
  List<PlatformId> get libraryPlatforms => [
        for (final platform in PlatformId.values)
          if (platform != PlatformId.unknown && library.any((item) => item.platform == platform)) platform,
      ];

  LibraryItem? jobForCurrent({int? onlyPhoto}) {
    final current = media;
    final option = selected;
    if (current == null || option == null) return null;
    final key = LinkParser.identityKey(current.webpageUrl, current.id);
    final quality = onlyPhoto == null ? option.label : 'Photo ${onlyPhoto + 1}';
    for (final item in library) {
      if (item.videoKey == key && item.quality == quality && item.active) return item;
    }
    return null;
  }

  Future<void> _init() async {
    settings = await settingsStore.load();
    library = libraryStore.recoverInterrupted(await libraryStore.all());
    await libraryStore.save(library);
    try {
      await downloader.sweep(library);
    } catch (_) {}
    localVersion = await updates.current();
    DownloadHost.bind(
      onOpened: (openLibrary) {
        if (openLibrary) goTab(1);
      },
      onPause: pauseCurrent,
      onResume: resumeCurrent,
      onCancel: cancelCurrent,
    );
    notifyListeners();
    _shareSub = InboundShare.stream().listen(ingest);
    final initial = await InboundShare.initial();
    if (initial != null) await ingest(initial);
    unawaited(offerClipboard());
    unawaited(_pump());
    // The site only publishes APKs; other platforms have no update to offer.
    if (Platform.isAndroid) {
      try {
        remote = await updates.fetch();
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> ingest(String incoming) async {
    final link = LinkParser.extract(incoming);
    final pasted = link.isNotEmpty ? link : incoming.trim();
    if (pasted.isEmpty) return;
    tab = 0;
    url = pasted;
    if (link.isNotEmpty) {
      clipOffer = null;
      _lastClip = link;
    }
    notifyListeners();
    if (link.isEmpty || !LinkParser.isSupported(link)) return;
    if (link == _lastIngest && (loading || media?.webpageUrl == link)) return;
    _lastIngest = link;
    await fetch(link);
  }

  void setUrl(String value) {
    url = value;
    failure = Failure.none;
    notifyListeners();
  }

  void clear() {
    url = '';
    media = null;
    selected = null;
    failure = Failure.none;
    doneItem = null;
    clipOffer = null;
    notifyListeners();
  }

  Future<void> paste(String clip) async {
    final link = LinkParser.extract(clip);
    if (link.isEmpty) return;
    url = link;
    clipOffer = null;
    _lastClip = link;
    notifyListeners();
    if (LinkParser.isSupported(link)) await fetch(link);
  }

  Future<void> offerClipboard() async {
    try {
      final data = await Clipboard.getData('text/plain');
      final link = LinkParser.extract(data?.text ?? '');
      if (link.isEmpty || !LinkParser.isSupported(link)) return;
      if (link == url || link == _lastIngest || link == _lastClip) return;
      if (media?.webpageUrl == link) return;
      clipOffer = link;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> acceptClipOffer() async {
    final link = clipOffer;
    clipOffer = null;
    if (link == null || link.isEmpty) return;
    _lastClip = link;
    notifyListeners();
    await fetch(link);
  }

  void dismissClipOffer() {
    if (clipOffer != null) _lastClip = clipOffer;
    clipOffer = null;
    notifyListeners();
  }

  Future<void> fetch([String? value]) async {
    final link = LinkParser.extract(value ?? url);
    if (link.isEmpty) {
      failure = Failure.pasteFirst;
      notifyListeners();
      return;
    }
    if (!LinkParser.isSupported(link)) {
      failure = Failure.unsupported;
      notifyListeners();
      return;
    }
    extractor.net.cancel();
    url = link;
    failure = Failure.none;
    media = null;
    selected = null;
    loading = true;
    tab = 0;
    final gen = ++_fetchGen;
    notifyListeners();
    HapticFeedback.selectionClick();
    try {
      final result = await extractor.fetch(link);
      if (gen != _fetchGen) return;
      media = result;
      selected = result.preferred;
      photoIndex = 0;
    } on CancelledException {
      if (gen != _fetchGen) return;
    } catch (e) {
      if (gen != _fetchGen) return;
      failure = failureOf(e);
    } finally {
      if (gen == _fetchGen) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void cancelFetch() {
    _fetchGen += 1;
    extractor.net.cancel();
    loading = false;
    notifyListeners();
  }

  void select(QualityOption option) {
    selected = option;
    notifyListeners();
  }

  void setPhotoIndex(int index) {
    photoIndex = index;
    notifyListeners();
  }

  void setLibraryKind(String value) {
    libraryKind = value;
    notifyListeners();
  }

  void setLibraryPlatform(String value) {
    libraryPlatform = value;
    notifyListeners();
  }

  void clearLibraryFilters() {
    libraryKind = 'all';
    libraryPlatform = 'all';
    notifyListeners();
  }

  Future<void> download({int? onlyPhoto}) async {
    final current = media;
    final option = selected;
    if (current == null || option == null) return;
    final key = LinkParser.identityKey(current.webpageUrl, current.id);
    final quality = onlyPhoto == null ? option.label : 'Photo ${onlyPhoto + 1}';
    final existing = libraryStore.findKept(
      videoKey: key,
      quality: quality,
      items: library,
    );
    if (existing != null) {
      if (existing.done) {
        duplicate = existing;
        notifyListeners();
        return;
      }
      if (existing.paused) {
        await resumeJob(existing);
        return;
      }
      if (existing.pending) {
        notifyListeners();
        return;
      }
    }
    final toSave = onlyPhoto == null
        ? option
        : QualityOption(
            id: 'photo-$onlyPhoto',
            label: 'Photo',
            ext: 'jpg',
            kind: MediaKind.photo,
            photoUrls: [
              option.kind == MediaKind.photo && onlyPhoto < option.photoUrls.length
                  ? option.photoUrls[onlyPhoto]
                  : current.photos[onlyPhoto],
            ],
          );
    final item = LibraryItem(
      id: 'q-$key-$quality',
      title: current.title,
      author: current.author,
      platform: current.platform,
      kind: toSave.kind,
      quality: quality,
      createdAt: DateTime.now(),
      sourceUrl: current.webpageUrl,
      videoKey: key,
      thumbnail: current.thumbnail,
      paths: const [],
      photoCount: toSave.kind == MediaKind.photo ? toSave.photoUrls.length : 0,
      status: LibraryItem.statusQueued,
      duration: current.duration,
      option: toSave,
    );
    library = [item, ...library.where((e) => e.id != item.id)];
    await libraryStore.save(library);
    notifyListeners();
    unawaited(_pump());
  }

  Future<void> pauseJob(LibraryItem item) async {
    if (item.id == activeJobId) {
      // Nothing is on the wire while the file is being made, so there is nothing to pause.
      if (!converting) downloadNet.pause();
      return;
    }
    if (item.status == LibraryItem.statusQueued) {
      await _patch(item.id, item.copyWith(status: LibraryItem.statusPaused));
    }
  }

  Future<void> pauseCurrent() async {
    final active = _byId(activeJobId ?? '');
    if (active != null) {
      await pauseJob(active);
      return;
    }
    final job = jobForCurrent();
    if (job != null) await pauseJob(job);
  }

  Future<void> resumeJob(LibraryItem item) async {
    if (!item.paused && item.status != LibraryItem.statusFailed) return;
    final next = item.copyWith(status: LibraryItem.statusQueued, error: '');
    library = [...library.where((e) => e.id != item.id), next];
    await libraryStore.save(library);
    notifyListeners();
    unawaited(_pump());
  }

  /// Puts a failed, cancelled or since-removed download back in the queue.
  Future<void> retryJob(LibraryItem item) async {
    if (item.active) return;
    final option = item.option;
    if (option == null) {
      await ingest(item.sourceUrl);
      return;
    }
    // Only a failed job can have a usable partial file to continue from.
    final fresh = item.status != LibraryItem.statusFailed;
    await _patch(
      item.id,
      item.copyWith(
        status: LibraryItem.statusQueued,
        error: '',
        paths: fresh ? const [] : null,
        photoCount: fresh ? (option.kind == MediaKind.photo ? option.photoUrls.length : 0) : null,
      ),
    );
    unawaited(_pump());
  }

  Future<void> resumeCurrent() async {
    final job = jobForCurrent() ??
        library.cast<LibraryItem?>().firstWhere(
              (e) => e?.paused == true,
              orElse: () => null,
            );
    if (job != null) await resumeJob(job);
  }

  Future<void> cancelJob(LibraryItem item) async {
    if (item.id == activeJobId) {
      downloadNet.cancel();
    }
    for (final path in item.paths) {
      final file = File(path);
      if (file.existsSync()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
    library = [
      for (final entry in library)
        entry.id == item.id
            ? entry.copyWith(status: LibraryItem.statusCancelled, error: '', paths: const [])
            : entry,
    ];
    await libraryStore.save(library);
    notifyListeners();
  }

  Future<void> cancelCurrent() async {
    final active = _byId(activeJobId ?? '');
    if (active != null) {
      await cancelJob(active);
      return;
    }
    final job = jobForCurrent();
    if (job != null) await cancelJob(job);
  }

  Future<void> _pump() async {
    if (_pumping) return;
    _pumping = true;
    try {
      if (Platforms.mobile) await Permission.notification.request();
      while (true) {
        final job = libraryStore.nextQueued(library);
        if (job == null) break;
        await _runJob(job);
      }
    } finally {
      _pumping = false;
      activeJobId = null;
      downloading = false;
      converting = false;
      await DownloadHost.stop();
      notifyListeners();
    }
  }

  Future<void> _runJob(LibraryItem queued) async {
    var job = queued;
    if (job.option == null) {
      await _patch(job.id, job.copyWith(status: LibraryItem.statusFailed, error: Failure.download.name));
      return;
    }
    activeJobId = job.id;
    downloading = true;
    converting = false;
    progress = 0.02;
    failure = Failure.none;
    await _patch(job.id, job.copyWith(status: LibraryItem.statusDownloading));
    await DownloadHost.start(title: job.title, percent: 2);
    var lastPercent = -1;
    var lastSent = DateTime.fromMillisecondsSinceEpoch(0);
    Future<DownloadResult> attempt() => downloader.download(
          media: job.media,
          option: job.option!,
          resumePaths: job.paths,
          completedPhotos: job.photoCount,
          onConvert: () {
            converting = true;
            notifyListeners();
          },
          onProgress: (value) {
            progress = value;
            final percent = (value * 100).round().clamp(1, 99);
            final now = DateTime.now();
            // Android drops notification updates beyond about 5 a second.
            if (percent != lastPercent && now.difference(lastSent) >= const Duration(seconds: 1)) {
              lastPercent = percent;
              lastSent = now;
              unawaited(DownloadHost.progress(job.title, percent));
            }
            notifyListeners();
          },
        );
    try {
      if (job.paths.isNotEmpty || DateTime.now().difference(job.createdAt) > linkLifetime) {
        job = await _withFreshLinks(job);
      }
      DownloadResult result;
      try {
        result = await attempt();
      } on HttpException catch (e) {
        if (!_looksExpired(e)) rethrow;
        job = await _withFreshLinks(job);
        result = await attempt();
      }
      final current = _byId(job.id);
      if (current == null ||
          current.status == LibraryItem.statusCancelled ||
          current.status == LibraryItem.statusPaused) {
        return;
      }
      final done = job.copyWith(
        status: LibraryItem.statusDone,
        error: '',
        paths: result.files.map((f) => f.path).toList(),
        photoCount: result.photoCount,
        thumbnail: job.thumbnail ?? (result.files.isNotEmpty ? result.files.first.path : null),
      );
      await _patch(job.id, done);
      HapticFeedback.mediumImpact();
      if (libraryStore.nextQueued(library) == null) {
        doneItem = done;
        await DownloadHost.done(done.title, path: done.primaryPath);
      }
    } on PausedException catch (paused) {
      final current = _byId(job.id);
      if (current == null || current.status == LibraryItem.statusCancelled) return;
      progress = progress.clamp(0.0, 0.99);
      await _patch(
        job.id,
        job.copyWith(
          status: LibraryItem.statusPaused,
          error: '',
          paths: paused.paths.isNotEmpty ? paused.paths : job.paths,
          photoCount: paused.completed,
        ),
      );
      if (libraryStore.nextQueued(library) == null) {
        await DownloadHost.paused(job.title, (progress * 100).round());
      }
    } on CancelledException {
      final current = _byId(job.id);
      if (current != null && current.status != LibraryItem.statusCancelled) {
        await _patch(job.id, job.copyWith(status: LibraryItem.statusCancelled, error: '', paths: const []));
      }
    } catch (e) {
      final current = _byId(job.id);
      if (current == null ||
          current.status == LibraryItem.statusCancelled ||
          current.status == LibraryItem.statusPaused) {
        return;
      }
      final kind = failureOf(e, downloading: true);
      failure = kind;
      await _patch(job.id, job.copyWith(status: LibraryItem.statusFailed, error: kind.name));
      if (libraryStore.nextQueued(library) == null) {
        await DownloadHost.failed(kind == Failure.none ? s.downloadFailed : s.failureLine(kind));
      }
    }
  }

  /// Signed CDN links (YouTube, TikTok, Instagram) stop working after a few
  /// hours; well before that is a safe point to ask for new ones.
  static const linkLifetime = Duration(minutes: 20);

  static bool _looksExpired(HttpException e) {
    final text = e.message.toLowerCase();
    return text.contains('blocked') || text.contains('gone') || text.contains('403') || text.contains('410');
  }

  Future<LibraryItem> _withFreshLinks(LibraryItem job) async {
    final old = job.option!;
    final MediaInfo media;
    try {
      media = await extractor.fetch(job.sourceUrl);
    } catch (_) {
      return job;
    }
    final fresh = media.options.where((o) => o.id == old.id).firstOrNull ??
        media.options.where((o) => o.label == old.label && o.kind == old.kind).firstOrNull;
    if (fresh == null) return job;
    // A different stream would not continue the bytes already on disk.
    final keepPartial = fresh.id == old.id;
    if (!keepPartial) {
      for (final path in job.paths) {
        try {
          File(path).deleteSync();
        } catch (_) {}
      }
    }
    final updated = job.copyWith(
      option: fresh,
      paths: keepPartial ? job.paths : const [],
      photoCount: keepPartial ? job.photoCount : 0,
    );
    await _patch(job.id, updated);
    return updated;
  }

  LibraryItem? _byId(String id) {
    for (final item in library) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> _patch(String id, LibraryItem next) async {
    library = [for (final item in library) item.id == id ? next : item];
    await libraryStore.save(library);
    notifyListeners();
  }

  Future<void> remove(LibraryItem item) async {
    if (item.active) await cancelJob(item);
    for (final path in item.paths) {
      final file = File(path);
      if (file.existsSync()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
    library = library.where((e) => e.id != item.id).toList();
    await libraryStore.save(library);
    notifyListeners();
  }

  Future<void> shareItem(LibraryItem item) async {
    final files = item.paths.where((p) => File(p).existsSync()).map(XFile.new).toList();
    if (files.isEmpty) return;
    try {
      await SharePlus.instance.share(ShareParams(files: files, text: item.title));
    } catch (_) {
      // Share is offered only where the system has a share sheet, so a failure here is rare.
    }
  }

  Future<void> openOriginal(String link) async {
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// False when the file is gone or nothing on the device could open it.
  Future<bool> openInGallery(LibraryItem item) async {
    final path = item.paths.where((p) => File(p).existsSync()).firstOrNull;
    if (path == null) return false;
    return DownloadHost.openFile(path);
  }

  Future<void> setLanguage(String language) async {
    settings = settings.copyWith(language: language);
    await settingsStore.save(settings);
    notifyListeners();
  }

  Future<void> setPalette(String id) async {
    settings = settings.copyWith(palette: id);
    await settingsStore.save(settings);
    notifyListeners();
  }

  Future<void> setTheme(String theme) async {
    settings = settings.copyWith(theme: theme);
    await settingsStore.save(settings);
    notifyListeners();
  }

  void goTab(int value) {
    if (tab == value) return;
    tab = value;
    HapticFeedback.selectionClick();
    notifyListeners();
  }

  void dismissSheets() {
    doneItem = null;
    duplicate = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    extractor.net.close();
    downloadNet.close();
    super.dispose();
  }
}
