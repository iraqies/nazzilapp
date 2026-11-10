enum PlatformId { youtube, tiktok, instagram, facebook, unknown }

enum MediaKind { video, audio, photo }

class CancelledException implements Exception {
  @override
  String toString() => 'Cancelled';
}

class PausedException implements Exception {
  const PausedException({this.paths = const [], this.completed = 0});
  final List<String> paths;
  final int completed;
  @override
  String toString() => 'Paused';
}

class QualityOption {
  const QualityOption({
    required this.id,
    required this.label,
    required this.ext,
    required this.kind,
    this.height,
    this.directUrl,
    this.audioUrl,
    this.photoUrls = const [],
  });

  final String id;
  final String label;
  final String ext;
  final MediaKind kind;
  final int? height;
  final String? directUrl;

  /// Set when [directUrl] is a video-only stream that has to be joined with
  /// this audio stream (YouTube above 360p).
  final String? audioUrl;
  final List<String> photoUrls;

  bool get isPhotoAlbum => kind == MediaKind.photo && photoUrls.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'ext': ext,
        'kind': kind.name,
        'height': height,
        'directUrl': directUrl,
        'audioUrl': audioUrl,
        'photoUrls': photoUrls,
      };

  factory QualityOption.fromJson(Map<String, dynamic> json) {
    return QualityOption(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      ext: json['ext'] as String? ?? 'mp4',
      kind: MediaKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => MediaKind.video,
      ),
      height: json['height'] as int?,
      directUrl: json['directUrl'] as String?,
      audioUrl: json['audioUrl'] as String?,
      photoUrls: ((json['photoUrls'] as List?) ?? const []).map((e) => e.toString()).toList(),
    );
  }
}

class MediaInfo {
  const MediaInfo({
    required this.id,
    required this.title,
    required this.webpageUrl,
    required this.platform,
    required this.options,
    this.author,
    this.thumbnail,
    this.duration,
    this.photos = const [],
  });

  final String id;
  final String title;
  final String? author;
  final String? thumbnail;
  final int? duration;
  final String webpageUrl;
  final PlatformId platform;
  final List<QualityOption> options;
  final List<String> photos;

  bool get isPhotoAlbum => photos.length > 1 || (photos.isNotEmpty && options.any((o) => o.kind == MediaKind.photo));

  QualityOption? get preferred {
    for (final option in options) {
      if (option.kind == MediaKind.photo) return option;
    }
    for (final option in options) {
      if (option.kind == MediaKind.video) return option;
    }
    return options.isEmpty ? null : options.first;
  }
}

class LibraryItem {
  const LibraryItem({
    required this.id,
    required this.title,
    required this.platform,
    required this.kind,
    required this.quality,
    required this.createdAt,
    required this.sourceUrl,
    required this.videoKey,
    this.author,
    this.thumbnail,
    this.paths = const [],
    this.photoCount = 0,
    this.status = statusDone,
    this.error = '',
    this.duration,
    this.option,
  });

  static const statusQueued = 'queued';
  static const statusDownloading = 'downloading';
  static const statusPaused = 'paused';
  static const statusDone = 'done';
  static const statusFailed = 'failed';
  static const statusCancelled = 'cancelled';

  final String id;
  final String title;
  final String? author;
  final PlatformId platform;
  final MediaKind kind;
  final String quality;
  final DateTime createdAt;
  final String sourceUrl;
  final String videoKey;
  final String? thumbnail;
  final List<String> paths;
  final int photoCount;
  final String status;
  final String error;
  final int? duration;
  final QualityOption? option;

  bool get pending => status == statusQueued || status == statusDownloading;
  bool get paused => status == statusPaused;
  bool get active => pending || paused;
  bool get done => status == statusDone || status.isEmpty;
  bool get isAlbum => kind == MediaKind.photo && photoCount > 1;

  String? get primaryPath => paths.isEmpty ? null : paths.first;

  MediaInfo get media => MediaInfo(
        id: videoKey.contains(':') ? videoKey.split(':').last : id,
        title: title,
        author: author,
        thumbnail: thumbnail,
        duration: duration,
        webpageUrl: sourceUrl,
        platform: platform,
        options: [?option],
        photos: option?.photoUrls ?? const [],
      );

  LibraryItem copyWith({
    String? id,
    List<String>? paths,
    int? photoCount,
    String? status,
    String? error,
    String? thumbnail,
    QualityOption? option,
  }) {
    return LibraryItem(
      id: id ?? this.id,
      title: title,
      author: author,
      platform: platform,
      kind: kind,
      quality: quality,
      createdAt: createdAt,
      sourceUrl: sourceUrl,
      videoKey: videoKey,
      thumbnail: thumbnail ?? this.thumbnail,
      paths: paths ?? this.paths,
      photoCount: photoCount ?? this.photoCount,
      status: status ?? this.status,
      error: error ?? this.error,
      duration: duration,
      option: option ?? this.option,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'platform': platform.name,
        'kind': kind.name,
        'quality': quality,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'sourceUrl': sourceUrl,
        'videoKey': videoKey,
        'thumbnail': thumbnail,
        'paths': paths,
        'photoCount': photoCount,
        'status': status,
        'error': error,
        'duration': duration,
        'option': option?.toJson(),
      };

  factory LibraryItem.fromJson(Map<String, dynamic> json) {
    return LibraryItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      author: (json['author'] as String?)?.trim().isEmpty == true ? null : json['author'] as String?,
      platform: PlatformId.values.firstWhere(
        (p) => p.name == json['platform'],
        orElse: () => PlatformId.unknown,
      ),
      kind: MediaKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => MediaKind.video,
      ),
      quality: json['quality'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int? ?? 0),
      sourceUrl: json['sourceUrl'] as String? ?? '',
      videoKey: json['videoKey'] as String? ?? '',
      thumbnail: json['thumbnail'] as String?,
      paths: ((json['paths'] as List?) ?? const []).map((e) => e.toString()).toList(),
      photoCount: json['photoCount'] as int? ?? 0,
      status: json['status'] as String? ?? statusDone,
      error: json['error'] as String? ?? '',
      duration: json['duration'] as int?,
      option: json['option'] is Map
          ? QualityOption.fromJson(Map<String, dynamic>.from(json['option'] as Map))
          : null,
    );
  }
}

class AppSettings {
  const AppSettings({
    this.language = 'system',
    this.theme = 'system',
    this.palette = 'rose',
  });

  final String language;
  final String theme;
  final String palette;

  AppSettings copyWith({String? language, String? theme, String? palette}) {
    return AppSettings(
      language: language ?? this.language,
      theme: theme ?? this.theme,
      palette: palette ?? this.palette,
    );
  }
}
