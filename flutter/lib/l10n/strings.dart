import '../data/platforms.dart';
import '../models/media.dart';

class S {
  const S(this.lang);
  final String lang;

  bool get isAr => lang == 'ar';
  bool get rtl => isAr;
  bool get _pc => Platforms.desktop;

  // The Arabic name is written as the logo writes it, with its shadda.
  String get appName => _t('Nazzil', 'نزّل');
  String get framePrompt => _t('Paste a link', 'الصق رابطًا');
  String get frameHint => _pc
      ? _t('or drop it on this window', 'أو اسحبه إلى هذه النافذة')
      : _t('or share a post to Nazzil from any app', 'أو شارك منشورًا مع نزّل من أي تطبيق');
  String get recent => _t('Recent', 'آخر التنزيلات');
  String get linkLabel => _t('Link', 'الرابط');
  String get pasteHint =>
      _t('Paste or share a YouTube, TikTok, Instagram, Facebook, Reddit, X or Pinterest link', 'الصق رابطًا من يوتيوب أو تيك توك أو إنستغرام أو فيسبوك أو ريديت أو X أو بنترست');
  String get paste => _t('Paste', 'الصق');
  String get clear => _t('Clear', 'امسح');
  String get fetch => _t('Fetch', 'اجلب');
  String get fetching => _t('Reading the link…', 'جارٍ قراءة الرابط…');
  String get cancel => _t('Cancel', 'ألغِ');
  String get cancelled => _t('Cancelled', 'أُلغي');
  String get pause => _t('Pause', 'أوقف مؤقتًا');
  String get paused => _t('Paused', 'متوقف مؤقتًا');
  String get resume => _t('Resume', 'استأنف');
  String get retry => _t('Try again', 'أعد المحاولة');
  String get download => _t('Download', 'نزّل');
  String get savePhotos => _t('Save photos', 'احفظ الصور');
  String get savePhoto => _t('Save this photo', 'احفظ هذه الصورة');
  String get saveOnePhoto => _t('Save photo', 'احفظ الصورة');
  String get saveAll => _t('Save all', 'احفظ الكل');
  String get saveThis => _t('Save this one', 'احفظ هذا فقط');
  String get photo => _t('Photo', 'صورة');
  String get photos => _t('Photos', 'صور');
  String get album => _t('Album', 'ألبوم');
  String get video => _t('Video', 'فيديو');
  String get audio => _t('Audio', 'صوت');
  String get hd => _t('HD', 'جودة عالية');
  String get sd => _t('SD', 'جودة عادية');
  String get home => _t('Home', 'الرئيسية');
  String get library => _t('Library', 'التنزيلات');
  String get settings => _t('Settings', 'الإعدادات');
  String get back => _t('Back', 'رجوع');
  String get downloading => _t('Downloading…', 'جارٍ التنزيل…');
  String get converting => _t('Converting…', 'جارٍ التحويل…');
  String get downloaded => _t('Saved', 'تم التنزيل');
  String get play => _t('Play', 'شغّل');
  String get share => _t('Share', 'شارك');
  String get delete => _t('Delete', 'احذف');
  String get close => _t('Close', 'أغلق');
  String get original => _t('Original', 'الأصل');
  String get language => _t('Language', 'اللغة');
  String get system => _t('System', 'حسب الجهاز');
  String get english => 'English';
  String get arabic => 'العربية';
  String get theme => _t('Theme', 'المظهر');
  String get colour => _t('Colour', 'اللون');
  String paletteName(String id) => switch (id) {
        'ocean' => _t('Ocean', 'بحري'),
        'emerald' => _t('Emerald', 'زمردي'),
        'sunset' => _t('Sunset', 'غروب'),
        'grape' => _t('Grape', 'عنبي'),
        _ => _t('Rose', 'وردي'),
      };
  String get themeLight => _t('Light', 'فاتح');
  String get themeDark => _t('Dark', 'داكن');
  String get about => _t('About', 'عن التطبيق');
  String get aboutBody => _t(
        _pc
            ? 'Nazzil saves videos, photos and audio from YouTube, TikTok, Instagram, Facebook, Reddit, X and Pinterest into Downloads/Nazzil. Paste or drop a link, pick a quality, download.'
            : 'Nazzil saves videos, photos and audio from YouTube, TikTok, Instagram, Facebook, Reddit, X and Pinterest into your gallery. Paste a link, pick a quality, download.',
        _pc
            ? 'نزّل يحفظ الفيديو والصور والصوت من يوتيوب وتيك توك وإنستغرام وفيسبوك وريديت و X وبنترست في مجلد Nazzil داخل مجلد التنزيلات. الصق الرابط أو اسحبه، ثم اختر الجودة ونزّل.'
            : 'نزّل يحفظ الفيديو والصور والصوت من يوتيوب وتيك توك وإنستغرام وفيسبوك وريديت و X وبنترست في المعرض. الصق الرابط، ثم اختر الجودة ونزّل.',
      );
  String get credits => _t('Credits', 'حقوق');
  String get version => _t('Version', 'الإصدار');
  String get emptyLibrary => _t('Nothing saved yet', 'لم تنزّل شيئًا بعد');
  String get emptyLibraryHint => _t('What you download shows up here.', 'ما تنزّله يظهر هنا.');
  String get addLink => _t('Add a link', 'أضف رابطًا');
  String get emptyFilter => _t('Nothing here for this filter', 'لا شيء يطابق هذه التصفية');
  String get showAll => _t('Show all', 'اعرض الكل');
  String get downloadFailed => _t('Download failed', 'فشل التنزيل');
  String get alreadyHave => _t('You already have this', 'سبق أن نزّلت هذا');
  String get alreadyHaveBody =>
      _t(_pc ? 'This file is still on this computer.' : 'This file is still on your phone.', 'الملف ما زال على جهازك.');
  // Nazzil tracks only its own copy, so these say nothing about the gallery or Downloads.
  String get missingFile => _t('File was removed', 'حُذف الملف');
  String get fileGone => _t("Nazzil's copy of this file is gone.", 'نسخة نزّل من هذا الملف لم تعد موجودة.');
  String get downloadAgain => _t('Download again', 'نزّله مرة أخرى');
  String get cantPlay => _t('This video will not play here.', 'لا يمكن تشغيل هذا الفيديو هنا.');
  String get cantOpen => _pc
      ? _t(
          'Nothing on this computer could open it. It was saved to Downloads/Nazzil.',
          'لا يوجد على جهازك برنامج يفتحه. حُفظ في مجلد Nazzil داخل مجلد التنزيلات.',
        )
      : _t('No app on this phone could open it.', 'لا يوجد على هاتفك تطبيق يفتحه.');
  String get photoFailed => _t('Could not load this photo.', 'تعذّر تحميل هذه الصورة.');
  String get deleteTitle => _t('Delete this download?', 'هل تريد حذف هذا التنزيل؟');
  // Delete removes the copy Nazzil keeps for itself and nothing else.
  String get deleteBody => _pc
      ? _t(
          'Nazzil deletes its own copy. Downloads/Nazzil is left as it is.',
          'نزّل يحذف نسخته فقط. مجلد Nazzil داخل مجلد التنزيلات يبقى كما هو.',
        )
      : _t(
          'Nazzil deletes its own copy. Your gallery and files are left as they are.',
          'نزّل يحذف نسخته فقط. المعرض وملفاتك تبقى كما هي.',
        );
  String get queued => _t('Waiting', 'قيد الانتظار');
  String get clipOffer => _t('A supported link is on your clipboard', 'في الحافظة رابط مدعوم');
  String get fetchThis => _t('Fetch this', 'اجلبه');
  String get openGallery => _pc ? _t('Open file', 'افتح الملف') : _t('Open in gallery', 'افتح في المعرض');
  String get filterAll => _t('All', 'الكل');
  String get filterAllApps => _t('All apps', 'كل التطبيقات');
  String get filterPhotos => _t('Photos', 'صور');
  String get filterVideos => _t('Videos', 'فيديو');
  String get filterAudio => _t('Audio', 'صوت');
  String get ofWord => _t('of', 'من');
  String get previous => _t('Previous', 'السابق');
  String get next => _t('Next', 'التالي');
  String get updateAvailable => _t('A new version is out', 'يتوفر إصدار جديد');
  String get updateNow => _t('Update', 'حدّث');
  String get albumSaved => _t('Photos saved', 'تم حفظ الصور');
  String get photoSaved => _t('Photo saved', 'تم حفظ الصورة');
  String get view => _t('View', 'اعرض');
  /// What the download notification says. Android draws it outside Flutter, so the app hands it these.
  Map<String, String> get hostWords => {
        'channel': _t('Downloads', 'التنزيلات'),
        'downloading': downloading,
        'pause': pause,
        'cancel': cancel,
        'paused': paused,
        'resume': resume,
        'saved': downloaded,
        'failed': downloadFailed,
        'open': _t('Open', 'افتح'),
      };

