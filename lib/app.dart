import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/auth/get_started_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/profile_setup/profile_setup_step1_screen.dart';
import 'screens/profile_setup/profile_setup_step2_screen.dart';
import 'screens/home_screen.dart';
import 'screens/notification_screen.dart';
import 'screens/search/search_screen.dart';
import 'screens/swap/swap_screen.dart';
import 'screens/messages/messages_screen.dart';
import 'screens/menu/personal_details_screen.dart';
import 'screens/menu/settings_screen.dart';
import 'screens/menu/help_screen.dart';
import 'screens/menu/availability_screen.dart';
import 'screens/menu/settings/change_password_screen.dart';
import 'screens/menu/settings/about_screen.dart';

class SkillSwapApp extends StatelessWidget {
  const SkillSwapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SkillSwap',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const SplashScreen(),
      routes: {

        // ── Auth ──────────────────────────────────────────────────
        '/onboarding':        (_) => const OnboardingScreen(),
        '/get-started':       (_) => const GetStartedScreen(),
        '/signup':            (_) => const SignupScreen(),
        '/login':             (_) => const LoginScreen(),

        // ── Profile Setup ─────────────────────────────────────────
        '/profile-setup-1':   (_) => const ProfileSetupStep1Screen(),
        '/profile-setup-2':   (_) => const ProfileSetupStep2Screen(),

        // ── Main ──────────────────────────────────────────────────
        '/home':              (_) => const HomeScreen(),
        '/notifications':     (_) => const NotificationScreen(),
        '/search':            (_) => const SearchScreen(),
        '/swap':              (_) => const SwapScreen(),
        '/messages':          (_) => const MessagesScreen(),

        // ── Menu ──────────────────────────────────────────────────
        '/personal-details':  (_) => const PersonalDetailsScreen(),
        '/settings':          (_) => const SettingsScreen(),
        '/settings/password': (_) => const ChangePasswordScreen(),
        '/settings/about':    (_) => const AboutScreen(),
        '/help':              (_) => const HelpScreen(),
        '/availability':      (_) => const AvailabilityScreen(),

        // ── Member 2 screens — placeholders until built ───────────
        '/schedule': (_) => const _PlaceholderScreen(
          label: 'Schedule',
          icon: Icons.calendar_today_outlined,
        ),
        '/my-profile': (_) => const _PlaceholderScreen(
          label: 'My Profile',
          icon: Icons.person_outline_rounded,
        ),
        '/saved-profiles': (_) => const _PlaceholderScreen(
          label: 'Saved Profiles',
          icon: Icons.bookmark_outline_rounded,
        ),

        // ── Member 3 screens — placeholders until built ───────────
        '/community': (_) => const _PlaceholderScreen(
          label: 'Community',
          icon: Icons.groups_outlined,
        ),

      },
    );
  }
}

// ── Placeholder screen ─────────────────────────────────────────────
// Replace each route above with real screen import when Member builds it
class _PlaceholderScreen extends StatelessWidget {
  final String label;
  final IconData icon;

  const _PlaceholderScreen({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: const Color(0xFF9999BB),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Being built by team member',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                color: Color(0xFF9999BB),
              ),
            ),
          ],
        ),
      ),
    );
  }
}