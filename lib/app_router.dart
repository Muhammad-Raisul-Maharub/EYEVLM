import 'package:go_router/go_router.dart';
import 'features/auth/login_screen.dart';
import 'features/submission/scan_result_screen.dart';
import 'features/scan/presentation/scan_flow_screen.dart';
import 'features/home/home_screen.dart';
import 'features/history/history_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/profile/settings_screen.dart';
import 'features/profile/help_support_screen.dart';
import 'features/profile/ethical_reasoning_screen.dart';
import 'features/profile/privacy_security_screen.dart';
import 'features/navigation/scaffold_with_nav_bar.dart';
import 'features/admin/admin_dashboard_screen.dart';

import 'features/onboarding/splash_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/auth/signup_screen.dart';

final router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignUpScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    // ShellRoute for Bottom Navigation
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ScaffoldWithNavBar(navigationShell: navigationShell);
      },
      branches: [
        // Tab 1: Home
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const HomeScreen(),
              routes: [
                GoRoute(
                  path: 'scan',
                  builder: (context, state) => const ScanFlowScreen(),
                ),
                GoRoute(
                  path: 'result',
                  builder: (context, state) {
                     final result = state.extra as Map<String, dynamic>;
                     return ScanResultScreen(result: result);
                  },
                ),
              ],
            ),
          ],
        ),
        // Tab 2: History
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/history',
              builder: (context, state) => const HistoryScreen(),

            ),
          ],
        ),
        // Tab 3: Admin (conditional visibility in nav bar)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/admin',
              builder: (context, state) => const AdminDashboardScreen(),
            ),
          ],
        ),
        // Tab 4: Profile
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'settings',
                  builder: (context, state) => const SettingsScreen(),
                ),
                GoRoute(
                  path: 'help',
                  builder: (context, state) => const HelpSupportScreen(),
                ),
                GoRoute(
                  path: 'ethics',
                  builder: (context, state) => const EthicalReasoningScreen(),
                ),
                GoRoute(
                  path: 'privacy',
                  builder: (context, state) => const PrivacySecurityScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