  String get youtube => _t('YouTube', 'يوتيوب');
  String get tiktok => _t('TikTok', 'تيك توك');
  String get instagram => _t('Instagram', 'إنستغرام');
  String get facebook => _t('Facebook', 'فيسبوك');
  String get reddit => _t('Reddit', 'ريديت');
  String get x => 'X';
  String get pinterest => _t('Pinterest', 'بنترست');

  String platformName(PlatformId platform) => switch (platform) {
        PlatformId.youtube => youtube,
        PlatformId.tiktok => tiktok,
        PlatformId.instagram => instagram,
        PlatformId.facebook => facebook,
        PlatformId.reddit => reddit,
        PlatformId.x => x,
        PlatformId.pinterest => pinterest,
        PlatformId.unknown => '',
      };

  /// What went wrong, for a spot that has its own retry button.
  String failure(Failure kind) => switch (kind) {
        Failure.none => '',
        Failure.pasteFirst => _t('Paste a link first.', 'الصق رابطًا أولًا.'),
        Failure.noLink => _t('No link on your clipboard.', 'لا يوجد رابط في الحافظة.'),
        Failure.unsupported => _t('This link is not from a supported app yet.', 'هذا الرابط ليس من تطبيق مدعوم بعد.'),
        Failure.network => _t('Connection dropped.', 'انقطع الاتصال.'),
        Failure.blocked => _t('This post blocked the download.', 'هذا المنشور يمنع التنزيل.'),
        Failure.permission => _t('Gallery permission is needed to save.', 'نحتاج إلى إذن المعرض للحفظ.'),
        // "May be", because a site that refuses the app answers the same way.
        Failure.unavailable => _t('This post may be private or deleted.', 'قد يكون المنشور خاصًا أو محذوفًا.'),
        Failure.noMedia => _t('This post has no video or photos to save.', 'هذا المنشور لا يحتوي على فيديو أو صور للحفظ.'),
        Failure.badLink => _t('This link does not point to a post.', 'هذا الرابط لا يشير إلى منشور.'),
        Failure.processing => _t('This video is still processing.', 'هذا الفيديو ما زال قيد المعالجة.'),
        Failure.convert => _t('Downloaded, but converting it failed.', 'تم التنزيل، لكن فشل التحويل.'),
        Failure.load => _t('Could not load this.', 'تعذّر التحميل.'),
        Failure.download => _t('Could not download this.', 'تعذّر التنزيل.'),
      };

