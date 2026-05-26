
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../../theme.dart';
import '../../models/user_model.dart';
import '../../widgets/gradient_avatar.dart';

class MatchMomentScreen extends StatefulWidget {
  final String swapId;
  final UserModel otherUser;

  const MatchMomentScreen({
    super.key,
    required this.swapId,
    required this.otherUser,
  });

  @override
  State<MatchMomentScreen> createState() => _MatchMomentScreenState();
}

class _MatchMomentScreenState extends State<MatchMomentScreen>
    with TickerProviderStateMixin {
  // ── Confetti controller ────────────────────────────────────────
  late ConfettiController _confettiController;

  // ── Animation controllers ──────────────────────────────────────
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupConfetti();
    _setupAnimations();
  }

  void _setupConfetti() {
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    // Start confetti after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _confettiController.play();
    });
  }

  void _setupAnimations() {
    // Scale animation for avatars
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.elasticOut,
      ),
    );

    // Fade animation for text
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeIn,
      ),
    );

    // Start animations
    _scaleController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [

          // ── Confetti top center ────────────────────────
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 30,
              gravity: 0.3,
              colors: const [
                AppColors.indigo,
                AppColors.coral,
                AppColors.green,
                AppColors.gold,
                Colors.white,
              ],
            ),
          ),

          // ── Main content ───────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  const Spacer(),

                  // ── Avatars with glow line ─────────────
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: _buildAvatarRow(),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // ── Match text ─────────────────────────
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [

                        // It's a Match!
                        const Text(
                          "It's a Match! 🎉",
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                            fontSize: 32,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        // Subtitle
                        Text(
                          'You and ${widget.otherUser.displayName} are now matched!',
                          style: AppTextStyles.body.copyWith(
                            fontSize: 16,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        // Message unlocked
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.indigo.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: AppColors.indigo.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_open_rounded,
                                color: AppColors.indigo,
                                size: 16,
                              ),
                              SizedBox(width: AppSpacing.xs),
                              Text(
                                'Chat unlocked!',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.indigo,
                                ),
                              ),
                            ],
                          ),
                        ),

                      ],
                    ),
                  ),

                  const Spacer(),

                  // ── Buttons ────────────────────────────
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [

                        // Start chat button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () {
                              // TODO: replace when chat is built
                              // Navigator.pushReplacement(context,
                              //   MaterialPageRoute(builder: (_) =>
                              //     ChatScreen(swapId: widget.swapId,
                              //       otherUser: widget.otherUser)));
                              Navigator.popUntil(
                                context,
                                (route) => route.isFirst,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Chat coming soon! Go to Messages tab.',
                                  ),
                                  backgroundColor: AppColors.indigo,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.coral,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100),
                              ),
                            ),
                            child: const Text(
                              'Start Chat →',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.md),

                        // Maybe later
                        TextButton(
                          onPressed: () {
                            Navigator.popUntil(
                              context,
                              (route) => route.isFirst,
                            );
                          },
                          child: const Text(
                            'Maybe Later',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),

                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                ],
              ),
            ),
          ),

        ],
      ),
    );
  }

  // ── Avatar row with glow line between ─────────────────────────
  Widget _buildAvatarRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [

        // My avatar (current user)
        _buildGlowAvatar(
          imageUrl: null,
          name: 'Me',
          color: AppColors.indigo,
        ),

        // Glow line between avatars
        Container(
          width: 60,
          height: 3,
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.indigo, AppColors.coral],
            ),
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                color: AppColors.indigo.withValues(alpha: 0.5),
                blurRadius: 8,
              ),
            ],
          ),
        ),

        // Their avatar
        _buildGlowAvatar(
          imageUrl: widget.otherUser.avatarUrl,
          name: widget.otherUser.displayName,
          color: AppColors.coral,
        ),

      ],
    );
  }

  // ── Glowing avatar ─────────────────────────────────────────────
  Widget _buildGlowAvatar({
    required String? imageUrl,
    required String name,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 20,
            spreadRadius: 4,
          ),
        ],
      ),
      child: GradientAvatar(
        imageUrl: imageUrl,
        name: name,
        size: 90,
        borderWidth: 3,
      ),
    );
  }
}