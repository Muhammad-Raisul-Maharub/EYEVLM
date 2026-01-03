import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_constants.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/locale_provider.dart';
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
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA), // Soft Blue-Grey
        primaryColor: const Color(0xFF009688), // Medical Teal
        
        // 1. Modern Typography
        // 1. Modern Typography (Use ThemeData.light() to match structure of darkTheme)
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.light().textTheme,
        ).copyWith(
          displayLarge: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF2D3748)),
          titleLarge: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF2D3748)),
        ),

        // 2. Modern Card Theme (Soft Shadows)
        cardTheme: CardThemeData(
          elevation: 2,
          shadowColor: Colors.black.withAlpha(26),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white,
        ),

        // 3. Modern Button Theme (Pill Shapes)
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF009688),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
        
        // 4. Modern Input Fields
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none, // Clean look
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF009688), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF009688),
          brightness: Brightness.light,
          surface: const Color(0xFFF5F7FA),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1A202C), // Dark Slate
        primaryColor: const Color(0xFF009688),
        
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        
        cardTheme: CardThemeData(
          elevation: 2,
          shadowColor: Colors.black.withAlpha(77),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: const Color(0xFF2D3748),
        ),
        
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF009688),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2D3748),
          border: OutlineInputBorder(
             borderRadius: BorderRadius.circular(12),
             borderSide: BorderSide.none,
          ),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF009688),
          brightness: Brightness.dark,
          surface: const Color(0xFF1A202C),
        ),
      ),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