  String advice(Failure kind) => switch (kind) {
        Failure.network || Failure.convert || Failure.load || Failure.download => _t('Try again.', 'حاول مرة أخرى.'),
        Failure.blocked => _t('Try again later.', 'حاول لاحقًا.'),
        Failure.noLink => _t("Copy a post's link first.", 'انسخ رابط المنشور أولًا.'),
        Failure.processing => _t('Try again in a bit.', 'حاول بعد قليل.'),
        _ => '',
      };

  /// What went wrong and what to do, for a spot with no button of its own.
  String failureLine(Failure kind) => [failure(kind), advice(kind)].where((part) => part.isNotEmpty).join(' ');

  String photosN(int n) => isAr
      ? _arCount(n, none: 'لا صور', one: 'صورة واحدة', two: 'صورتان', few: 'صور', many: 'صورة', other: 'صورة')
      : (n == 1 ? '1 photo' : '$n photos');

  String itemsN(int n) => isAr
      ? _arCount(n, none: 'لا عناصر', one: 'عنصر واحد', two: 'عنصران', few: 'عناصر', many: 'عنصرًا', other: 'عنصر')
      : (n == 1 ? '1 item' : '$n items');

  /// "8%", sign last, wherever it stands. After Arabic words the sign would jump to the other side
  /// of the number, so the Arabic one starts with a left-to-right mark that keeps the two together.
  String percent(int n) => isAr ? '\u200E$n%' : '$n%';

  String waitingN(int n) => isAr ? '$n قيد الانتظار' : (n == 1 ? '1 waiting' : '$n waiting');

  /// An Arabic count. One and two have words of their own, three to ten take
  /// the plural, eleven to ninety-nine the singular with its ending, and a
  /// round hundred the bare singular. Past a hundred the last two digits decide.
  String _arCount(
    int n, {
    required String none,
    required String one,
    required String two,
    required String few,
    required String many,
    required String other,
  }) {
    final tail = n % 100;
    return switch (n) {
      0 => none,
      1 => one,
      2 => two,
      _ when tail >= 3 && tail <= 10 => '$n $few',
      _ when tail >= 11 => '$n $many',
      _ => '$n $other',
    };
  }

  /// 75 seconds reads 1:15; an hour and more reads 1:02:03.
  String clock(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final sec = (seconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$sec' : '$m:$sec';
  }

  String _t(String en, String ar) => isAr ? ar : en;
}
