// lib/screens/schedule/book_session_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme.dart';
import '../../supabase_service.dart';

class BookSessionScreen extends StatefulWidget {
  final String swapId;
  final String otherUserId;
  final String otherUserName;
  final String? editingSessionId;
  final Map<String, dynamic>? existingData;

  const BookSessionScreen({
    super.key,
    required this.swapId,
    required this.otherUserId,
    required this.otherUserName,
    this.editingSessionId,
    this.existingData,
  });

  @override
  State<BookSessionScreen> createState() => _BookSessionScreenState();
}

class _BookSessionScreenState extends State<BookSessionScreen> {
  // ── State ──────────────────────────────────────────────────────
  final Set<DateTime> _selectedDates = {};
  String _selectedTime = '09:00'; // always has a value from wheel
  final _topicController = TextEditingController();
  int  _durationMins = 60;
  bool _isSubmitting = false;

  // Calendar navigation
  late DateTime _calendarMonth; // which month is shown

  Set<String> _datesWithBookings = {};

  static const _durations = [
    _Dur(label: '30 min',    mins: 30),
    _Dur(label: '1 hour',    mins: 60),
    _Dur(label: '1.5 hrs',   mins: 90),
    _Dur(label: '2 hours',   mins: 120),
    _Dur(label: '2.5 hrs',   mins: 150),
    _Dur(label: '3 hours',   mins: 180),
    _Dur(label: '3.5 hrs',   mins: 210),
    _Dur(label: '4 hours',   mins: 240),
  ];

  bool get _isEditing => widget.editingSessionId != null;

  @override
  void initState() {
    super.initState();
    _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);

