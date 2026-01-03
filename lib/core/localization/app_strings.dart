import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/locale_provider.dart';

class AppStrings {
  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // Titles
      'titleHome': 'EyeVLM Dashboard',
      'titleSubmission': 'EyeVLM Submission',
      'titleHistory': 'Scan History',
      'titleProfile': 'Profile',
      'titleSettings': 'Settings',
      
      // Bottom Nav
      'navHome': 'Home',
      'navHistory': 'History',
      'navProfile': 'Profile',

      // Home Screen
      'welcome': 'Hello',
      'btnStartScan': 'Start New Scan',
      'recentActivity': 'Recent Activity',
      'noRecentActivity': 'No recent scans',
      'noRecentSubtitle': 'Your analysis history will appear here.',

      // History Screen
      'noScansYet': 'No scans yet.',
      'confidence': 'Confidence',

      // Submission Screen
      'hintSymptoms': 'Describe Symptoms (Required)\ne.g., blurred vision, redness...',
      'hintSymptomsOptional': 'Describe Symptoms (Optional)',
      'btnAnalyze': 'Analyze Image',
      'txtTapToUpload': 'Tap to upload eye image',
      'txtAnalyzing': 'Analyzing image patterns...',
      'txtSecureProcessing': 'Securely processing data.',
      'msgErrorPick': 'Error picking image',
      'msgErrorSubmit': 'Submission failed',

      // Profile Screen
      'btnHelp': 'Help & Support',
      'btnLogout': 'Log Out',
      'txtLanguage': 'Language',
      'txtDarkMode': 'Dark Mode',

      // Onboarding
      'onboardTitle1': 'AI-Powered Analysis',
      'onboardDesc1': 'Instant eye disease detection using advanced AI.',
      'onboardTitle2': 'Medical Reports',
      'onboardDesc2': 'Generate PDF reports for your doctor.',
      'onboardTitle3': 'Secure & Private',
      'onboardDesc3': 'Your data is encrypted and safe.',
      'btnGetStarted': 'Get Started',

      // Auth
      'titleLogin': 'Log In',
      'titleSignUp': 'Sign Up',
      'btnSignUp': 'Sign Up',
      'msgNoAccount': "Don't have an account? Sign Up",
      'msgHaveAccount': "Already have an account? Log In",
    },
    'bn': {
      // Titles
      'titleHome': 'EyeVLM ড্যাশবোর্ড',
      'titleSubmission': 'EyeVLM জমা',
      'titleHistory': 'স্ক্যান ইতিহাস',
      'titleProfile': 'প্রোফাইল',
      'titleSettings': 'সেটিংস',
      
      // ... previous values ...
      
      // Profile Screen
      'btnHelp': 'সহায়তা এবং সমর্থন',
      'btnLogout': 'লগ আউট',
      'txtLanguage': 'ভাষা',
      'txtDarkMode': 'ডার্ক মোড',

      // Onboarding
      'onboardTitle1': 'AI-চালিত বিশ্লেষণ',
      'onboardDesc1': 'উন্নত AI ব্যবহার করে চোখের রোগ নির্ণয়।',
      'onboardTitle2': 'মেডিকেল রিপোর্ট',
      'onboardDesc2': 'আপনার ডাক্তারের জন্য PDF রিপোর্ট তৈরি করুন।',
      'onboardTitle3': 'নিরাপদ এবং গোপনীয়',
      'onboardDesc3': 'আপনার ডেটা এনক্রিপ্ট করা এবং নিরাপদ।',
      'btnGetStarted': 'শুরু করুন',

      // Auth
      'titleLogin': 'লগ ইন করুন',
      'titleSignUp': 'নিবন্ধন করুন',
      'btnSignUp': 'নিবন্ধন',
      'msgNoAccount': "অ্যাকাউন্ট নেই? নিবন্ধন করুন",
      'msgHaveAccount': "ইতোমধ্যে অ্যাকাউন্ট আছে? লগ ইন করুন",
    }
  };

  static String tr(WidgetRef ref, String key) {
    final locale = ref.watch(localeProvider);
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }
}
