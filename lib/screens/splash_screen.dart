import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../supabase_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {

  // ── Tap counter for hidden seed trigger ───────────────────────
  int _tapCount = 0;

  // ── Animation controller for logo fade in ────────────────────
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _navigate();
  }

  // ── Setup fade animation ───────────────────────────────────────
  void _setupAnimation() {
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeIn,
      ),
    );
    _animController.forward();
  }

  // ── Decide where to navigate after 2 seconds ──────────────────
 Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final user = SupabaseService.currentUser;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final seenOnboarding = prefs.getBool('seen_onboarding') ?? false;
    if (!mounted) return;

    if (user != null) {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (!seenOnboarding) {
      Navigator.pushReplacementNamed(context, '/onboarding');
    } else {
      Navigator.pushReplacementNamed(context, '/get-started');
    }
  }

  void _onLogoTap() {
  _tapCount++;
  if (_tapCount >= 3) {
    _tapCount = 0;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SkillSwap v1.0'),
        backgroundColor: AppColors.indigo,
      ),
    );
  }
}

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              // ── Logo ───────────────────────────────────────
              GestureDetector(
                onTap: _onLogoTap,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: AppColors.indigoCoralGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.indigo.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.swap_horiz_rounded,
                    size: 56,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── App name ───────────────────────────────────
              const Text(
                'SkillSwap',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 36,
                  color: AppColors.textPrimary,
                  letterSpacing: 1.2,
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // ── Tagline ────────────────────────────────────
              const Text(
                'Swap Skills. Grow Together.',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // ── Loading indicator ──────────────────────────
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: AppColors.indigo,
                  strokeWidth: 2.5,
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}