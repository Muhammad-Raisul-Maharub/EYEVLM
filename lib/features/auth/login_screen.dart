import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/localization/app_strings.dart';
import '../../core/widgets/responsive_wrapper.dart';
import '../../core/utils/app_notifications.dart'; // Import
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String? _errorMessage;

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authServiceProvider).signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().contains('Invalid login credentials') 
              ? 'Invalid email or password' 
              : 'Login failed: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, 
      body: ResponsiveWrapper(
        mobileBody: _buildMobileLayout(context),
        webBody: _buildWebLayout(context),
      ),
    );
  }

  // 📱 MOBILE LAYOUT (Original)
  Widget _buildMobileLayout(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // 🌊 1. CURVED HEADER
          Container(
            height: 300,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF009688),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.remove_red_eye, size: 80, color: Colors.white)
                    .animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                const SizedBox(height: 16),
                Text(
                  "EyeVLM Research",
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  "Early Disease Detection System",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withAlpha(230),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // 📝 2. LOGIN FORM
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildLoginForm(context),
          ),

          const SizedBox(height: 60),
          _buildFooter(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // 💻 WEB LAYOUT (Split View)
  Widget _buildWebLayout(BuildContext context) {
    return Row(
      children: [
        // Left Side: Hero Image / Brand
        Expanded(
          flex: 1,
          child: Container(
            color: const Color(0xFF009688),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.remove_red_eye_rounded, size: 100, color: Colors.white)
                    .animate().scale(duration: 800.ms, curve: Curves.elasticOut),
                const SizedBox(height: 24),
                Text(
                  "EyeVLM",
                  style: GoogleFonts.poppins(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    "Advanced AI-powered early disease detection system for healthier vision.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 16, color: Colors.white.withAlpha(200)),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Right Side: Login Form
        Expanded(
          flex: 1,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Welcome Back", style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text("Please enter your details to sign in.", style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 40),
                    _buildLoginForm(context),
                    const SizedBox(height: 40),
                    Center(child: _buildFooter()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Reusable Form Component
  Widget _buildLoginForm(BuildContext context) {
    return Column(
      children: [
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
              textAlign: TextAlign.center,
            ),
          ).animate().fadeIn(),

        TextFormField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: "Email Address",
            prefixIcon: Icon(Icons.email),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          decoration: InputDecoration(
            labelText: "Password",
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
            ),
          ),
        ),
        
        // Forgot Password Placeholder
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _showResetPasswordDialog(), 
            child: const Text("Forgot Password?", style: TextStyle(color: Colors.grey)),
          ),
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            child: _isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text("Log In Securely"),
          ),
        ),
        
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => context.push('/signup'),
          child: Text(AppStrings.tr(ref, 'msgNoAccount')),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2);
  }

  Widget _buildFooter() {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: GoogleFonts.inter(
          fontSize: 12,
          color: Colors.grey[500],
          height: 1.5, 
        ),
        children: [
          const TextSpan(text: "Designed & Developed by\n"), 
          TextSpan(
            text: "Raisul Maharub",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600), 
          ),
          const TextSpan(text: "\nVersion 1.0.0"),
        ],
      ),
    );
  }

  Future<void> _showResetPasswordDialog() async {
    final resetEmailController = TextEditingController();
    
    return showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Reset Password"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Enter your email address to receive a password reset link."),
              const SizedBox(height: 16),
              TextField(
                controller: resetEmailController,
                decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = resetEmailController.text.trim();
                if (email.isEmpty) return;

                Navigator.pop(dialogContext); // Close dialog
                
                try {
                  await Supabase.instance.client.auth.resetPasswordForEmail(email);
                  if (mounted) {
                     AppNotifications.showSuccess(context, "Check your email for the reset link!");
                  }
                } catch (e) {
                  if (mounted) {
                     AppNotifications.showError(context, "Error: $e");
                  }
                }
              },
              child: const Text("Send Link"),
            ),
          ],
        );
      },
    );
  }
}
