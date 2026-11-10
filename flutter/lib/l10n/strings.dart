import '../data/platforms.dart';
import '../models/media.dart';

class S {
  const S(this.lang);
  final String lang;

  bool get isAr => lang == 'ar';
  bool get rtl => isAr;
  bool get _pc => Platforms.desktop;

  String get appName => _t('Nazzil', 'نزل');
  String get tagline => _t('Download the video. Keep it.', 'نزّل الفيديو. خليه عندك.');
  String get photoTagline =>
      _pc
          ? _t('Videos, TikTok photos, Instagram carousels. Straight into Downloads.', 'فيديو وصور تيك توك وألبومات إنستغرام. ينزلون بالتنزيلات.')
          : _t('Videos, TikTok photos, Instagram carousels. Straight into your gallery.', 'فيديو وصور تيك توك وألبومات إنستغرام. ينزلون بالمعرض.');
  String get linkLabel => _t('Link', 'الرابط');
  String get pasteHint =>
      _t('Paste or share a YouTube, TikTok, Instagram, Facebook, Reddit, X or Pinterest link', 'الصق رابط يوتيوب أو تيك توك أو إنستغرام أو فيسبوك أو ريديت أو X أو بنترست');
  String get paste => _t('Paste', 'لصّق');
  String get clear => _t('Clear', 'امسح');
  String get fetch => _t('Fetch', 'جيب');
  String get fetching => _t('Reading the link…', 'لحظات…');
  String get cancel => _t('Cancel', 'ألغِ');
  String get cancelled => _t('Cancelled', 'أُلغي');
  String get pause => _t('Pause', 'وقّف');
  String get paused => _t('Paused', 'متوقف');
  String get resume => _t('Resume', 'كمّل');
  String get retry => _t('Try again', 'حاول مرة ثانية');
  String get download => _t('Download', 'نزّل');
  String get savePhotos => _t('Save photos', 'حفظ الصور');
  String get savePhoto => _t('Save this photo', 'حفظ هذي الصورة');
  String get saveAll => _t('Save all', 'حفظ الكل');
  String get saveThis => _t('Save this one', 'حفظ هذا');
  String get photos => _t('Photos', 'صور');
  String get album => _t('Album', 'ألبوم');
  String get video => _t('Video', 'فيديو');
  String get audio => _t('Audio', 'صوت');
  String get hd => _t('HD', 'جودة عالية');
  String get sd => _t('SD', 'جودة عادية');
  String get home => _t('Home', 'الرئيسية');
  String get library => _t('Library', 'التحميلات');
  String get settings => _t('Settings', 'الإعدادات');
  String get back => _t('Back', 'رجوع');
  String get ready => _t('Ready', 'جاهز');
  String get downloading => _t('Downloading…', 'قاعد ينزّل…');
  String get converting => _t('Converting…', 'قاعد يحوّل…');
  String get downloaded => _t('Saved', 'تم التنزيل');
  String get play => _t('Play', 'شغّل');
  String get share => _t('Share', 'شارك');
  String get delete => _t('Delete', 'احذف');
  String get close => _t('Close', 'سكّر');
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
            ? 'نزل يحفظ الفيديو والصور والصوت من يوتيوب وتيك توك وإنستغرام وفيسبوك وريديت و X وبنترست بمجلد التنزيلات/Nazzil. الصق أو اسحب الرابط، اختار الجودة، ونزّل.'
            : 'نزل يحفظ الفيديو والصور والصوت من يوتيوب وتيك توك وإنستغرام وفيسبوك وريديت و X وبنترست بالمعرض. الصق الرابط، اختار الجودة، ونزّل.',
      );
  String get credits => _t('Credits', 'حقوق');
  String get version => _t('Version', 'الإصدار');
  String get emptyLibrary => _t('Nothing saved yet', 'بعد ما نزلت شي');
  String get emptyLibraryHint => _t('What you download shows up here.', 'اللي تنزله يطلع هنا.');
  String get addLink => _t('Add a link', 'ضيف رابط');
  String get emptyFilter => _t('Nothing here for this filter', 'ماكو شي بهذا الفلتر');
  String get showAll => _t('Show all', 'اعرض الكل');
  String get downloadFailed => _t('Download failed', 'التنزيل فشل');
  String get alreadyHave => _t('You already have this', 'هذا نازل عندك');
  String get alreadyHaveBody =>
      _t(_pc ? 'This file is still on this computer.' : 'This file is still on your phone.', 'الملف بعد موجود على جهازك.');
  // Nazzil tracks only its own copy, so these say nothing about the gallery or Downloads.
  String get missingFile => _t('File was removed', 'الملف انحذف');
  String get fileGone => _t("Nazzil's copy of this file is gone.", 'نسخة نزل من الملف راحت.');
  String get downloadAgain => _t('Download again', 'نزّله مرة ثانية');
  String get cantPlay => _t('This video will not play here.', 'الفيديو ما يشتغل هنا.');
  String get cantOpen => _pc
      ? _t(
          'Nothing on this computer could open it. It was saved to Downloads/Nazzil.',
          'ماكو برنامج بجهازك يفتحه. انحفظ بمجلد Nazzil بالتنزيلات.',
        )
      : _t('No app on this phone could open it.', 'ماكو تطبيق بتلفونك يفتحه.');
  String get photoFailed => _t('Could not load this photo.', 'ما كدرت أجيب الصورة.');
  String get deleteTitle => _t('Delete this download?', 'تحذف هذا التنزيل؟');
  // Delete removes the copy Nazzil keeps for itself and nothing else.
  String get deleteBody => _pc
      ? _t(
          'Nazzil deletes its own copy. Downloads/Nazzil is left as it is.',
          'نزل يحذف نسخته بس. مجلد Nazzil بالتنزيلات يبقى مثل ما هو.',
        )
      : _t(
          'Nazzil deletes its own copy. Your gallery and files are left as they are.',
          'نزل يحذف نسخته بس. المعرض وملفاتك يبقون مثل ما همّ.',
        );
  String get queued => _t('Waiting', 'بالانتظار');
  String get clipOffer => _t('A supported link is on your clipboard', 'في رابط مدعوم بالنسخ');
  String get fetchThis => _t('Fetch this', 'جيب هذا');
  String get openGallery => _pc ? _t('Open file', 'افتح الملف') : _t('Open in gallery', 'افتح بالمعرض');
  String get filterAll => _t('All', 'الكل');
  String get filterAllApps => _t('All apps', 'كل التطبيقات');
  String get filterPhotos => _t('Photos', 'صور');
  String get filterVideos => _t('Videos', 'فيديو');
  String get filterAudio => _t('Audio', 'صوت');
  String get how => _pc
      ? _t(
          'Paste a link or drop it on this window. Pick the quality and it saves to the Nazzil folder in Downloads.',
          'الصق الرابط أو اسحبه على النافذة. اختار الجودة وينحفظ بمجلد Nazzil بالتنزيلات.',
        )
      : _t(
          'Share a post to Nazzil from any app, or paste its link here. Pick the quality and it saves to the Nazzil album in your gallery.',
          'شارك المنشور ويّا نزل من أي تطبيق، أو الصق الرابط هنا. اختار الجودة وينحفظ بألبوم نزل بالمعرض.',
        );
  String get ofWord => _t('of', 'من');
  String get previous => _t('Previous', 'السابق');
  String get next => _t('Next', 'التالي');
  String get updateAvailable => _t('A new version is out', 'في إصدار جديد');
  String get updateNow => _t('Update', 'حدّث');
  String get albumSaved => _t('Photos saved', 'الصور انحفظت');
  String get view => _t('View', 'عرض');
  String get youtube => 'YouTube';
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
        Failure.pasteFirst => _t('Paste a link first.', 'أول شي الصق رابط.'),
        Failure.unsupported => _t('This link is not from a supported app yet.', 'هذا الرابط مو من تطبيق مدعوم بعد.'),
        Failure.network => _t('Connection dropped.', 'النت انقطع.'),
        Failure.blocked => _t('This post blocked the download.', 'المنشور منع التنزيل.'),
        Failure.permission => _t('Gallery permission is needed to save.', 'نحتاج إذن المعرض للحفظ.'),
        // "May be", because a site that refuses the app answers the same way.
        Failure.unavailable => _t('This post may be private or deleted.', 'يمكن المنشور خاص أو محذوف.'),
        Failure.noMedia => _t('This post has no video or photos to save.', 'هذا المنشور ما بيه فيديو ولا صور.'),
        Failure.badLink => _t('This link does not point to a post.', 'هذا الرابط مو لمنشور.'),
        Failure.processing => _t('This video is still processing.', 'الفيديو بعده يتجهز.'),
        Failure.convert => _t('Downloaded, but converting it failed.', 'نزل بس التحويل فشل.'),
        Failure.load => _t('Could not load this.', 'ما كدرت أجيبه.'),
        Failure.download => _t('Could not download this.', 'ما كدرت أنزّله.'),
      };

  String advice(Failure kind) => switch (kind) {
        Failure.network || Failure.convert || Failure.load || Failure.download => _t('Try again.', 'حاول مرة ثانية.'),
        Failure.blocked => _t('Try again later.', 'جرّب بعدين.'),
        Failure.processing => _t('Try again in a bit.', 'جرّب بعد شوية.'),
        _ => '',
      };

  /// What went wrong and what to do, for a spot with no button of its own.
  String failureLine(Failure kind) => [failure(kind), advice(kind)].where((part) => part.isNotEmpty).join(' ');

  String photosN(int n) => isAr ? '$n صور' : (n == 1 ? '1 photo' : '$n photos');

  String itemsN(int n) => isAr ? '$n عناصر' : (n == 1 ? '1 item' : '$n items');

  String waitingN(int n) => isAr ? '$n بالانتظار' : (n == 1 ? '1 waiting' : '$n waiting');

  /// 75 seconds reads 1:15; an hour and more reads 1:02:03.
  String clock(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final sec = (seconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$sec' : '$m:$sec';
  }

  String _t(String en, String ar) => isAr ? ar : en;
}
