
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../supabase_service.dart';
import '../../widgets/coral_button.dart';
import '../../widgets/loading_spinner.dart';

class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  // ── Days and slots ─────────────────────────────────────────────
  final List<String> _days = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  final List<String> _slots = [
    'Morning', 'Afternoon', 'Evening',
  ];

  // ── State ──────────────────────────────────────────────────────
  // Key format: 'Mon_Morning', 'Tue_Afternoon' etc.
  final Set<String> _selectedSlots = {};
  bool _isAvailableNow = false;
  bool _isLoading      = false;
  bool _isSaving       = false;

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  // ── Load existing availability ─────────────────────────────────
  Future<void> _loadAvailability() async {
    setState(() => _isLoading = true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final res = await SupabaseService.client
          .from('users')
          .select('availability, is_available_now')
          .eq('id', userId)
          .single();

      final availability = res['availability'];
      if (availability != null && availability is Map) {
        setState(() {
          for (final entry in availability.entries) {
            final day   = entry.key as String;
            final slots = entry.value as List;
            for (final slot in slots) {
              _selectedSlots.add('${day}_$slot');
            }
          }
        });
      }

      setState(() => _isAvailableNow = res['is_available_now'] ?? false);

    } catch (e) {
      debugPrint('Load availability error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Toggle a slot ──────────────────────────────────────────────
  void _toggleSlot(String day, String slot) {
    final key = '${day}_$slot';
    setState(() {
      if (_selectedSlots.contains(key)) {
        _selectedSlots.remove(key);
      } else {
        _selectedSlots.add(key);
      }
    });
  }

  // ── Build availability map for Supabase ───────────────────────
  Map<String, List<String>> _buildAvailabilityMap() {
    final map = <String, List<String>>{};
    for (final key in _selectedSlots) {
      final parts = key.split('_');
      final day   = parts[0];
      final slot  = parts[1];
      map.putIfAbsent(day, () => []).add(slot);
    }
    return map;
  }

  // ── Save availability ──────────────────────────────────────────
  Future<void> _saveAvailability() async {
    setState(() => _isSaving = true);
    try {
      final userId = SupabaseService.currentUserId!;
      await SupabaseService.client.from('users').update({
        'availability':     _buildAvailabilityMap(),
        'is_available_now': _isAvailableNow,
      }).eq('id', userId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Availability saved! ✓'),
          backgroundColor: AppColors.green,
        ),
      );
      Navigator.pop(context);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
          backgroundColor: AppColors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Availability',
          style: AppTextStyles.heading2,
        ),
      ),
      body: _isLoading
          ? const LoadingSpinner()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Available now toggle ─────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.elevated),
                    ),
                    child: SwitchListTile(
                      title: const Text(
                        'Available Right Now',
                        style: AppTextStyles.bodyBold,
                      ),
                      subtitle: const Text(
                        'Show others you are online and ready to swap',
                        style: AppTextStyles.caption,
                      ),
                      value: _isAvailableNow,
                      onChanged: (val) =>
                          setState(() => _isAvailableNow = val),
                      activeThumbColor: AppColors.indigo,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  const Text(
                    'Weekly Schedule',
                    style: AppTextStyles.heading3,
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  const Text(
                    'Tap a slot to mark when you are free each week',
                    style: AppTextStyles.body,
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // ── Grid ────────────────────────────────
                  _buildGrid(),

                  const SizedBox(height: AppSpacing.xl),

                  // ── Legend ──────────────────────────────
                  Row(
                    children: [
                      _buildLegendItem(
                        color: AppColors.indigo,
                        label: 'Available',
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      _buildLegendItem(
                        color: AppColors.elevated,
                        label: 'Not Available',
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // ── Save button ──────────────────────────
                  CoralButton(
                    label: 'Save Availability',
                    onTap: _isSaving ? null : _saveAvailability,
                    isLoading: _isSaving,
                  ),

                  const SizedBox(height: AppSpacing.lg),

                ],
              ),
            ),
    );
  }

  // ── Availability grid ──────────────────────────────────────────
  Widget _buildGrid() {
    return Column(
      children: [

        // ── Header row — slot names ──────────────────────
        Row(
          children: [
            const SizedBox(width: 48), // space for day labels
            ..._slots.map((slot) {
              return Expanded(
                child: Center(
                  child: Text(
                    slot,
                    style: AppTextStyles.label,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }),
          ],
        ),

        const SizedBox(height: AppSpacing.sm),

        // ── Day rows ─────────────────────────────────────
        ..._days.map((day) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [

                // Day label
                SizedBox(
                  width: 48,
                  child: Text(
                    day,
                    style: AppTextStyles.label,
                    textAlign: TextAlign.center,
                  ),
                ),

                // Slot cells
                ..._slots.map((slot) {
                  final key       = '${day}_$slot';
                  final isSelected = _selectedSlots.contains(key);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                      ),
                      child: GestureDetector(
                        onTap: () => _toggleSlot(day, slot),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.indigo
                                : AppColors.cardSurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.indigo
                                  : AppColors.elevated,
                              width: 1.5,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 16,
                                )
                              : null,
                        ),
                      ),
                    ),
                  );
                }),

              ],
            ),
          );
        }),

      ],
    );
  }

  // ── Legend item ────────────────────────────────────────────────
  Widget _buildLegendItem({
    required Color color,
    required String label,
  }) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}