// ignore_for_file: unused_import

import 'package:flutter/material.dart';

// ── Screen Imports ────────────────────────────────────────────
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/notification_screen.dart';

import 'screens/auth/get_started_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/login_screen.dart';

import 'screens/profile_setup/profile_setup_step1_screen.dart';
import 'screens/profile_setup/profile_setup_step2_screen.dart';

import 'screens/menu/hamburger_menu_drawer.dart';
import 'screens/menu/personal_details_screen.dart';
import 'screens/menu/skill_verification_screen.dart';
import 'screens/menu/availability_screen.dart';
import 'screens/menu/settings_screen.dart';
import 'screens/menu/help_screen.dart';
import 'screens/menu/settings/change_password_screen.dart';
import 'screens/menu/settings/about_screen.dart';

import 'screens/search/search_screen.dart';

import 'screens/community/community_screen.dart';
import 'screens/community/create_community_screen.dart';
import 'screens/community/community_detail_screen.dart';
import 'screens/community/admin_actions_screen.dart';
import 'screens/community/create_post_screen.dart';
import 'screens/community/post_detail_screen.dart';

import 'screens/schedule/schedule_screen.dart';
import 'screens/schedule/book_session_screen.dart';

import 'screens/swap/swap_screen.dart';
import 'screens/swap/swap_proposal_sheet.dart';
import 'screens/swap/match_moment_screen.dart';

import 'screens/profile/user_profile_screen.dart';
import 'screens/profile/my_profile_screen.dart';
import 'screens/profile/saved_profiles_screen.dart';

import 'screens/messages/messages_screen.dart';
import 'screens/messages/chat_screen.dart';

import 'screens/video_call/prejoin_screen.dart';
import 'screens/video_call/call_screen.dart';

import 'screens/post_session/session_complete_screen.dart';
import 'screens/post_session/rate_session_screen.dart';

import 'screens/trust_safety/report_block_sheet.dart';

// ── Route Name Constants ───────────────────────────────────────
// Use these constants everywhere instead of typing strings manually
// Example: Navigator.pushNamed(context, AppRoutes.home)

class AppRoutes {
  // Auth
  static const String splash          = '/';
  static const String onboarding      = '/onboarding';
  static const String getStarted      = '/get-started';
  static const String signup          = '/signup';
  static const String login           = '/login';

  // Profile Setup
  static const String profileSetup1   = '/profile-setup-1';
  static const String profileSetup2   = '/profile-setup-2';

  // Main Screens
  static const String home            = '/home';
  static const String notifications   = '/notifications';
  static const String swap            = '/swap';
  static const String messages        = '/messages';
  static const String myProfile       = '/my-profile';
  static const String savedProfiles   = '/saved-profiles';
  static const String search          = '/search';

  // Menu
  static const String personalDetails = '/personal-details';
  static const String skillVerify     = '/skill-verification';
  static const String availability    = '/availability';
  static const String settings        = '/settings';
  static const String changePassword  = '/settings/password';
  static const String about           = '/settings/about';
  static const String help            = '/help';

  // Community
  static const String community       = '/community';
  static const String createCommunity = '/community/create';
  static const String communityDetail = '/community/detail';
  static const String adminActions    = '/community/admin';
  static const String createPost      = '/community/post/create';
  static const String postDetail      = '/community/post/detail';

  // Schedule
  static const String schedule        = '/schedule';
  static const String bookSession     = '/schedule/book';

  // Video Call
  static const String prejoin         = '/call/prejoin';
  static const String call            = '/call/active';

  // Post Session
  static const String sessionComplete = '/session/complete';
  static const String rateSession     = '/session/rate';
}

// ── Route Generator ────────────────────────────────────────────
// This is the single place that maps every route name to a screen.
// Used in app.dart as: onGenerateRoute: AppRouter.generateRoute

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {

      // ── Auth ──────────────────────────────────────────────────
      case AppRoutes.splash:
        return _build(const SplashScreen());

      case AppRoutes.onboarding:
        return _build(const OnboardingScreen());

      case AppRoutes.getStarted:
        return _build(const GetStartedScreen());

      case AppRoutes.signup:
        return _build(const SignupScreen());

      case AppRoutes.login:
        return _build(const LoginScreen());

      // ── Profile Setup ─────────────────────────────────────────
      case AppRoutes.profileSetup1:
        return _build(const ProfileSetupStep1Screen());

      case AppRoutes.profileSetup2:
        return _build(const ProfileSetupStep2Screen());

      // ── Main ──────────────────────────────────────────────────
      case AppRoutes.home:
        return _build(const HomeScreen());

      case AppRoutes.notifications:
        return _build(const NotificationScreen());

      case AppRoutes.swap:
        return _build(const SwapScreen());

      case AppRoutes.messages:
        return _build(const MessagesScreen());

      case AppRoutes.myProfile:
        return _build(const MyProfileScreen());

      case AppRoutes.savedProfiles:
        return _build(const SavedProfilesScreen());

      case AppRoutes.search:
        return _build(const SearchScreen());

      // ── Menu ──────────────────────────────────────────────────
      case AppRoutes.personalDetails:
        return _build(const PersonalDetailsScreen());

      case AppRoutes.availability:
        return _build(const AvailabilityScreen());

      case AppRoutes.settings:
        return _build(const SettingsScreen());

      case AppRoutes.changePassword:
        return _build(const ChangePasswordScreen());

      case AppRoutes.about:
        return _build(const AboutScreen());

      case AppRoutes.help:
        return _build(const HelpScreen());

      // ── Community ─────────────────────────────────────────────
      case AppRoutes.community:
        return _build(const CommunityScreen());

      case AppRoutes.createCommunity:
        return _build(const CreateCommunityScreen());

      // ── Schedule ──────────────────────────────────────────────
      case AppRoutes.schedule:
        return _build(const ScheduleScreen());

      // ── Post Session ──────────────────────────────────────────
      case AppRoutes.sessionComplete:
        return _build(const SessionCompleteScreen());

      // ── Screens that need arguments ───────────────────────────
      // These screens receive data (ids, objects) so they are
      // navigated to using Navigator.push() not pushNamed()
      // Examples shown below for reference:
      //
      // Navigator.push(context, MaterialPageRoute(
      //   builder: (_) => CommunityDetailScreen(communityId: id),
      // ));
      //
      // Navigator.push(context, MaterialPageRoute(
      //   builder: (_) => ChatScreen(swapId: id, otherUser: user),
      // ));
      //
      // Navigator.push(context, MaterialPageRoute(
      //   builder: (_) => UserProfileScreen(userId: id, myTeachingSkills: skills),
      // ));

      // ── Fallback ──────────────────────────────────────────────
      default:
        return _build(
          Scaffold(
            body: Center(
              child: Text(
                'No route found for: ${settings.name}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        );
    }
  }

  // Helper — wraps any widget in a MaterialPageRoute
  static MaterialPageRoute _build(Widget page) {
    return MaterialPageRoute(builder: (_) => page);
  }
}