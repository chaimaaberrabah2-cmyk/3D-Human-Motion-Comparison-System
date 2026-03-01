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
  String get history => 'السجل';

  @override
  String get recentActivity => 'النشاط الأخير';

  @override
  String get viewAllRecords => 'عرض جميع السجلات';

  @override
  String get totalSessions => 'إجمالي الجلسات';

  @override
  String get avgAccuracy => 'متوسط الدقة';

  @override
  String get processingTime => 'وقت المعالجة';

  @override
  String get activeCameras => 'الكاميرات النشطة';

  @override
  String get sessionId => 'معرف الجلسة';

  @override
  String get dateTime => 'التاريخ والوقت';

  @override
  String get deviceSource => 'مصدر الجهاز';

  @override
  String get duration => 'المدة';

  @override
  String get score => 'النتيجة';

  @override
  String get performancePreview => 'معاينة';

  @override
  String get completedStatus => 'مكتمل';

  @override
  String get failedStatus => 'فشل';

  @override
  String get stable => 'مستقر';

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
  String get addCalibrationData => 'إضافة بيانات المعايرة';

  @override
  String get clickToUpload => 'انقر لتحميل ملف المعايرة';

  @override
  String get uploadDesc => 'or drag and drop your .bin or .json file here';

  @override
  String get applyChanges => 'تطبيق التغييرات';

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

  @override
  String get addNewCamera => 'إضافة كاميرا جديدة';

  @override
  String get deleteCameraTitle => 'حذف الكاميرا؟';

  @override
  String deleteCameraMessage(String cameraName) {
    return 'هل أنت متأكد من رغبتك في حذف $cameraName؟ لا يمكن التراجع عن هذا الإجراء.';
  }

  @override
  String get delete => 'حذف';

  @override
  String get minimumCamerasWarning => 'يجب أن يكون لديك 4 كاميرات على الأقل';

  @override
  String get languageLabel => '(Language)';

  @override
  String get unsavedChangesTitle => 'تغييرات غير محفوظة';

  @override
  String get unsavedChangesMessage =>
      'لديك تغييرات غير محفوظة. ماذا تريد أن تفعل؟';

  @override
  String get saveAndContinue => 'حفظ ومتابعة';

  @override
  String get discardAndContinue => 'تجاهل ومتابعة';

  @override
  String get cameraSource => 'مصدر الكاميرا';

  @override
  String get calibrationFile => 'ملف المعايرة';

  @override
  String get uploadCalibration => 'تحميل المعايرة';

  @override
  String get dragDropHint => 'أو اسحب وأفلت ملف .bin أو .json هنا';

  @override
  String get statusCalibrated => 'الحالة: معاير';

  @override
  String get aiAlgorithm => 'خوارزمية الذكاء الاصطناعي';

  @override
  String get blazePose => 'MediaPipe (BlazePose)';

  @override
  String get openPose => 'OpenPose';

  @override
  String get yolo => 'YOLO';

  @override
  String get pavllo => 'Pavllo';

  @override
  String get blazePoseDesc => 'سريع وخفيف. الأفضل للاستخدام الفوري على الجوال.';

  @override
  String get openPoseDesc => 'دقة عالية. يستهلك موارد كثيرة.';

  @override
  String get yoloDesc => 'كشف سريع للكائنات والوضعيات. سرعة ودقة متوازنة.';

  @override
  String get pavlloDesc =>
      'رفع متخصص للوضعيات ثلاثية الأبعاد من فيديو ثنائي الأبعاد.';

  @override
  String get startRecording => 'بدء التسجيل';

  @override
  String get rec => 'تسجيل';

  @override
  String get start => 'بدء';

  @override
  String get newAnalysis => 'تحليل جديد';

  @override
  String get selectExercise => 'اختر التمرين';

  @override
  String get pleaseSelectExercise => 'يرجى اختيار التمرين المرجعي الخاص بك';

  @override
  String get userReconstruction => 'إعادة بناء المستخدم';

  @override
  String get analysisResultsTitle => 'نتائج التحليل';

  @override
  String get exportPdf => 'تصدير PDF';

  @override
  String get exportingPdfMessage => 'تصدير PDF... (الميزة قيد التطوير)';

  @override
  String get syncVideoStreams => 'مزامنة تدفقات الفيديو...';

  @override
  String get extractingKeypoints => 'استخراج النقاط الرئيسية (BlazePose)...';

  @override
  String get fittingSmpl => 'ملاءمة نموذج الجسم SMPL-X...';

  @override
  String get optimizingMesh => 'تحسين إعادة البناء ثلاثي الأبعاد...';

  @override
  String get generatingReports => 'إنشاء تقارير المقارنة...';

  @override
  String remainingTimeLabel(int time) {
    return 'الوقت المتبقي: $time ثانية';
  }

  @override
  String get logAnalysisStarted => 'بدأت التحليلات';

  @override
  String get logSyncOk => 'مزامنة التدفقات - تم';

  @override
  String get logExtractionProgress => 'استخراج النقاط الرئيسية قيد التنفيذ';

  @override
  String get logSmplActive => 'ملاءمة شبكة SMPL-X نشطة';

  @override
  String analysisFeedback(String exerciseName) {
    return 'مقارنة حركتك مع $exerciseName. يظهر التحليل الأولي دقة في الشكل بنسبة 85%. ركز على خفض وركيك أكثر خلال المرحلة اللامركزية.';
  }

  @override
  String get strengthAnalysisMode => 'وضع تحليل القوة';

  @override
  String get mobilityAnalysisMode => 'وضع تحليل المرونة';

  @override
  String get beginner => 'مبتدئ';

  @override
  String get intermediate => 'متوسط';

  @override
  String get advanced => 'متقدم';

  @override
  String get descriptionLabel => 'الوصف';

  @override
  String get instructionsLabel => 'التعليمات';

  @override
  String get motionVisualization => 'تصوير الحركة ثلاثي الأبعاد';

  @override
  String get motionVisualizationSubtitle => 'مقارنة الحركة المثالية ستظهر هنا';

  @override
  String get startAnalysis => 'بدء التحليل';
}
