import '../models/media.dart';

class S {
  const S(this.lang);
  final String lang;

  bool get isAr => lang == 'ar';
  bool get rtl => isAr;

  String get appName => _t('Nazzil', 'نزل');
  String get tagline => _t('Download the video. Keep it.', 'نزّل الفيديو. خليه عندك.');
  String get photoTagline =>
      _t('Videos, TikTok photos, Instagram carousels. Straight into your gallery.', 'فيديو وصور تيك توك وألبومات إنستغرام. ينزلون بالمعرض.');
  String get pasteHint =>
      _t('Paste or share a YouTube, TikTok, Instagram or Facebook link', 'الصق رابط يوتيوب أو تيك توك أو إنستغرام أو فيسبوك');
  String get paste => _t('Paste', 'لصّق');
  String get clear => _t('Clear', 'امسح');
  String get fetch => _t('Fetch', 'جيب');
  String get fetching => _t('Reading the link…', 'لحظات…');
  String get cancel => _t('Cancel', 'ألغِ');
  String get cancelled => _t('Cancelled', 'أُلغي');
  String get pause => _t('Pause', 'وقّف');
  String get paused => _t('Paused', 'متوقف');
  String get resume => _t('Resume', 'كمّل');
  String get download => _t('Download', 'نزّل');
  String get savePhotos => _t('Save photos', 'حفظ الصور');
  String get savePhoto => _t('Save this photo', 'حفظ هذي الصورة');
  String get photos => _t('Photos', 'صور');
  String get photoCount => _t('photos', 'صور');
  String get video => _t('Video', 'فيديو');
  String get audio => _t('Audio', 'صوت');
  String get hd => _t('HD', 'جودة عالية');
  String get sd => _t('SD', 'جودة عادية');
  String get home => _t('Home', 'الرئيسية');
  String get library => _t('Library', 'التحميلات');
  String get settings => _t('Settings', 'الإعدادات');
  String get ready => _t('Ready', 'جاهز');
  String get downloading => _t('Downloading…', 'قاعد ينزّل…');
  String get downloaded => _t('Saved', 'تم التنزيل');
  String get play => _t('Play', 'شغّل');
  String get share => _t('Share', 'شارك');
  String get delete => _t('Delete', 'احذف');
  String get close => _t('Close', 'سكّر');
  String get original => _t('Original', 'الأصل');
  String get language => _t('Language', 'اللغة');
  String get languageSystem => _t('System language', 'لغة الجهاز');
  String get english => 'English';
  String get arabic => 'العربية';
  String get theme => _t('Theme', 'المظهر');
  String get themeSystem => _t('System theme', 'مظهر الجهاز');
  String get themeLight => _t('Light', 'فاتح');
  String get themeDark => _t('Dark', 'داكن');
  String get about => _t('About', 'عن التطبيق');
  String get aboutBody => _t(
        'Nazzil saves videos, TikTok photo posts and Instagram carousels into your gallery. Paste a link, pick a quality, download.',
        'نزل يحفظ الفيديو ومنشورات تيك توك وإنستغرام الصور بالمعرض. الصق الرابط، اختار الجودة، ونزّل.',
      );
  String get credits => _t('Credits', 'حقوق');
  String get version => _t('Version', 'الإصدار');
  String get emptyLibrary => _t('Nothing saved yet', 'بعد ما نزلت شي');
  String get emptyLibraryHint =>
      _t('Downloads land here. Photos stay photos.', 'التحميلات تظهر هنا. الصور تبقى صور.');
  String get pasteFirst => _t('Paste a link first.', 'أول شي الصق رابط.');
  String get unknownPlatform =>
      _t('This link is not from a supported app yet.', 'هذا الرابط مو من تطبيق مدعوم بعد.');
  String get failed => _t('Could not load this. Try again.', 'ما كدرت أجيبه. حاول مرة ثانية.');
  String get downloadFailed => _t('Download failed', 'التنزيل فشل');
  String get alreadyHave => _t('You already have this', 'هذا نازل عندك');
  String get alreadyHaveBody => _t('This file is still on your phone.', 'الملف بعد موجود على جهازك.');
  String get missingFile => _t('Removed from gallery', 'انحذف من المعرض');
  String get queued => _t('Waiting', 'بالانتظار');
  String get clipOffer => _t('A supported link is on your clipboard', 'في رابط مدعوم بالنسخ');
  String get fetchThis => _t('Fetch this', 'جيب هذا');
  String get openGallery => _t('Open in gallery', 'افتح بالمعرض');
  String get filterAll => _t('All', 'الكل');
  String get filterPhotos => _t('Photos', 'صور');
  String get filterVideos => _t('Videos', 'فيديو');
  String get filterAudio => _t('Audio', 'صوت');
  String get howTitle => _t('Three beats', 'ثلاث خطوات');
  String get step1 => _t('Share or paste a link', 'شارك أو الصق الرابط');
  String get step2 => _t('Pick HD, SD, audio — or save photo albums', 'اختار الجودة — أو احفظ ألبوم الصور');
  String get step3 => _t('It lands in Gallery → Nazzil', 'ينزل بالمعرض ← نزل');
  String get ofWord => _t('of', 'من');
  String get updateAvailable => _t('A new version is out', 'في إصدار جديد');
  String get updateNow => _t('Update', 'حدّث');
  String get updateLater => _t('Later', 'بعدين');
  String get updateCurrent => _t('You are on the latest version', 'هذا أحدث إصدار');
  String get updateCheck => _t('Check for update', 'تحقق من التحديث');
  String get permissionNeeded =>
      _t('Gallery permission is needed to save.', 'نحتاج إذن المعرض للحفظ.');
  String get openSettings => _t('Settings', 'الإعدادات');
  String get platforms => _t('YouTube · TikTok · Instagram · Facebook', 'يوتيوب · تيك توك · إنستغرام · فيسبوك');
  String get albumSaved => _t('Photos saved', 'الصور انحفظت');
  String get view => _t('View', 'عرض');
  String get youtube => 'YouTube';
  String get tiktok => _t('TikTok', 'تيك توك');
  String get instagram => _t('Instagram', 'إنستغرام');
  String get facebook => _t('Facebook', 'فيسبوك');

  String platformName(PlatformId platform) => switch (platform) {
        PlatformId.youtube => youtube,
        PlatformId.tiktok => tiktok,
        PlatformId.instagram => instagram,
        PlatformId.facebook => facebook,
        PlatformId.unknown => '',
      };

  String photosN(int n) => isAr ? '$n صور' : (n == 1 ? '1 photo' : '$n photos');

  String waitingN(int n) => isAr ? '$n بالانتظار' : (n == 1 ? '1 waiting' : '$n waiting');

  String _t(String en, String ar) => isAr ? ar : en;
}
