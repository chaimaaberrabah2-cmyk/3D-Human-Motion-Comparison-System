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
}
