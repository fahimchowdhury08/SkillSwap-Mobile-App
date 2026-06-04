import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import '../../theme.dart';
import '../../supabase_service.dart';
import '../../models/skill_model.dart';
import '../../widgets/coral_button.dart';
import '../../widgets/loading_spinner.dart';
import '../../widgets/gradient_avatar.dart';
import 'availability_screen.dart';
import 'skill_verification_screen.dart';

class PersonalDetailsScreen extends StatefulWidget {
  const PersonalDetailsScreen({super.key});

  @override
  State<PersonalDetailsScreen> createState() =>
      _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  final _emailController    = TextEditingController();
  final _phoneController    = TextEditingController();
  final _linkedinController = TextEditingController();
  final _newSkillController = TextEditingController();

  bool _isLoading    = false;
  bool _isSaving     = false;
  bool _showAddSkill = false;
  String? _avatarUrl;
  Uint8List? _avatarBytes;
  List<SkillModel> _teachingSkills = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _linkedinController.dispose();
    _newSkillController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final userRes = await SupabaseService.client
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      final skillsRes = await SupabaseService.client
          .from('skills')
          .select()
          .eq('user_id', userId)
          .eq('is_teaching', true);

      setState(() {
        _emailController.text    = userRes['email'] ?? '';
        _phoneController.text    = userRes['phone'] ?? '';
        _linkedinController.text = userRes['linkedin_url'] ?? '';
        _avatarUrl               = userRes['avatar_url'];
        _teachingSkills          = (skillsRes as List)
            .map((j) => SkillModel.fromJson(j))
            .toList();
      });
    } catch (e) {
      debugPrint('Load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Pick avatar ────────────────────────────────────────────────
  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 800,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() => _avatarBytes = bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not pick image.'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  // ── Upload avatar ──────────────────────────────────────────────
  Future<String?> _uploadAvatar(String userId) async {
    if (_avatarBytes == null) return _avatarUrl;
    try {
      final fileName = 'avatar_$userId.jpg';
      await SupabaseService.client.storage
          .from('avatars')
          .uploadBinary(
            fileName,
            _avatarBytes!,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      return SupabaseService.client.storage
          .from('avatars')
          .getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Upload error: $e');
      return _avatarUrl;
    }
  }

  // ── Add new skill ──────────────────────────────────────────────
  Future<void> _addSkill() async {
    final skillName = _newSkillController.text.trim();
    if (skillName.isEmpty) return;
    try {
      final userId = SupabaseService.currentUserId!;
      await SupabaseService.client.from('skills').insert({
        'user_id':     userId,
        'name':        skillName,
        'category':    SkillModel.detectCategory(skillName),
        'is_teaching': true,
      });
      _newSkillController.clear();
      setState(() => _showAddSkill = false);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$skillName added!'),
          backgroundColor: AppColors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not add skill. Please try again.'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  // ── Save changes ───────────────────────────────────────────────
  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final userId    = SupabaseService.currentUserId!;
      final avatarUrl = await _uploadAvatar(userId);
      await SupabaseService.client.from('users').update({
        'phone':        _phoneController.text.trim(),
        'linkedin_url': _linkedinController.text.trim(),
        'avatar_url':   avatarUrl,
      }).eq('id', userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Changes saved! ✓'),
          backgroundColor: AppColors.green,
        ),
      );
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
          'Personal Details',
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

                    // ── Avatar ────────────────────────────
                    Center(child: _buildAvatarSection()),

                    const SizedBox(height: AppSpacing.xl),

                    // ── Email (read only) ─────────────────
                    _buildReadOnlyField(
                      label: 'Email Address',
                      value: _emailController.text,
                      icon: Icons.email_outlined,
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // ── Phone ─────────────────────────────
                    _buildEditableField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // ── LinkedIn ──────────────────────────
                    _buildEditableField(
                      controller: _linkedinController,
                      label: 'LinkedIn URL',
                      icon: Icons.link_rounded,
                      keyboardType: TextInputType.url,
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ── My Skills ─────────────────────────
                    _buildSkillsSection(),

                    const SizedBox(height: AppSpacing.xl),

                    // ── Availability ──────────────────────
                    _buildAvailabilityTile(),

                    const SizedBox(height: AppSpacing.xl),

                    // ── Save button ───────────────────────
                    CoralButton(
                      label: 'Save Changes',
                      onTap: _isSaving ? null : _saveChanges,
                      isLoading: _isSaving,
                    ),

                    const SizedBox(height: AppSpacing.lg),

                  ],
                ),
              ),
            ),
    );
  }

  // ── Avatar section ─────────────────────────────────────────────
  Widget _buildAvatarSection() {
    return GestureDetector(
      onTap: _pickAvatar,
      child: Stack(
        children: [
          // Avatar display
          _avatarBytes != null
              ? Container(
                  width: 90,
                  height: 90,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.indigoCoralGradient,
                  ),
                  padding: const EdgeInsets.all(2.5),
                  child: ClipOval(
                    child: Image.memory(
                      _avatarBytes!,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              : GradientAvatar(
                  imageUrl: _avatarUrl,
                  size: 90,
                ),

          // Camera icon
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

  // ── Skills section ─────────────────────────────────────────────
  Widget _buildSkillsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'My Skills (${_teachingSkills.length})',
              style: AppTextStyles.heading3,
            ),
            TextButton.icon(
              onPressed: () =>
                  setState(() => _showAddSkill = !_showAddSkill),
              icon: Icon(
                _showAddSkill ? Icons.close : Icons.add,
                size: 16,
                color: AppColors.indigo,
              ),
              label: Text(
                _showAddSkill ? 'Cancel' : 'Add Skill',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.indigo,
                ),
              ),
            ),
          ],
        ),

        if (_showAddSkill) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newSkillController,
                  style: AppTextStyles.bodyBold,
                  onSubmitted: (_) => _addSkill(),
                  decoration: InputDecoration(
                    hintText: 'e.g. Python, Figma',
                    hintStyle: const TextStyle(
                      color: AppColors.textMuted,
                      fontFamily: 'Nunito',
                      fontSize: 13,
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              GestureDetector(
                onTap: _addSkill,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.indigo,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: AppSpacing.md),

        if (_teachingSkills.isEmpty)
          const Text(
            'No skills added yet. Tap Add Skill to get started.',
            style: AppTextStyles.body,
          )
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _teachingSkills.map((skill) {
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SkillVerificationScreen(
                        skillId:   skill.id,
                        skillName: skill.name,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs + 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.indigo.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: AppColors.indigo.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        skill.name,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.indigo,
                        ),
                      ),
                      if (skill.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          size: 12,
                          color: AppColors.indigo,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  // ── Availability tile ──────────────────────────────────────────
  Widget _buildAvailabilityTile() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AvailabilityScreen(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.elevated),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.access_time_rounded,
              color: AppColors.indigo,
              size: 22,
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Availability', style: AppTextStyles.bodyBold),
                  Text(
                    'Set when you are free for sessions',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.textMuted,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  // ── Read only field ────────────────────────────────────────────
  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 20),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption),
              const SizedBox(height: 2),
              Text(value, style: AppTextStyles.bodyBold),
            ],
          ),
        ],
      ),
    );
  }

  // ── Editable field ─────────────────────────────────────────────
  Widget _buildEditableField({
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
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
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