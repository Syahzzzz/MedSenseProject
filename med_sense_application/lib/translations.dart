import 'package:flutter/material.dart';

// Global Notifier for Language State
final ValueNotifier<String> appLanguageNotifier = ValueNotifier<String>('English');

class AppTranslations {
  static String get(String key) {
    final lang = appLanguageNotifier.value;
    return _localizedValues[lang]?[key] ?? key; // Fallback to key if not found
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'English': {
      // Auth
      'login': 'Login',
      'signup': 'Sign Up',
      'email': 'Email',
      'password': 'Password',
      'forgot_pass': 'Forget password?',
      'no_account': 'Don\'t have an account? ',
      'welcome_title': 'Good to See You Again!',
      'welcome_subtitle': 'Let\'s keep that smile healthy and shining',
      'create_account': 'Create Account',
      'medsense_slogan': 'Hey there! Let\'s Keep You Healthy',
      
      // Dashboard
      'hello': 'Hello ',
      'upcoming': 'Upcoming',
      'services': 'Services',
      'view_all': 'View all',
      'top_doctor': 'Top Doctor & Staff',
      'home': 'HOME',
      'location': 'LOCATION',
      'booking': 'BOOKING',
      'profile': 'PROFILE',
      'dental_clinic_rawang': 'Dental Clinic Rawang',
      
      // Services Keys
      'Braces': 'Braces',
      'Scaling': 'Scaling',
      'Whitening': 'Whitening',
      'Retainers': 'Retainers',

      // Profile
      'profile_title': 'Profile',
      'personal_info': 'Personal Information',
      'personal_info_sub': 'Edit name, birthday, email',
      'security': 'Security',
      'change_password': 'Change Password',
      'notifications': 'Notifications',
      'notifications_sub': 'Receive appointment reminders',
      'language': 'Language',
      'logout': 'Log Out',
      'permission_required': 'Permission Required',
      'permission_msg': 'Notifications are disabled. Please go to settings to enable them.',
      'cancel': 'Cancel',
      'open_settings': 'Open Settings',
    },
    'Bahasa Melayu': {
      // Auth
      'login': 'Log Masuk',
      'signup': 'Daftar',
      'email': 'Emel',
      'password': 'Kata Laluan',
      'forgot_pass': 'Lupa kata laluan?',
      'no_account': 'Tiada akaun? ',
      'welcome_title': 'Gembira Melihat Anda!',
      'welcome_subtitle': 'Mari kekalkan senyuman itu sihat dan bersinar',
      'create_account': 'Cipta Akaun',
      'medsense_slogan': 'Hai! Mari Kekal Sihat',

      // Dashboard
      'hello': 'Helo ',
      'upcoming': 'Akan Datang',
      'services': 'Perkhidmatan',
      'view_all': 'Lihat semua',
      'top_doctor': 'Doktor & Staf Terbaik',
      'home': 'UTAMA',
      'location': 'LOKASI',
      'booking': 'TEMPAHAN',
      'profile': 'PROFIL',
      'dental_clinic_rawang': 'Klinik Gigi Rawang',

      // Services Keys
      'Braces': 'Pendakap',
      'Scaling': 'Cuci Gigi',
      'Whitening': 'Pemutihan',
      'Retainers': 'Retainer',

      // Profile
      'profile_title': 'Profil',
      'personal_info': 'Maklumat Peribadi',
      'personal_info_sub': 'Edit nama, hari jadi, emel',
      'security': 'Keselamatan',
      'change_password': 'Tukar Kata Laluan',
      'notifications': 'Notifikasi',
      'notifications_sub': 'Terima peringatan janji temu',
      'language': 'Bahasa',
      'logout': 'Log Keluar',
      'permission_required': 'Izin Diperlukan',
      'permission_msg': 'Notifikasi dimatikan. Sila ke tetapan untuk mengaktifkannya.',
      'cancel': 'Batal',
      'open_settings': 'Buka Tetapan',
    },
    'Mandarin': {
      // Auth
      'login': '登录',
      'signup': '注册',
      'email': '电子邮件',
      'password': '密码',
      'forgot_pass': '忘记密码？',
      'no_account': '没有账号？ ',
      'welcome_title': '很高兴见到你！',
      'welcome_subtitle': '让我们保持健康的微笑',
      'create_account': '创建账号',
      'medsense_slogan': '嘿！让我们保持健康',

      // Dashboard
      'hello': '你好 ',
      'upcoming': '即将到来',
      'services': '服务',
      'view_all': '查看全部',
      'top_doctor': '顶级医生与员工',
      'home': '主页',
      'location': '位置',
      'booking': '预订',
      'profile': '个人资料',
      'dental_clinic_rawang': '万挠牙科诊所',

      // Services Keys
      'Braces': '牙套',
      'Scaling': '洗牙',
      'Whitening': '美白',
      'Retainers': '保持器',

      // Profile
      'profile_title': '个人资料',
      'personal_info': '个人信息',
      'personal_info_sub': '编辑姓名，生日，电子邮件',
      'security': '安全',
      'change_password': '更改密码',
      'notifications': '通知',
      'notifications_sub': '接收预约提醒',
      'language': '语言',
      'logout': '登出',
      'permission_required': '需要权限',
      'permission_msg': '通知已禁用。请前往设置启用它们。',
      'cancel': '取消',
      'open_settings': '打开设置',
    },
  };
}