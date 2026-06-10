// lib/screens/schedule/schedule_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme.dart';
import '../../models/session_model.dart';
import '../../models/user_model.dart';
import '../../supabase_service.dart';
import '../../widgets/gradient_avatar.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  // ── State ──────────────────────────────────────────────────────
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate  = DateTime.now();

  // All sessions for current user — loaded once
  List<_SessionWithPartner> _allSessions = [];
  bool _isLoading = false;

  // Sessions for the selected date
  List<_SessionWithPartner> get _sessionsForDate => _allSessions
      .where((e) => _isSameDay(e.session.scheduledAt.toLocal(), _selectedDate))
      .toList()
    ..sort((a, b) =>
        a.session.scheduledAt.compareTo(b.session.scheduledAt));

  // Dot color per date — highest priority: upcoming > completed > cancelled
  Color? _dotColorFor(DateTime date) {
    final sessions = _allSessions
        .where((e) => _isSameDay(e.session.scheduledAt.toLocal(), date))
        .toList();
    if (sessions.isEmpty) return null;
    if (sessions.any((e) => e.session.status == 'upcoming')) {
      return AppColors.indigo;
    }
    if (sessions.any((e) => e.session.status == 'completed')) {
      return AppColors.green;
    }
    return AppColors.coral; // cancelled / rejected
  }

  // 30-min upcoming banner
  _SessionWithPartner? get _upcomingBanner {
    final now = DateTime.now();
    try {
      return _allSessions.firstWhere((e) {
        if (e.session.status != 'upcoming') return false;
        final diff = e.session.scheduledAt.toLocal().difference(now);
        return diff.inMinutes >= 0 && diff.inMinutes <= 30;
      });
    } catch (_) {
      return null;
    }
  }

  bool _bannerDismissed = false;

  @override
  void initState() {
    super.initState();
    _fetchSessions();
  }

  // ── Fetch all sessions ─────────────────────────────────────────
  Future<void> _fetchSessions() async {
    setState(() => _isLoading = true);
    try {
      final uid = SupabaseService.currentUserId!;

      final data = await SupabaseService.client
          .from('sessions')
          .select('''
            *,
            host:users!host_id(id, full_name, avatar_url, institution),
            guest:users!guest_id(id, full_name, avatar_url, institution)
          ''')
          .or('host_id.eq.$uid,guest_id.eq.$uid')
          .inFilter('status', ['upcoming', 'completed', 'cancelled'])
          .order('scheduled_at', ascending: true);

      final List<_SessionWithPartner> parsed = [];
      for (final row in data as List) {
        final session   = SessionModel.fromJson(row);
        final isHost    = session.hostId == uid;
        final partnerJson = isHost
            ? row['guest'] as Map<String, dynamic>?
            : row['host']  as Map<String, dynamic>?;
        final partner   = partnerJson != null
            ? UserModel.fromJson(partnerJson)
            : null;
        parsed.add(_SessionWithPartner(session: session, partner: partner));
      }

      if (mounted) {
        setState(() {
          _allSessions    = parsed;
          _isLoading      = false;
          _bannerDismissed = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load schedule: $e')),
        );
      }
    }
  }

  // ── Cancel session ─────────────────────────────────────────────
  Future<void> _cancelSession(_SessionWithPartner item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        title: const Text('Cancel Session',
            style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        content: Text(
          'Cancel "${item.session.topic ?? 'this session'}"?',
          style: const TextStyle(
              fontFamily: 'Nunito', color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Session',
                style: TextStyle(color: AppColors.coral)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await SupabaseService.client
          .from('sessions')
          .update({'status': 'cancelled'})
          .eq('id', item.session.id);

      if (item.partner != null) {
        final meData = await SupabaseService.client
            .from('users')
            .select('full_name')
            .eq('id', SupabaseService.currentUserId!)
            .single();
        final myName = (meData['full_name'] as String?) ?? 'Your partner';

        await SupabaseService.sendNotification(
          userId: item.partner!.id,
          type:   'session_cancelled',
          title:  '$myName cancelled a session',
          body:   item.session.topic != null
              ? '"${item.session.topic}" has been cancelled.'
              : 'A session has been cancelled.',
          data:   {'swap_id': item.session.swapId},
        );
      }

      // Update in place
      final idx = _allSessions.indexWhere(
          (e) => e.session.id == item.session.id);
      if (idx != -1 && mounted) {
        setState(() {
          _allSessions[idx] = _SessionWithPartner(
            session: _updatedStatus(item.session, 'cancelled'),
            partner: item.partner,
          );
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session cancelled.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  SessionModel _updatedStatus(SessionModel s, String status) =>
      SessionModel(
        id:           s.id,
        swapId:       s.swapId,
        hostId:       s.hostId,
        guestId:      s.guestId,
        topic:        s.topic,
        scheduledAt:  s.scheduledAt,
        durationMins: s.durationMins,
        status:       status,
        createdAt:    s.createdAt,
      );

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ── Month/Year picker ──────────────────────────────────────────
  void _pickMonthYear() {
    int tempYear  = _calendarMonth.year;
    int tempMonth = _calendarMonth.month;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          backgroundColor: AppColors.cardSurface,
          title: const Text('Select Month & Year',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              )),
          content: SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Year row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded,
                          color: AppColors.textPrimary),
                      onPressed: () => setD(() => tempYear--),
                    ),
                    Text('$tempYear',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: AppColors.textPrimary,
                        )),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textPrimary),
                      onPressed: () => setD(() => tempYear++),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // Month grid as rows
                ...List.generate(4, (row) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: List.generate(3, (col) {
                      final month     = row * 3 + col + 1;
                      final isSelected = month == tempMonth;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                              right: col < 2 ? AppSpacing.sm : 0),
                          child: GestureDetector(
                            onTap: () => setD(() => tempMonth = month),
                            child: Container(
                              height: 36,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.indigo
                                    : AppColors.elevated,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  DateFormat('MMM')
                                      .format(DateTime(2000, month)),
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() =>
                    _calendarMonth = DateTime(tempYear, tempMonth));
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.indigo,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Go',
                  style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final banner = _upcomingBanner;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('My Schedule', style: AppTextStyles.heading3),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.textMuted, size: 20),
            onPressed: _fetchSessions,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.indigo))
          : RefreshIndicator(
              color: AppColors.indigo,
              onRefresh: _fetchSessions,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── 30-min banner ─────────────────────────
                    if (banner != null && !_bannerDismissed)
                      _buildBanner(banner),

                    // ── Legend ────────────────────────────────
                    const Padding(
                      padding: EdgeInsets.fromLTRB(
                          AppSpacing.md, AppSpacing.sm,
                          AppSpacing.md, 0),
                      child: Row(
                        children: [
                          _LegendDot(
                              color: AppColors.indigo,
                              label: 'Upcoming'),
                          SizedBox(width: AppSpacing.md),
                          _LegendDot(
                              color: AppColors.green,
                              label: 'Completed'),
                          SizedBox(width: AppSpacing.md),
                          _LegendDot(
                              color: AppColors.coral,
                              label: 'Cancelled'),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // ── Full calendar ─────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md),
                      child: _buildCalendar(),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // ── Selected date label ───────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md),
                      child: Text(
                        DateFormat('EEEE, d MMMM').format(_selectedDate),
                        style: AppTextStyles.bodyBold,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // ── Sessions for selected date ─────────────
                    _sessionsForDate.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.lg),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.event_available_outlined,
                                    size: 40,
                                    color: AppColors.textMuted
                                        .withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  const Text('No sessions on this day',
                                      style: AppTextStyles.body),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Book a session from a chat conversation.',
                                    style: AppTextStyles.caption,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md),
                            itemCount: _sessionsForDate.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (_, i) => _SessionCard(
                              item: _sessionsForDate[i],
                              onCancel: () =>
                                  _cancelSession(_sessionsForDate[i]),
                            ),
                          ),

                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Calendar widget ────────────────────────────────────────────
  Widget _buildCalendar() {
    final firstDay =
        DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final lastDay =
        DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0);
    final startOffset = (firstDay.weekday - 1) % 7;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.elevated),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [

          // ── Month/Year header ──────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded,
                    color: AppColors.textPrimary),
                onPressed: () => setState(() {
                  _calendarMonth = DateTime(
                    _calendarMonth.year,
                    _calendarMonth.month - 1,
                  );
                }),
              ),
              GestureDetector(
                onTap: _pickMonthYear,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(_calendarMonth),
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down_rounded,
                        color: AppColors.indigo, size: 20),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textPrimary),
                onPressed: () => setState(() {
                  _calendarMonth = DateTime(
                    _calendarMonth.year,
                    _calendarMonth.month + 1,
                  );
                }),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── Weekday headers ────────────────────────────────
          Row(
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                              color: AppColors.textMuted,
                            )),
                      ),
                    ))
                .toList(),
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── Date grid ──────────────────────────────────────
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: startOffset + lastDay.day,
            itemBuilder: (context, index) {
              if (index < startOffset) return const SizedBox.shrink();

              final day     = index - startOffset + 1;
              final date    = DateTime(_calendarMonth.year,
                  _calendarMonth.month, day);
              final isToday = _isSameDay(date, DateTime.now());
              final isSelected = _isSameDay(date, _selectedDate);
              final dotColor = _dotColorFor(date);

              return GestureDetector(
                onTap: () => setState(() => _selectedDate = date),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.indigo
                        : isToday
                            ? AppColors.indigo.withValues(alpha: 0.15)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday && !isSelected
                        ? Border.all(
                            color: AppColors.indigo.withValues(alpha: 0.5))
                        : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: isSelected || isToday
                              ? FontWeight.w700
                              : FontWeight.w400,
                          fontSize: 13,
                          color: isSelected
                              ? Colors.white
                              : isToday
                                  ? AppColors.indigo
                                  : AppColors.textPrimary,
                        ),
                      ),
                      // Session dot
                      if (dotColor != null)
                        Positioned(
                          bottom: 3,
                          child: Container(
                            width: 5, height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : dotColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── 30-min banner ──────────────────────────────────────────────
  Widget _buildBanner(_SessionWithPartner item) {
    final name  = item.partner?.fullName ?? 'your partner';
    final topic = item.session.topic ?? 'Session';

    return Dismissible(
      key: ValueKey(item.session.id),
      direction: DismissDirection.up,
      onDismissed: (_) => setState(() => _bannerDismissed = true),
      child: Container(
        margin: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.coral.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppColors.coral.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Text('⏰', style: TextStyle(fontSize: 18)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '"$topic" with $name starts in 30 minutes!',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.coral,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _bannerDismissed = true),
              child: const Icon(Icons.close,
                  color: AppColors.coral, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data holder ───────────────────────────────────────────────────
class _SessionWithPartner {
  final SessionModel session;
  final UserModel?   partner;
  const _SessionWithPartner(
      {required this.session, required this.partner});
}

// ── Legend dot ────────────────────────────────────────────────────
class _LegendDot extends StatelessWidget {
  final Color  color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration:
              BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11,
              color: AppColors.textMuted,
            )),
      ],
    );
  }
}

// ── Session card ──────────────────────────────────────────────────
class _SessionCard extends StatelessWidget {
  final _SessionWithPartner item;
  final VoidCallback onCancel;

  const _SessionCard({required this.item, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final session = item.session;
    final partner = item.partner;
    final timeStr = DateFormat('h:mm a')
        .format(session.scheduledAt.toLocal());
    final duration = _durationLabel(session.durationMins);

    // Card accent color based on status
    final Color accentColor;
    switch (session.status) {
      case 'completed':
        accentColor = AppColors.green;
        break;
      case 'cancelled':
        accentColor = AppColors.coral;
        break;
      default:
        accentColor = AppColors.indigo;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: accentColor, width: 3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Avatar
            GradientAvatar(
              imageUrl: partner?.avatarUrl,
              name: partner?.displayName ?? '?',
              size: 44,
            ),

            const SizedBox(width: AppSpacing.md),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.topic ?? 'Skill Session',
                    style: AppTextStyles.bodyBold,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'with ${partner?.fullName ?? 'Unknown'}',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          color: AppColors.indigo, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        '$timeStr · $duration',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _StatusBadge(status: session.status),
                ],
              ),
            ),

            // 3-dot menu — only for upcoming
            if (session.status == 'upcoming')
              PopupMenuButton<String>(
                color: AppColors.elevated,
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppColors.textMuted, size: 20),
                onSelected: (v) {
                  if (v == 'cancel') onCancel();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'cancel',
                    child: Row(
                      children: [
                        Icon(Icons.cancel_outlined,
                            color: AppColors.coral, size: 16),
                        SizedBox(width: 8),
                        Text('Cancel Session',
                            style: TextStyle(
                                fontFamily: 'Nunito',
                                color: AppColors.coral,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _durationLabel(int mins) {
    if (mins < 60) return '$mins min';
    if (mins % 60 == 0) {
      final h = mins ~/ 60;
      return '$h ${h == 1 ? 'hour' : 'hours'}';
    }
    return '${mins ~/ 60}.5 hrs';
  }
}

// ── Status badge ──────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color  color;
    final String label;
    switch (status) {
      case 'completed':
        color = AppColors.green;  label = '✓ Completed'; break;
      case 'cancelled':
        color = AppColors.coral;  label = '✕ Cancelled'; break;
      default:
        color = AppColors.indigo; label = '⏳ Upcoming';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w600,
            fontSize: 11,
            color: color,
          )),
    );
  }
}