import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import '../../theme.dart';
import '../../supabase_service.dart';
import '../../widgets/coral_button.dart';
import '../../widgets/loading_spinner.dart';

class ProfileSetupStep1Screen extends StatefulWidget {
  const ProfileSetupStep1Screen({super.key});

  @override
  State<ProfileSetupStep1Screen> createState() =>
      _ProfileSetupStep1ScreenState();
}

class _ProfileSetupStep1ScreenState extends State<ProfileSetupStep1Screen> {
  // ── Controllers ───────────────────────────────────────────────
  final _fullNameController    = TextEditingController();
  final _dobController         = TextEditingController();
  final _institutionController = TextEditingController();

  // ── State ──────────────────────────────────────────────────────
  bool _isLoading      = false;
  Uint8List? _imageBytes;
  String? _occupation  = 'Student';
  String? _passingYear = '2024';
  DateTime? _selectedDob;

  final List<String> _occupations = [
    'Student',
    'Developer',
    'Designer',
    'Researcher',
    'Other',
  ];

  final List<String> _passingYears = [
    '2024', '2025', '2026', '2027', '2028', '2029',
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _dobController.dispose();
    _institutionController.dispose();
    super.dispose();
  }

  // ── Load existing data ─────────────────────────────────────────
  Future<void> _loadExistingData() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      final res = await SupabaseService.client
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      setState(() {
        _fullNameController.text    = res['full_name'] ?? '';
        _institutionController.text = res['institution'] ?? '';
        _occupation  = res['occupation'] ?? 'Student';
        _passingYear = res['passing_year']?.toString() ?? '2024';
      });

