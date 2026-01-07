import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/localization/app_strings.dart';
import '../../core/widgets/responsive_wrapper.dart';
import '../../core/utils/app_notifications.dart';
import '../../core/providers/connectivity_provider.dart';
import '../../core/widgets/connectivity_banner.dart';
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
  String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
        });
      }
    } catch (e) {
      // Keep default version
    }
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    
    // Basic validation
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both email and password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authServiceProvider).signIn(email, password);
      
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        
        // User-friendly error messages
        if (errorMsg.contains('Invalid login credentials')) {
          errorMsg = 'Invalid email or password';
        } else if (errorMsg.contains('SocketException') || 
                   errorMsg.contains('Failed host lookup')) {
          final isOnline = ref.read(isOnlineProvider);
          if (!isOnline) {
            errorMsg = 'You are offline. Please connect to the internet or use previously saved credentials.';
          } else {
            errorMsg = 'Connection error. Please check your internet and try again.';
          }
        } else if (errorMsg.contains('Offline login failed')) {
          errorMsg = 'Offline login failed. Please connect to the internet to verify your credentials.';
        } else {
          errorMsg = 'Login failed. Please try again.';
        }
        
        setState(() {
          _errorMessage = errorMsg;
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

  // 📱 MOBILE LAYOUT
  Widget _buildMobileLayout(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // 🌊 1. CURVED HEADER with centered content
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
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  // Connectivity indicator in top right
                  Positioned(
                    top: 8,
                    right: 16,
                    child: const ConnectivityIndicator(
                      size: 20,
                      showOnlineState: false,
                    ),
                  ),
                  // Centered logo and text
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.remove_red_eye,
                            size: 64,
                            color: Colors.white,
                          ),
                        ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                        const SizedBox(height: 20),
                        Text(
                          "EyeVLM Research",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Early Disease Detection System",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
            child: Stack(
              children: [
                // Connectivity indicator
                Positioned(
                  top: 16,
                  right: 16,
                  child: const ConnectivityIndicator(
                    size: 24,
                    showOnlineState: false,
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.remove_red_eye_rounded,
                          size: 80,
                          color: Colors.white,
                        ),
                      ).animate().scale(duration: 800.ms, curve: Curves.elasticOut),
                      const SizedBox(height: 32),
                      Text(
                        "EyeVLM",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          "Advanced AI-powered early disease detection system for healthier vision.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ],
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
                    Text(
                      "Welcome Back",
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Please enter your details to sign in.",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
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
    final isOnline = ref.watch(isOnlineProvider);
    
    return Column(
      children: [
        // Offline notice
        if (!isOnline)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You are offline. Login with saved credentials.',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(),

        // Error message
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
          ).animate().fadeIn().shake(duration: 300.ms),

        TextFormField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: "Email Address",
            prefixIcon: Icon(Icons.email),
          ),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
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
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onFieldSubmitted: (_) => _handleLogin(),
        ),
        
        // Forgot Password
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: isOnline ? _showResetPasswordDialog : () {
              AppNotifications.showInfo(context, 'Password reset requires an internet connection');
            },
            child: Text(
              "Forgot Password?",
              style: TextStyle(
                color: isOnline ? Colors.grey : Colors.grey.shade400,
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            child: _isLoading 
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(isOnline ? "Log In Securely" : "Log In Offline"),
          ),
        ),
        
        const SizedBox(height: 16),
        TextButton(
          onPressed: isOnline 
              ? () => context.push('/signup')
              : () {
                  AppNotifications.showInfo(context, 'Sign up requires an internet connection');
                },
          child: Text(
            AppStrings.tr(ref, 'msgNoAccount'),
            style: TextStyle(
              color: isOnline ? null : Colors.grey.shade400,
            ),
          ),
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
          TextSpan(text: "\nVersion $_appVersion"),
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
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                ),
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

                Navigator.pop(dialogContext);
                
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