    if (_isEditing && widget.existingData != null) {
      final data = widget.existingData!;
      final scheduledAt =
          DateTime.parse(data['scheduled_at'] as String).toLocal();
      final date =
          DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day);
      _selectedDates.add(date);
      _calendarMonth = DateTime(scheduledAt.year, scheduledAt.month);
      _selectedTime = DateFormat('HH:mm').format(scheduledAt);
      _topicController.text = data['topic'] as String? ?? '';
      _durationMins = data['duration_mins'] as int? ?? 60;
    }

    _fetchBookings();
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _fetchBookings() async {
    try {
      final data = await SupabaseService.client
          .from('sessions')
          .select('scheduled_at')
          .eq('swap_id', widget.swapId)
          .inFilter('status', ['upcoming', 'pending']);

      final Set<String> dates = {};
      for (final row in data as List) {
        final dt = DateTime.parse(row['scheduled_at'] as String).toLocal();
        dates.add(DateFormat('yyyy-MM-dd').format(dt));
      }
      if (mounted) setState(() => _datesWithBookings = dates);
    } catch (e) {
      debugPrint('Booking fetch error: $e');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isSelected(DateTime d) =>
      _selectedDates.any((s) => _isSameDay(s, d));

  bool _isPast(DateTime d) {
    final today = DateTime.now();
    return d.isBefore(DateTime(today.year, today.month, today.day));
  }

  bool _dateHasBooking(DateTime d) =>
      _datesWithBookings.contains(DateFormat('yyyy-MM-dd').format(d));

  String _displayTime(String hhmm) {
    final p = hhmm.split(':');
    return DateFormat('h:mm a').format(
        DateTime(2000, 1, 1, int.parse(p[0]), int.parse(p[1])));
  }

  void _toggleDate(DateTime d) {
    if (_isPast(d)) return;
    setState(() {
      if (_isEditing) {
        _selectedDates.clear();
        _selectedDates.add(d);
      } else {
        final existing = _selectedDates
            .where((s) => _isSameDay(s, d))
            .toList();
        if (existing.isNotEmpty) {
          _selectedDates.remove(existing.first);
        } else {
          _selectedDates.add(d);
        }
      }
    });
  }

  bool get _canBook =>
      _selectedDates.isNotEmpty &&
      _topicController.text.trim().isNotEmpty &&
      !_isSubmitting;

  // ── Submit ─────────────────────────────────────────────────────
  Future<void> _submitProposal() async {
    if (!_canBook) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill all fields'),
            backgroundColor: AppColors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final uid = SupabaseService.currentUserId!;
      final p   = _selectedTime.split(':');
      final topic    = _topicController.text.trim();
      final timeStr  = _displayTime(_selectedTime);
      final durLabel = _durations
          .firstWhere((d) => d.mins == _durationMins,
              orElse: () => const _Dur(label: '1 hour', mins: 60))
          .label;

      if (_isEditing) {
        // Single date for edits
        final date = _selectedDates.first;
        final scheduledAt = DateTime(
          date.year, date.month, date.day,
          int.parse(p[0]), int.parse(p[1]),
        ).toUtc();
        final dateStr = DateFormat('EEE, d MMM').format(date);

        await SupabaseService.client.from('sessions').update({
          'topic':         topic,
          'scheduled_at':  scheduledAt.toIso8601String(),
          'duration_mins': _durationMins,
          'status':        'pending',
        }).eq('id', widget.editingSessionId!);

        await SupabaseService.client.from('messages').insert({
          'swap_id':      widget.swapId,
          'sender_id':    uid,
          'content':      _buildContent(topic, dateStr, timeStr, durLabel),
          'message_type': 'session_proposal',
          'metadata': {
            'session_id':     widget.editingSessionId,
            'topic':          topic,
            'scheduled_at':   scheduledAt.toIso8601String(),
            'duration_mins':  _durationMins,
            'date_display':   dateStr,
            'time_display':   timeStr,
            'duration_label': durLabel,
            'is_update':      true,
          },
          'is_read': false,
        });

        await SupabaseService.sendNotification(
          userId: widget.otherUserId,
          type:   'session_proposed',
          title:  'Session updated: $topic',
          body:   '$dateStr at $timeStr · $durLabel',
          data:   {'swap_id': widget.swapId},
        );

      } else {
        // Create one session per selected date
        final sortedDates = _selectedDates.toList()..sort();

        for (final date in sortedDates) {
          final scheduledAt = DateTime(
            date.year, date.month, date.day,
            int.parse(p[0]), int.parse(p[1]),
          ).toUtc();
          final dateStr = DateFormat('EEE, d MMM').format(date);

          final sessionRes = await SupabaseService.client
              .from('sessions')
              .insert({
                'swap_id':       widget.swapId,
                'host_id':       uid,
                'guest_id':      widget.otherUserId,
                'topic':         topic,
                'scheduled_at':  scheduledAt.toIso8601String(),
                'duration_mins': _durationMins,
                'status':        'pending',
                'proposed_by':   uid,
              })
              .select('id')
              .single();

          final sessionId = sessionRes['id'] as String;

          await SupabaseService.client.from('messages').insert({
            'swap_id':      widget.swapId,
            'sender_id':    uid,
            'content':      _buildContent(topic, dateStr, timeStr, durLabel),
            'message_type': 'session_proposal',
            'metadata': {
              'session_id':     sessionId,
              'topic':          topic,
              'scheduled_at':   scheduledAt.toIso8601String(),
              'duration_mins':  _durationMins,
              'date_display':   dateStr,
              'time_display':   timeStr,
              'duration_label': durLabel,
              'is_update':      false,
            },
            'is_read': false,
          });
        }

        final datesLabel = sortedDates.length == 1
            ? DateFormat('EEE, d MMM').format(sortedDates.first)
            : '${sortedDates.length} dates';

        await SupabaseService.sendNotification(
          userId: widget.otherUserId,
          type:   'session_proposed',
          title:  'New session proposal: $topic',
          body:   '$datesLabel at $timeStr · $durLabel',
          data:   {'swap_id': widget.swapId},
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? 'Proposal updated ✓'
                : _selectedDates.length > 1
                    ? '${_selectedDates.length} proposals sent ✓'
                    : 'Proposal sent ✓'),
            backgroundColor: AppColors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Submit error: $e');
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed: $e'),
              backgroundColor: AppColors.red),
        );
      }
    }
  }

  String _buildContent(
      String topic, String dateStr, String timeStr, String durLabel) =>
      '📅 Session Proposal\n$topic\n$dateStr at $timeStr · $durLabel';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Edit Session Proposal' : 'Book a Session',
          style: AppTextStyles.heading3,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // With label
              Center(
                child: Text('with ${widget.otherUserName}',
                    style: AppTextStyles.body),
              ),

              if (_isEditing) ...[
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                          color: AppColors.orange.withValues(alpha: 0.4)),
                    ),
                    child: const Text('✏️ Editing existing proposal',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: AppColors.orange,
                        )),
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.xl),

              // ── Step 1 — Topic ──────────────────────────────
              const _StepLabel(step: '1', label: 'What will you teach?'),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _topicController,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                    fontFamily: 'Nunito', color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'e.g. "Python Basics - Variables & Loops"',
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Step 2 — Calendar ───────────────────────────
              _StepLabel(
                step: '2',
                label: _isEditing
                    ? 'Pick a Date'
                    : 'Pick Date(s)',
              ),
              if (!_isEditing) ...[
                const SizedBox(height: 4),
                const Text(
                  'Tap to select · Tap again to deselect · Pick multiple',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              _buildCalendar(),

              // Selected dates summary
              if (_selectedDates.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                _buildSelectedDatesSummary(),
              ],

              const SizedBox(height: AppSpacing.xl),

              // ── Step 3 — Time (wheel picker) ───────────────
              const _StepLabel(step: '3', label: 'Set Time'),
              const SizedBox(height: 4),
              const Text(
                'Scroll to set hour, minutes and AM/PM',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _WheelTimePicker(
                initialTime: _selectedTime,
                onTimeChanged: (hhmm) {
                  setState(() => _selectedTime = hhmm);
                },
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Step 4 — Duration ───────────────────────────
              const _StepLabel(step: '4', label: 'Session Duration'),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _durations.map((opt) {
                  final selected = _durationMins == opt.mins;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _durationMins = opt.mins),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.indigo
                            : AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? AppColors.indigo
                              : AppColors.elevated,
                        ),
                      ),
                      child: Text(opt.label,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 13,
                            color: selected
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          )),
                    ),
                  );
                }).toList(),
              ),

              // ── Summary preview ─────────────────────────────
              if (_selectedDates.isNotEmpty &&
                  _topicController.text.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                _SummaryCard(
                  selectedDates: _selectedDates.toList()..sort(),
                  time:          _selectedTime,
                  topic:         _topicController.text.trim(),
                  durationMins:  _durationMins,
                  partnerName:   widget.otherUserName,
                  displayTime:   _displayTime,
                  isEditing:     _isEditing,
                ),
              ],

              const SizedBox(height: AppSpacing.xl),

              // ── Submit button ───────────────────────────────
              _isSubmitting
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.coral))
                  : SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _canBook ? _submitProposal : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.coral,
                          disabledBackgroundColor: AppColors.elevated,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        child: Text(
                          _isEditing
                              ? '📤 Send Updated Proposal'
                              : _selectedDates.length > 1
                                  ? '📤 Send ${_selectedDates.length} Proposals to ${widget.otherUserName}'
                                  : '📤 Send Proposal to ${widget.otherUserName}',
                          style: AppTextStyles.button,
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

  // ── Full calendar widget ───────────────────────────────────────
  Widget _buildCalendar() {
    final firstDay =
        DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final lastDay =
        DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0);

    // Weekday of first day (Mon=1 … Sun=7) → offset for grid
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

          // ── Month / Year header with nav arrows ────────────
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

          // ── Day-of-week headers ─────────────────────────────
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

          // ── Date grid ───────────────────────────────────────
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
              if (index < startOffset) {
                return const SizedBox.shrink();
              }
              final day = index - startOffset + 1;
              final date = DateTime(
                  _calendarMonth.year, _calendarMonth.month, day);
              final isPast    = _isPast(date);
              final isToday   = _isSameDay(date, DateTime.now());
              final selected  = _isSelected(date);
              final hasBooking = _dateHasBooking(date);

              return GestureDetector(
                onTap: isPast ? null : () => _toggleDate(date),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.indigo
                        : isToday
                            ? AppColors.indigo.withValues(alpha: 0.15)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday && !selected
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
                          fontWeight: selected || isToday
                              ? FontWeight.w700
                              : FontWeight.w400,
                          fontSize: 13,
                          color: isPast
                              ? AppColors.textMuted
                                  .withValues(alpha: 0.3)
                              : selected
                                  ? Colors.white
                                  : isToday
                                      ? AppColors.indigo
                                      : AppColors.textPrimary,
                        ),
                      ),
                      // Dot for dates with existing bookings
                      if (hasBooking && !selected)
                        Positioned(
                          bottom: 3,
                          child: Container(
                            width: 4, height: 4,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.coral,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

          // ── Legend ──────────────────────────────────────────
          const SizedBox(height: AppSpacing.sm),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: AppColors.indigo, label: 'Selected'),
              SizedBox(width: AppSpacing.md),
              _LegendDot(color: AppColors.coral, label: 'Has booking'),
            ],
          ),
        ],
      ),
    );
  }

  // ── Month/Year picker dialog ───────────────────────────────────
  void _pickMonthYear() {
    int tempYear  = _calendarMonth.year;
    int tempMonth = _calendarMonth.month;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
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
                // Year picker row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded,
                          color: AppColors.textPrimary),
                      onPressed: () =>
                          setStateDialog(() => tempYear--),
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
                      onPressed: () =>
                          setStateDialog(() => tempYear++),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // Month grid — built as Column of Rows (no GridView inside dialog)
                ...List.generate(4, (rowIndex) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: List.generate(3, (colIndex) {
                        final month = rowIndex * 3 + colIndex + 1;
                        final isSelected = month == tempMonth;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: colIndex < 2 ? AppSpacing.sm : 0,
                            ),
                            child: GestureDetector(
                              onTap: () =>
                                  setStateDialog(() => tempMonth = month),
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
                  );
                }),
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
                setState(() {
                  _calendarMonth =
                      DateTime(tempYear, tempMonth);
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.indigo,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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

  // ── Selected dates summary chips ───────────────────────────────
  Widget _buildSelectedDatesSummary() {
    final sorted = _selectedDates.toList()..sort();
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: sorted.map((date) {
        return Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.indigo.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
                color: AppColors.indigo.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat('EEE d MMM').format(date),
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppColors.indigo,
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _toggleDate(date),
                child: const Icon(Icons.close_rounded,
                    size: 13, color: AppColors.indigo),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Legend dot ────────────────────────────────────────────────────
class _LegendDot extends StatelessWidget {
  final Color  color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 10,
              color: AppColors.textMuted,
            )),
      ],
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final List<DateTime> selectedDates;
  final String   time;
  final String   topic;
  final int      durationMins;
  final String   partnerName;
  final String Function(String) displayTime;
  final bool     isEditing;

  const _SummaryCard({
    required this.selectedDates,
    required this.time,
    required this.topic,
    required this.durationMins,
    required this.partnerName,
    required this.displayTime,
    required this.isEditing,
  });

  @override
  Widget build(BuildContext context) {
    final durLabel = durationMins == 30
        ? '30 min'
        : durationMins % 60 == 0
            ? '${durationMins ~/ 60} ${durationMins == 60 ? 'hour' : 'hours'}'
            : '${durationMins ~/ 60}.5 hrs';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.indigo.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.indigo.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEditing
                ? '📋 Updated Proposal Preview'
                : selectedDates.length > 1
                    ? '📋 ${selectedDates.length} Proposals Preview'
                    : '📋 Proposal Preview',
            style: AppTextStyles.body.copyWith(
              color: AppColors.indigo,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _Row(icon: Icons.lightbulb_outline, text: topic),
          _Row(icon: Icons.person_outline,    text: 'with $partnerName'),
          // Show all dates
          ...selectedDates.map((d) => _Row(
                icon: Icons.calendar_today_outlined,
                text: DateFormat('EEE, d MMMM').format(d),
              )),
          _Row(
              icon: Icons.access_time_rounded,
              text: '${displayTime(time)} · $durLabel'),
          const SizedBox(height: AppSpacing.sm),
          Text(
            selectedDates.length > 1
                ? 'Each date will be sent as a separate proposal.'
                : 'This will be sent as a proposal. Your partner must accept it.',
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String   text;
  const _Row({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.indigo, size: 14),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text,
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

// ── Data ──────────────────────────────────────────────────────────
class _Dur {
  final String label;
  final int    mins;
  const _Dur({required this.label, required this.mins});
}

class _StepLabel extends StatelessWidget {
  final String step;
  final String label;
  const _StepLabel({required this.step, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24, height: 24,
          decoration: const BoxDecoration(
              shape: BoxShape.circle, color: AppColors.indigo),
          child: Center(
            child: Text(step,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: Colors.white,
                )),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: AppTextStyles.heading3),
      ],
    );
  }
}

// ── Scroll-wheel time picker ──────────────────────────────────────
class _WheelTimePicker extends StatefulWidget {
  final void Function(String hhmm) onTimeChanged;
  final String? initialTime;

  const _WheelTimePicker({
    required this.onTimeChanged,
    this.initialTime,
  });

  @override
  State<_WheelTimePicker> createState() => _WheelTimePickerState();
}

class _WheelTimePickerState extends State<_WheelTimePicker> {
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late FixedExtentScrollController _amPmController;

  late int _selectedHour;    // 1–12
  late int _selectedMinute;  // index into _minuteOptions
  late int _selectedAmPm;    // 0=AM, 1=PM

  static final _minuteOptions = List.generate(60, (i) => i.toString().padLeft(2, '0'));
  static const _hours = [1,2,3,4,5,6,7,8,9,10,11,12];

  @override
  void initState() {
    super.initState();
    if (widget.initialTime != null) {
      final parts = widget.initialTime!.split(':');
      final h24   = int.parse(parts[0]);
      final m     = int.parse(parts[1]);
      _selectedAmPm  = h24 >= 12 ? 1 : 0;
      _selectedHour  = h24 % 12 == 0 ? 12 : h24 % 12;
      _selectedMinute = m; // direct index 0-59
    } else {
      _selectedHour   = 9;
      _selectedMinute = 0; // "00"
      _selectedAmPm   = 0; // AM
    }

    _hourController   = FixedExtentScrollController(
        initialItem: _hours.indexOf(_selectedHour));
    _minuteController = FixedExtentScrollController(
        initialItem: _selectedMinute);
    _amPmController   = FixedExtentScrollController(
        initialItem: _selectedAmPm);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _amPmController.dispose();
    super.dispose();
  }

  void _notify() {
    int h24 = _selectedHour % 12;
    if (_selectedAmPm == 1) h24 += 12;
    final hStr = h24.toString().padLeft(2, '0');
    final mStr = _minuteOptions[_selectedMinute];
    widget.onTimeChanged('$hStr:$mStr');
  }

  Widget _buildWheel({
    required FixedExtentScrollController controller,
    required List<String> items,
    required void Function(int) onSelected,
    double width = 64,
  }) {
    return SizedBox(
      width: width,
      height: 160,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 48,
        perspective: 0.003,
        diameterRatio: 1.4,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (index) {
          onSelected(index);
          _notify();
        },
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: items.length,
          builder: (context, index) {
            final isSelected =
                controller.hasClients && controller.selectedItem == index;
            return Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 120),
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w400,
                  fontSize: isSelected ? 22 : 16,
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                ),
                child: Text(items[index]),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.elevated),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Selection highlight behind wheels
          Container(
            height: 48,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.indigo.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.indigo.withValues(alpha: 0.35)),
            ),
          ),
          // Wheels
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Hour
              _buildWheel(
                controller: _hourController,
                items: _hours.map((h) => '$h').toList(),
                onSelected: (i) =>
                    setState(() => _selectedHour = _hours[i]),
                width: 56,
              ),
              const Text(':',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                    color: AppColors.textPrimary,
                  )),
              // Minute
              _buildWheel(
                controller: _minuteController,
                items: _minuteOptions,
                onSelected: (i) =>
                    setState(() => _selectedMinute = i),
                width: 56,
              ),
              const SizedBox(width: AppSpacing.md),
              // AM/PM
              _buildWheel(
                controller: _amPmController,
                items: const ['AM', 'PM'],
                onSelected: (i) =>
                    setState(() => _selectedAmPm = i),
                width: 52,
              ),
            ],
          ),
        ],
      ),
    );
  }
}