      // Load existing date of birth
      final dobStr = res['date_of_birth'] as String?;
      if (dobStr != null && dobStr.isNotEmpty) {
        final parts = dobStr.split('-');
        if (parts.length == 3) {
          setState(() {
            _selectedDob = DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
            _dobController.text =
                '${parts[2].padLeft(2, '0')}/'
                '${parts[1].padLeft(2, '0')}/'
                '${parts[0]}';
          });
        }
      }
    } catch (e) {
      debugPrint('Load existing data error: $e');
    }
  }

  // ── Pick photo ─────────────────────────────────────────────────
  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 800,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() => _imageBytes = bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not pick image. Please try again.'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  // ── Upload photo ───────────────────────────────────────────────
  Future<String?> _uploadPhoto(String userId) async {
    if (_imageBytes == null) return null;
    try {
      final fileName = 'avatar_$userId.jpg';
      await SupabaseService.client.storage
          .from('avatars')
          .uploadBinary(
            fileName,
            _imageBytes!,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      return SupabaseService.client.storage
          .from('avatars')
          .getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Upload photo error: $e');
      return null;
    }
  }

  // ── Pick date ──────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.indigo,
              onPrimary: Colors.white,
              surface: AppColors.cardSurface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobController.text =
            '${picked.day.toString().padLeft(2, '0')}/'
            '${picked.month.toString().padLeft(2, '0')}/'
            '${picked.year}';
      });
    }
  }

  // ── Next step ──────────────────────────────────────────────────
  Future<void> _next() async {
    if (_fullNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your full name'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId    = SupabaseService.currentUserId!;
      final avatarUrl = await _uploadPhoto(userId);

      final updateData = <String, dynamic>{
        'full_name':    _fullNameController.text.trim(),
        'institution':  _institutionController.text.trim(),
        'occupation':   _occupation,
        'passing_year': int.tryParse(_passingYear ?? ''),
      };

      // Only save avatar if uploaded
      if (avatarUrl != null) {
        updateData['avatar_url'] = avatarUrl;
      }

      // Only save date of birth if user picked one
      if (_selectedDob != null) {
        updateData['date_of_birth'] =
            '${_selectedDob!.year}-'
            '${_selectedDob!.month.toString().padLeft(2, '0')}-'
            '${_selectedDob!.day.toString().padLeft(2, '0')}';
      }

      await SupabaseService.client
          .from('users')
          .update(updateData)
          .eq('id', userId);

      if (!mounted) return;
      Navigator.pushNamed(context, '/profile-setup-2');

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.red,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
          'SkillSwap',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.indigo,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: AppColors.elevated,
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.indigo,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Step label ───────────────────────────
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PERSONAL INFO',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: AppColors.indigo,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    'Step 1 of 2',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── Heading ──────────────────────────────
              const Text(
                'Set Up Your Profile',
                style: AppTextStyles.heading1,
              ),

              const SizedBox(height: AppSpacing.xs),

              const Text(
                'Tell us about yourself to find your perfect skill match.',
                style: AppTextStyles.body,
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Avatar picker ────────────────────────
              Center(
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.indigoCoralGradient,
                        ),
                        padding: const EdgeInsets.all(3),
                        child: ClipOval(
                          child: _imageBytes != null
                              ? Image.memory(
                                  _imageBytes!,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: AppColors.cardSurface,
                                  child: const Icon(
                                    Icons.person_outline_rounded,
                                    size: 48,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: AppColors.indigo,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xs),

              const Center(
                child: Text(
                  'UPLOAD PHOTO',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: AppColors.textMuted,
                    letterSpacing: 1.2,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Form fields ──────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [

                    // Full Name
                    _buildFormField(
                      controller: _fullNameController,
                      label: 'Full Name',
                      hint: 'Fahim Chowdhury',
                    ),

                    _buildDivider(),

// Date of Birth — tap calendar icon OR type manually
Padding(
  padding: const EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.sm,
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Date of Birth',
        style: TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: AppColors.textMuted,
        ),
      ),
      const SizedBox(height: 4),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _dobController,
              style: AppTextStyles.bodyBold,
              keyboardType: TextInputType.datetime,
              onChanged: (value) {
                if (value.length == 10) {
                  final parts = value.split('/');
                  if (parts.length == 3) {
                    try {
                      final d = int.parse(parts[0]);
                      final m = int.parse(parts[1]);
                      final y = int.parse(parts[2]);
                      setState(() {
                        _selectedDob = DateTime(y, m, d);
                      });
                    } catch (_) {}
                  }
                }
              },
              decoration: const InputDecoration(
                hintText: 'DD/MM/YYYY',
                hintStyle: TextStyle(
                  color: AppColors.textMuted,
                  fontFamily: 'Nunito',
                  fontSize: 14,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          GestureDetector(
            onTap: _pickDate,
            child: const Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: AppColors.indigo,
            ),
          ),
        ],
      ),
    ],
  ),
),
_buildDivider(),
                    // Occupation
                    _buildDropdownField(
                      label: 'Occupation',
                      value: _occupation,
                      items: _occupations,
                      onChanged: (val) =>
                          setState(() => _occupation = val),
                    ),

                    _buildDivider(),

                    // Institution
                    _buildFormField(
                      controller: _institutionController,
                      label: 'Institution Name',
                      hint: 'Leading University',
                      suffix: const Icon(
                        Icons.school_outlined,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                    ),

                    _buildDivider(),

                    // Passing Year
                    _buildDropdownField(
                      label: 'Passing Year',
                      value: _passingYear,
                      items: _passingYears,
                      onChanged: (val) =>
                          setState(() => _passingYear = val),
                      suffix: const Icon(
                        Icons.check_box_outlined,
                        size: 18,
                        color: AppColors.indigo,
                      ),
                    ),

                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // ── Next button ──────────────────────────
              CoralButton(
                label: 'Next →',
                onTap: _isLoading ? null : _next,
                isLoading: _isLoading,
              ),

              const SizedBox(height: AppSpacing.lg),

            ],
          ),
        ),
      ),
    );
  }

  // ── Form field builder ─────────────────────────────────────────
  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  style: AppTextStyles.bodyBold,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(
                      color: AppColors.textMuted,
                      fontFamily: 'Nunito',
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (suffix != null) suffix,
            ],
          ),
        ],
      ),
    );
  }

  // ── Dropdown field builder ─────────────────────────────────────
  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isDense: true,
                    isExpanded: true,
                    dropdownColor: AppColors.cardSurface,
                    style: AppTextStyles.bodyBold,
                    icon: const SizedBox.shrink(),
                    items: items.map((item) {
                      return DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      );
                    }).toList(),
                    onChanged: onChanged,
                  ),
                ),
              ),
              suffix ??
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Divider ────────────────────────────────────────────────────
  Widget _buildDivider() {
    return const Divider(
      color: AppColors.elevated,
      height: 1,
      indent: AppSpacing.md,
      endIndent: AppSpacing.md,
    );
  }
}