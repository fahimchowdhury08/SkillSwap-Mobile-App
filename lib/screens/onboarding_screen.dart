
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../theme.dart';
import '../widgets/coral_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // ── Slide data ─────────────────────────────────────────────────
  final List<_OnboardingSlide> _slides = const [
    _OnboardingSlide(
      icon: Icons.search_rounded,
      title: 'Find Your Skill Match',
      subtitle:
          'We match you with students who have what you want to learn — based on your interests.',
      iconColor: AppColors.indigo,
    ),
    _OnboardingSlide(
      icon: Icons.swap_horiz_rounded,
      title: 'Swap. Don\'t Pay.',
      subtitle:
          'You teach what you know. They teach what you need. Both of you grow — completely free.',
      iconColor: AppColors.coral,
    ),
    _OnboardingSlide(
      icon: Icons.videocam_rounded,
      title: 'Learn Live, Together',
      subtitle:
          'Schedule sessions, video call, share screens — everything you need is inside the app.',
      iconColor: AppColors.green,
    ),
  ];

  // ── Mark onboarding as seen and go to get started ─────────────
  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/get-started');
  }

  // ── Go to next slide or finish ─────────────────────────────────
  void _next() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [

            // ── Skip button ────────────────────────────────────
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            // ── Page view ──────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  return _buildSlide(_slides[index]);
                },
              ),
            ),

            // ── Bottom section ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [

                  // ── Page indicator dots ──────────────────────
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: _slides.length,
                    effect: const ExpandingDotsEffect(
                      activeDotColor: AppColors.indigo,
                      dotColor: AppColors.elevated,
                      dotHeight: 8,
                      dotWidth: 8,
                      expansionFactor: 3,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // ── Next / Get Started button ────────────────
                  CoralButton(
                    label: _currentPage == _slides.length - 1
                        ? 'Get Started →'
                        : 'Next →',
                    onTap: _next,
                  ),

                ],
              ),
            ),

          ],
        ),
      ),
    );
  }

  // ── Single slide builder ───────────────────────────────────────
  Widget _buildSlide(_OnboardingSlide slide) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          // ── Icon circle ──────────────────────────────────────
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: slide.iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: slide.iconColor.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Icon(
              slide.icon,
              size: 70,
              color: slide.iconColor,
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ── Title ────────────────────────────────────────────
          Text(
            slide.title,
            style: AppTextStyles.heading1,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Subtitle ─────────────────────────────────────────
          Text(
            slide.subtitle,
            style: AppTextStyles.body.copyWith(
              fontSize: 16,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),

        ],
      ),
    );
  }
}

// ── Slide data model ───────────────────────────────────────────
class _OnboardingSlide {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;

  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
  });
}