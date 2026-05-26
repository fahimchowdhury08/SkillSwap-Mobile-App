
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../theme.dart';
import '../../supabase_service.dart';
import '../../widgets/coral_button.dart';
import '../../widgets/loading_spinner.dart';
import '../../widgets/gradient_avatar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileSetupStep2Screen extends StatefulWidget {
  const ProfileSetupStep2Screen({super.key});

  @override
  State<ProfileSetupStep2Screen> createState() =>
      _ProfileSetupStep2ScreenState();
}

class _ProfileSetupStep2ScreenState extends State<ProfileSetupStep2Screen> {
  // ── Controllers ───────────────────────────────────────────────
  final _fullNameController    = TextEditingController();
  final _institutionController = TextEditingController();
  final _occupationController  = TextEditingController();
  final _phoneController       = TextEditingController();
  final _linkedinController    = TextEditingController();

  // ── State ──────────────────────────────────────────────────────
  bool _isLoading       = false;
  bool _isSaving        = false;
  String? _avatarUrl;
  String? _selectedYear;
  File? _selectedAvatar;

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
    _institutionController.dispose();
    _occupationController.dispose();
    _phoneController.dispose();
    _linkedinController.dispose();
    super.dispose();
  }

  // ── Load existing profile data ─────────────────────────────────
  Future<void> _loadExistingData() async {
    setState(() => _isLoading = true);
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
        _occupationController.text  = res['occupation'] ?? '';
        _phoneController.text       = res['phone'] ?? '';
        _linkedinController.text    = res['linkedin_url'] ?? '';
        _avatarUrl                  = res['avatar_url'];
        _selectedYear               = res['passing_year']?.toString();
      });
    } catch (e) {
      debugPrint('Load profile error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Pick profile photo ─────────────────────────────────────────
  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 800,
      );
      if (picked == null) return;
      setState(() => _selectedAvatar = File(picked.path));
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

  // ── Upload avatar to Supabase Storage ─────────────────────────
  Future<String?> _uploadAvatar(String userId) async {
    if (_selectedAvatar == null) return _avatarUrl;
    try {
      final fileName = 'avatar_$userId.jpg';
      final bytes    = await _selectedAvatar!.readAsBytes();

      await SupabaseService.client.storage
          .from('avatars')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );

      final url = SupabaseService.client.storage
          .from('avatars')
          .getPublicUrl(fileName);

      return url;
    } catch (e) {
      debugPrint('Avatar upload error: $e');
      return _avatarUrl;
    }
  }

  // ── Save profile ───────────────────────────────────────────────
  Future<void> _saveProfile() async {
    if (_fullNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your full name'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userId = SupabaseService.currentUserId!;

      // Upload avatar if selected
      final avatarUrl = await _uploadAvatar(userId);

      // Save to users table
      await SupabaseService.client.from('users').update({
        'full_name':    _fullNameController.text.trim(),
        'institution':  _institutionController.text.trim(),
        'occupation':   _occupationController.text.trim(),
        'phone':        _phoneController.text.trim(),
        'linkedin_url': _linkedinController.text.trim(),
        'passing_year': _selectedYear != null
            ? int.tryParse(_selectedYear!)
            : null,
        'avatar_url':   avatarUrl,
      }).eq('id', userId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved! ✓'),
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
          'Complete Profile',
          style: AppTextStyles.heading2,
        ),
      ),
      body: _isLoading
          ? const LoadingSpinner()
          : LoadingOverlay(
              isLoading: _isSaving,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Progress ──────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.indigo,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.indigo,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    const Text('Step 2 of 2', style: AppTextStyles.label),

                    const SizedBox(height: AppSpacing.xl),

                    const Text(
                      'Tell us about yourself',
                      style: AppTextStyles.heading1,
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    const Text(
                      'This helps others know who you are',
                      style: AppTextStyles.body,
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ── Avatar ────────────────────────────
                    Center(child: _buildAvatarPicker()),

                    const SizedBox(height: AppSpacing.xl),

                    // ── Full name ─────────────────────────
                    _buildField(
                      controller: _fullNameController,
                      label: 'Full Name',
                      icon: Icons.person_outline_rounded,
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // ── Occupation ────────────────────────
                    _buildField(
                      controller: _occupationController,
                      label: 'Occupation (e.g. Student, Developer)',
                      icon: Icons.work_outline_rounded,
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // ── Institution ───────────────────────
                    _buildField(
                      controller: _institutionController,
                      label: 'Institution / University',
                      icon: Icons.school_outlined,
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // ── Passing year ──────────────────────
                    _buildYearDropdown(),

                    const SizedBox(height: AppSpacing.md),

                    // ── Phone ─────────────────────────────
                    _buildField(
                      controller: _phoneController,
                      label: 'Phone Number (optional)',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // ── LinkedIn ──────────────────────────
                    _buildField(
                      controller: _linkedinController,
                      label: 'LinkedIn URL (optional)',
                      icon: Icons.link_rounded,
                      keyboardType: TextInputType.url,
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    // ── Save button ───────────────────────
                    CoralButton(
                      label: 'Save Profile',
                      onTap: _isSaving ? null : _saveProfile,
                      isLoading: _isSaving,
                    ),

                    const SizedBox(height: AppSpacing.lg),

                  ],
                ),
              ),
            ),
    );
  }

  // ── Avatar picker ──────────────────────────────────────────────
  Widget _buildAvatarPicker() {
    return GestureDetector(
      onTap: _pickAvatar,
      child: Stack(
        children: [
          _selectedAvatar != null
              ? Container(
                  width: 90,
                  height: 90,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.indigoCoralGradient,),
                  padding: const EdgeInsets.all(2.5),
                  child: ClipOval(
                    child: Image.file(
                      _selectedAvatar!,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              : GradientAvatar(
                  imageUrl: _avatarUrl,
                  name: _fullNameController.text,
                  size: 90,
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
                Icons.camera_alt_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Year dropdown ──────────────────────────────────────────────
  Widget _buildYearDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedYear,
      dropdownColor: AppColors.cardSurface,
      style: AppTextStyles.bodyBold,
      decoration: InputDecoration(
        labelText: 'Passing Year',
        labelStyle: const TextStyle(
          color: AppColors.textMuted,
          fontFamily: 'Nunito',
        ),
        prefixIcon: const Icon(
          Icons.calendar_today_outlined,
          color: AppColors.textMuted,
          size: 20,
        ),
        filled: true,
        fillColor: AppColors.cardSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.indigo,
            width: 1.5,
          ),
        ),
      ),
      hint: const Text(
        'Select year',
        style: TextStyle(
          color: AppColors.textMuted,
          fontFamily: 'Nunito',
        ),
      ),
      items: _passingYears.map((year) {
        return DropdownMenuItem(
          value: year,
          child: Text(year),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedYear = value),
    );
  }

  // ── Text field builder ─────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: AppTextStyles.bodyBold,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: AppColors.textMuted,
          fontFamily: 'Nunito',
        ),
        prefixIcon: Icon(
          icon,
          color: AppColors.textMuted,
          size: 20,
        ),
        filled: true,
        fillColor: AppColors.cardSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.indigo,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}