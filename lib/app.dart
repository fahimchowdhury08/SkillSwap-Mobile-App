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
import 'screens/community/community_screen.dart';
import 'screens/schedule/schedule_screen.dart';
import 'screens/profile/my_profile_screen.dart';
import 'screens/profile/saved_profiles_screen.dart';


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

        // ── Schedule ──────────────────────────────────────────────
        '/schedule':          (_) => const ScheduleScreen(),

        // ── Profile ───────────────────────────────────────────────
        '/my-profile':        (_) => const MyProfileScreen(),
        '/saved-profiles':    (_) => const SavedProfilesScreen(),

        // ── Community ─────────────────────────────────────────────
        '/community':         (_) => const CommunityScreen(),

      },
    );
  }
}