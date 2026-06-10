
// lib/screens/post_session/session_complete_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme.dart';
import '../../models/user_model.dart';
import '../../models/session_model.dart';
import '../../supabase_service.dart';
import '../../widgets/gradient_avatar.dart';
import 'rate_session_screen.dart';
import '../schedule/book_session_screen.dart';

class SessionCompleteScreen extends StatefulWidget {
  final String? sessionId;
  final UserModel otherUser;
  final String swapId;

  const SessionCompleteScreen({
    super.key,
    this.sessionId,
    required this.otherUser,
    required this.swapId,
  });

  @override
  State<SessionCompleteScreen> createState() => _SessionCompleteScreenState();
}

class _SessionCompleteScreenState extends State<SessionCompleteScreen> {
  SessionModel? _session;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.sessionId != null) _fetchSession();
  }

  Future<void> _fetchSession() async {
    setState(() => _isLoading = true);
    try {
      final data = await SupabaseService.client
          .from('sessions')
          .select()
          .eq('id', widget.sessionId!)
          .single();
      if (mounted) {
        setState(() {
          _session = SessionModel.fromJson(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load session details: $e')),
        );
      }
    }
  }

  String _formatDuration(int mins) {
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.indigo),
                )
              : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: AppSpacing.lg),

          // ── Checkmark icon ──────────────────────────────────
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.indigo.withValues(alpha: 0.15),
              border: Border.all(color: AppColors.indigo, width: 2),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.indigo,
              size: 44,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          const Text(
            'Session Complete!',
            style: AppTextStyles.heading1,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.sm),

          const Text(
            'Great work — keep swapping and growing 🚀',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Recap card ──────────────────────────────────────
          _session != null
              ? _buildFullRecapCard()
              : _buildSimpleRecapCard(),

          const SizedBox(height: AppSpacing.xl),

          // ── Rate button ─────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RateSessionScreen(
                    sessionId: widget.sessionId,
                    reviewedUser: widget.otherUser,
                    swapId: widget.swapId,
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.coral,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              child: const Text(
                'Rate this Session ⭐',
                style: AppTextStyles.button,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── Book next session button ─────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BookSessionScreen(
                    swapId: widget.swapId,
                    otherUserId: widget.otherUser.id,
                    otherUserName:
                        widget.otherUser.fullName ?? 'your partner',
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.indigo,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              child: const Text(
                'Book Next Session →',
                style: AppTextStyles.button,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── Skip ────────────────────────────────────────────
          TextButton(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              '/messages',
              (route) => route.isFirst,
            ),
            child: const Text(
              'Skip',
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
    );
  }

  Widget _buildFullRecapCard() {
    final session = _session!;
    final formattedDate =
        DateFormat('EEE, d MMM · h:mm a').format(session.scheduledAt.toLocal());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.indigo.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Partner row
          Row(
            children: [
              GradientAvatar(imageUrl: widget.otherUser.avatarUrl),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.otherUser.fullName ?? 'Unknown',
                      style: AppTextStyles.heading3,
                    ),
                    if (widget.otherUser.institution != null)
                      Text(
                        widget.otherUser.institution!,
                        style: AppTextStyles.caption,
                      ),
                  ],
                ),
              ),
              // Rating badge
              if (widget.otherUser.avgRating > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          color: AppColors.gold, size: 14),
                      const SizedBox(width: 2),
                      Text(
                        widget.otherUser.avgRating.toStringAsFixed(1),
                        style: AppTextStyles.label.copyWith(
                            color: AppColors.gold),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),
          const Divider(color: AppColors.elevated, height: 1),
          const SizedBox(height: AppSpacing.md),

          if (session.topic != null)
            _RecapRow(
              icon: Icons.lightbulb_outline,
              label: 'Topic',
              value: session.topic!,
            ),
          _RecapRow(
            icon: Icons.access_time_rounded,
            label: 'Duration',
            value: _formatDuration(session.durationMins),
          ),
          _RecapRow(
            icon: Icons.calendar_today_outlined,
            label: 'Date & Time',
            value: formattedDate,
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleRecapCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.indigo.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          GradientAvatar(imageUrl: widget.otherUser.avatarUrl),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Great call with',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 4),
          Text(
            widget.otherUser.fullName ?? 'your partner',
            style: AppTextStyles.heading2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            '🤝 Keep swapping to grow together!',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Recap row helper ──────────────────────────────────────────────────────────

class _RecapRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _RecapRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.indigo, size: 16),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$label: ',
            style: AppTextStyles.label,
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body,
            ),
          ),
        ],
      ),
    );
  }
}