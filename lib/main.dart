import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_constants.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/locale_provider.dart';
import 'core/theme/app_theme.dart';
import 'app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  // Global Error Handler ("The Backup")
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               const Icon(Icons.error_outline, size: 60, color: Colors.amber),
               const SizedBox(height: 20),
               Text(
                 "Oops! Something went wrong.", 
                 style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
                 textAlign: TextAlign.center,
               ),
               const SizedBox(height: 10),
               Text(
                 "We encountered an unexpected error. Please restart the app.",
                 textAlign: TextAlign.center,
                 style: GoogleFonts.inter(color: Colors.grey[600]),
               ),
               if (const bool.fromEnvironment("dart.vm.product") == false)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(details.exceptionAsString(), style: const TextStyle(color: Colors.red, fontSize: 10)),
                ),
            ],
          ),
        ),
      ),
    );
  };

  runApp(const ProviderScope(child: EyeVLMApp()));
}

class EyeVLMApp extends ConsumerWidget {
  const EyeVLMApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'EyeVLM',
      debugShowCheckedModeBanner: false,
      locale: locale, // 🌐 Connect Language Switcher
      builder: (context, child) {
         // 📏 CONSTANT FONT SIZE: Prevent system font scaling from ignoring our design
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: child!,
        );
      },
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
