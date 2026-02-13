// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'Motion AI';

  @override
  String get systemSettings => 'إعدادات النظام';

  @override
  String get systemSettingsDesc =>
      'إدارة أجهزة MotionAI ونماذج الذكاء الاصطناعي وتفضيلات الحساب.';

  @override
  String get accountProfile => 'ملف الحساب';

  @override
  String get cameraCalibration => 'معايرة الكاميرا';

  @override
  String get aiProcessing => 'معالجة الذكاء الاصطناعي';

  @override
  String get personalInformation => 'المعلومات الشخصية';

  @override
  String get user => 'المستخدم';

  @override
  String get changePassword => 'تغيير كلمة المرور';

  @override
  String get language => 'اللغة';

  @override
  String get light => 'فاتح';

  @override
  String get discardChanges => 'تجاهل التغييرات';

  @override
  String get saveSettings => 'حفظ الإعدادات';

  @override
  String welcomeBack(String username) {
    return 'مرحبًا بعودتك، $username';
  }

  @override
  String get startNewAnalysis => 'بدء تحليل جديد';

  @override
  String get searchExercises => 'البحث عن التمارين...';

  @override
  String get all => 'الكل';

  @override
  String get strength => 'القوة';

  @override
  String get mobility => 'المرونة';

  @override
  String get bodyWeight => 'وزن الجسم';

  @override
  String get rehab => 'إعادة التأهيل';

  @override
  String get dashboard => 'لوحة التحكم';

  @override
  String get settings => 'الإعدادات';

  @override
  String get deepLearningBackend => 'Deep Learning Backend';

  @override
  String get status => 'Status';

  @override
  String get calibrated => 'Calibrated';

  @override
  String get processingModel => 'Processing Model';

  @override
  String get performanceMode => 'Performance Mode';

  @override
  String get computingDevice => 'Computing Device';

  @override
  String get highAccuracy => 'High Accuracy';

  @override
  String get balanced => 'Balanced';

  @override
  String get highSpeed => 'High Speed';

  @override
  String modifyCamera(String cameraName) {
    return 'Modify $cameraName';
  }

  @override
  String get updateDeviceSource =>
      'Update device source and calibration parameters';

  @override
  String get chooseCameraSource => '1. CHOOSE CAMERA SOURCE';

  @override
  String get addCalibrationData => '2. ADD CALIBRATION DATA';

  @override
  String get clickToUpload => 'Click to upload calibration file';

  @override
  String get uploadDesc => 'or drag and drop your .bin or .json file here';

  @override
  String get applyChanges => 'Apply Changes';

  @override
  String get cancel => 'Cancel';

  @override
  String get aiEngineDescription =>
      'حدد محرك الذكاء الاصطناعي لاستخراج النقاط الرئيسية وملاءمة SMPL.';

  @override
  String get legacyPose2DEngine => 'محرك Pose2D القديم';

  @override
  String get legacyPose2DDesc => 'معالجة أسرع، دقة مكانية مخفضة.';

  @override
  String get deepLearningBackendDesc => 'محسن لتتبع الوضعيات بدقة عالية.';

  @override
  String get newMultiViewAnalysis => 'تحليل جديد متعدد الرؤى';

  @override
  String get newAnalysisSubtitle =>
      'قم بتحميل تدفقات فيديو متزامنة لإعادة البناء ثلاثي الأبعاد ونمذجة SMPL';

  @override
  String get captureMethod => 'طريقة الالتقاط';

  @override
  String get uploadStreams => 'تحميل التدفقات';

  @override
  String get syncAndProcess => 'المزامنة والمعالجة';

  @override
  String get uploadFiles => 'تحميل الملفات';

  @override
  String get uploadFilesDesc =>
      'قم بتحميل ملفات فيديو متزامنة موجودة من ما يصل إلى 4 زوايا للكاميرا.';

  @override
  String get liveMultiCam => 'مباشرة من كاميرات متعددة';

  @override
  String get liveMultiCamDesc =>
      'البث مباشرة من الكاميرات المتصلة للتحليل الآني.';

  @override
  String get analysisInfoBanner =>
      'للحصول على أفضل النتائج، تأكد من أن جميع الكاميرات تشترك في نفس معدل الإطارات ومعايرتها باستخدام نموذج المعايرة المقدم.';

  @override
  String get cameraAngleFront => 'زاوية الكاميرا 1 - أمامي';

  @override
  String get cameraAngleLeft => 'زاوية الكاميرا 2 - يسار';

  @override
  String get cameraAngleBack => 'زاوية الكاميرا 3 - خلف';

  @override
  String get cameraAngleRight => 'زاوية الكاميرا 4 - يمين';

  @override
  String get back => 'رجوع';
}
