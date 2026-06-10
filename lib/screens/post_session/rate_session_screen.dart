// lib/screens/post_session/rate_session_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../../theme.dart';
import '../../models/user_model.dart';
import '../../supabase_service.dart';
import '../../widgets/gradient_avatar.dart';

class RateSessionScreen extends StatefulWidget {
  final String? sessionId;
  final UserModel reviewedUser;
  final String swapId;

  const RateSessionScreen({
    super.key,
    this.sessionId,
    required this.reviewedUser,
    required this.swapId,
  });

  @override
  State<RateSessionScreen> createState() => _RateSessionScreenState();
}

class _RateSessionScreenState extends State<RateSessionScreen> {
  double _rating = 0;
  final Set<String> _selectedTags = {};
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  static const _tags = [
    'Great teacher',
    'Very patient',
    'Well prepared',
    'Hard to follow',
    'Was late',
  ];

  static const _ratingLabels = {
    1: 'Not helpful',
    2: 'Could be better',
    3: 'It was okay',
    4: 'Pretty good!',
    5: 'Amazing session!',
  };

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String get _ratingLabel {
    if (_rating == 0) return 'Tap to rate';
    return _ratingLabels[_rating.toInt()] ?? '';
  }

  Color get _ratingColor {
    if (_rating == 0) return AppColors.textMuted;
    if (_rating <= 2) return AppColors.coral;
    if (_rating == 3) return AppColors.gold;
    return AppColors.green;
  }

  Future<void> _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating first.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final currentUserId = SupabaseService.currentUserId!;

      await SupabaseService.client.from('reviews').insert({
        'session_id': widget.sessionId,
        'swap_id': widget.swapId,
        'reviewer_id': currentUserId,
        'reviewed_id': widget.reviewedUser.id,
        'rating': _rating.toInt(),
        'tags': _selectedTags.toList(),
        'comment': _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      });

      // Recalculate avg_rating for the reviewed user
      final result = await SupabaseService.client
          .from('reviews')
          .select('rating')
          .eq('reviewed_id', widget.reviewedUser.id);

      if ((result as List).isNotEmpty) {
        final ratings =
            result.map((r) => (r['rating'] as num).toDouble()).toList();
        final avg = ratings.reduce((a, b) => a + b) / ratings.length;
        await SupabaseService.client
            .from('users')
            .update(
                {'avg_rating': double.parse(avg.toStringAsFixed(2))})
            .eq('id', widget.reviewedUser.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted! Thank you ⭐')),
        );
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/messages',
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit review: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Rate Session', style: AppTextStyles.heading3),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Partner info ──────────────────────────────────
              GradientAvatar(imageUrl: widget.reviewedUser.avatarUrl),
              const SizedBox(height: AppSpacing.sm),
              const Text('How was your session with',
                  style: AppTextStyles.body),
              const SizedBox(height: 4),
              Text(
                widget.reviewedUser.fullName ?? 'your partner',
                style: AppTextStyles.heading2,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Star rating ───────────────────────────────────
              RatingBar.builder(
                initialRating: _rating,
                minRating: 1,
                maxRating: 5,
                itemCount: 5,
                allowHalfRating: false,
                unratedColor: AppColors.elevated,
                itemPadding:
                    const EdgeInsets.symmetric(horizontal: 6),
                itemBuilder: (_, __) => const Icon(
                  Icons.star_rounded,
                  color: AppColors.gold,
                ),
                onRatingUpdate: (value) =>
                    setState(() => _rating = value),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Dynamic label
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _ratingLabel,
                  key: ValueKey(_ratingLabel),
                  style: AppTextStyles.heading3.copyWith(
                    color: _ratingColor,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Tag chips ─────────────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'What stood out?',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _tags.map((tag) {
                  final selected = _selectedTags.contains(tag);
                  final isNegative =
                      tag == 'Hard to follow' || tag == 'Was late';
                  final activeColor =
                      isNegative ? AppColors.coral : AppColors.indigo;

                  return GestureDetector(
                    onTap: () => setState(() {
                      selected
                          ? _selectedTags.remove(tag)
                          : _selectedTags.add(tag);
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? activeColor.withValues(alpha: 0.18)
                            : AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? activeColor
                              : AppColors.elevated,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        tag,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 13,
                          color: selected
                              ? activeColor
                              : AppColors.textSecondary,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Written review ────────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Write a review (optional)',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              TextField(
                controller: _commentController,
                maxLines: 4,
                maxLength: 300,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText:
                      'Share your experience — what did you learn? What could be better?',
                  counterStyle: AppTextStyles.caption,
                  // uses theme InputDecorationTheme for fill + border
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Submit button ─────────────────────────────────
              _isSubmitting
                  ? const CircularProgressIndicator(
                      color: AppColors.coral)
                  : SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _submitReview,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.coral,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        child: const Text(
                          'Submit Review',
                          style: AppTextStyles.button,
                        ),
                      ),
                    ),

              const SizedBox(height: AppSpacing.md),

              TextButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/messages',
                  (route) => route.isFirst,
                ),
                child: const Text(
                  'Skip for now',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    color: AppColors.textMuted,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.textMuted,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}