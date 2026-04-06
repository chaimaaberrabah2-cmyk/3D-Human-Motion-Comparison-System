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
  String get deepLearningBackend => 'محرك التعلم العميق';

  @override
  String get status => 'الحالة';

  @override
  String get calibrated => 'معاير';

  @override
  String get processingModel => 'نموذج المعالجة';

  @override
  String get performanceMode => 'وضع الأداء';

  @override
  String get computingDevice => 'جهاز الحوسبة';

  @override
  String get highAccuracy => 'دقة عالية';

  @override
  String get balanced => 'متوازن';

  @override
  String get highSpeed => 'سرعة عالية';

  @override
  String modifyCamera(String cameraName) {
    return 'تعديل $cameraName';
  }

  @override
  String get updateDeviceSource => 'تحديث مصدر الجهاز ومعاملات المعايرة';

  @override
  String get chooseCameraSource => '١. اختيار مصدر الكاميرا';

  @override
  String get addCalibrationData => 'إضافة بيانات المعايرة';

  @override
  String get clickToUpload => 'انقر لتحميل ملف المعايرة';

  @override
  String get uploadDesc => 'أو اسحب وأفلت ملف .bin أو .json هنا';

  @override
  String get applyChanges => 'تطبيق التغييرات';

  @override
  String get cancel => 'إلغاء';

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

  @override
  String get bodyMeasurements => 'قياسات الجسم';

  @override
  String get heightLabel => 'الطول';

  @override
  String get weightLabel => 'الوزن';

  @override
  String get ageLabel => 'العمر';

  @override
  String get genderLabel => 'الجنس';

  @override
  String get maleLabel => 'ذكر';

  @override
  String get femaleLabel => 'أنثى';

  @override
  String get notSpecifiedLabel => 'غير محدد';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get networkCameras => 'كاميرات الشبكة (IP / RTSP)';

  @override
  String get addUrl => 'إضافة رابط';

  @override
  String get customIpStream => 'بث مخصص';

  @override
  String get networkStreamAssigned => 'تم تعيين بث الشبكة';

  @override
  String get previewDisabled =>
      'تم تعطيل المعاينة لتوفير الموارد.\nالخادم سيعالجه مباشرة.';

  @override
  String get noNetworkCameras =>
      'لم تتم إضافة كاميرات. انقر على \'إضافة رابط\'.';

  @override
  String get addNetworkCamera => 'إضافة كاميرا شبكة';

  @override
  String get enterStreamUrl => 'أدخل رابط RTSP أو HTTP الخاص بكاميرا IP.';

  @override
  String get addButton => 'إضافة';

  @override
  String get editInformation => 'تعديل المعلومات';

  @override
  String get usernameLabel => 'اسم المستخدم';

  @override
  String get emailLabel => 'البريد الإلكتروني';

  @override
  String get saveButton => 'حفظ';

  @override
  String get infoUpdated => 'تم تحديث المعلومات!';

  @override
  String get errorPrefix => 'خطأ: ';

  @override
  String get editPassword => 'تغيير كلمة المرور';

  @override
  String get oldPassword => 'كلمة المرور القديمة';

  @override
  String get newPassword => 'كلمة المرور الجديدة';

  @override
  String get confirmPassword => 'تأكيد كلمة المرور';

  @override
  String get passwordsDoNotMatch => 'كلمات المرور غير متطابقة!';

  @override
  String get passwordTooShort => 'كلمة المرور قصيرة جدًا (على الأقل 4)';

  @override
  String get passwordUpdated => 'تم تحديث كلمة المرور!';

  @override
  String editField(String fieldName) {
    return 'تعديل $fieldName';
  }

  @override
  String fieldUpdated(String fieldName) {
    return 'تم تحديث $fieldName!';
  }

  @override
  String get editGender => 'تعديل الجنس';

  @override
  String get unassigned => 'غير معين';

  @override
  String get refreshCameras => 'تحديث الكاميرات';

  @override
  String get externalCamera => 'كاميرا خارجية';

  @override
  String get builtInFrontCamera => 'الكاميرا الأمامية';

  @override
  String get builtInBackCamera => 'الكاميرا الخلفية';
}
