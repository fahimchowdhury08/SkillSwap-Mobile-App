import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../theme.dart';
import '../../supabase_service.dart';
import '../../models/skill_model.dart';
import '../../widgets/coral_button.dart';
import '../../widgets/loading_spinner.dart';

class ProfileSetupStep2Screen extends StatefulWidget {
  const ProfileSetupStep2Screen({super.key});

  @override
  State<ProfileSetupStep2Screen> createState() =>
      _ProfileSetupStep2ScreenState();
}

class _ProfileSetupStep2ScreenState extends State<ProfileSetupStep2Screen> {
  final _teachSkillController = TextEditingController();
  final _learnSkillController = TextEditingController();

  final List<String> _teachingSkills = [];
  final List<String> _learningSkills = [];

  // Confirmed certs — stored in database
  final List<Map<String, dynamic>> _confirmedCerts = [];

  // Pending cert — picked but not yet confirmed
  Map<String, dynamic>? _pendingCert;

  bool _isLoading   = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadExistingSkills();
  }

  @override
  void dispose() {
    _teachSkillController.dispose();
    _learnSkillController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingSkills() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      final res = await SupabaseService.client
          .from('skills')
          .select()
          .eq('user_id', userId);

      setState(() {
        for (final s in res as List) {
          final skill = SkillModel.fromJson(s);
          if (skill.isTeaching &&
              !_teachingSkills.contains(skill.name)) {
            _teachingSkills.add(skill.name);
          } else if (!skill.isTeaching &&
              !_learningSkills.contains(skill.name)) {
            _learningSkills.add(skill.name);
          }
        }
      });
    } catch (e) {
      debugPrint('Load skills error: $e');
    }
  }

  void _addTeachSkill() {
    final skill = _teachSkillController.text.trim();
    if (skill.isEmpty) return;
    if (_teachingSkills.contains(skill)) {
      _teachSkillController.clear();
      return;
    }
    setState(() {
      _teachingSkills.add(skill);
      _teachSkillController.clear();
    });
  }

  void _addLearnSkill() {
    final skill = _learnSkillController.text.trim();
    if (skill.isEmpty) return;
    if (_learningSkills.contains(skill)) {
      _learnSkillController.clear();
      return;
    }
    setState(() {
      _learningSkills.add(skill);
      _learnSkillController.clear();
    });
  }

  // ── Step 1 — Pick file and show pending preview ────────────────
  Future<void> _pickCertificate() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;

      late final Uint8List bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      } else {
        return;
      }

      // Show pending preview — not uploaded yet
      setState(() {
        _pendingCert = {
          'name':  file.name,
          'bytes': bytes,
          'ext':   file.extension ?? 'jpg',
        };
      });

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not pick file. Please try again.'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  // ── Step 2 — Confirm: upload to storage + save to database ─────
  Future<void> _confirmCertificate() async {
    if (_pendingCert == null) return;

    setState(() => _isUploading = true);

    try {
      final userId   = SupabaseService.currentUserId!;
      final fileName =
          'cert_${userId}_${DateTime.now().millisecondsSinceEpoch}'
          '.${_pendingCert!['ext']}';
      final bytes = _pendingCert!['bytes'] as Uint8List;

      // Upload to storage
      await SupabaseService.client.storage
          .from('certificates')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final url = SupabaseService.client.storage
          .from('certificates')
          .getPublicUrl(fileName);

      // Add to confirmed list
      setState(() {
        _confirmedCerts.add({
          'name':     _pendingCert!['name'],
          'url':      url,
          'fileName': fileName,
        });
        _pendingCert = null;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_pendingCert?['name'] ?? 'Certificate'} saved! ✓'),
          backgroundColor: AppColors.green,
        ),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload failed. Please try again.'),
          backgroundColor: AppColors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── Cancel pending cert ────────────────────────────────────────
  void _cancelPendingCert() {
    setState(() => _pendingCert = null);
  }

  // ── Delete confirmed cert from storage ─────────────────────────
  Future<void> _deleteCert(int index) async {
    final cert = _confirmedCerts[index];
    try {
      // Delete from storage
      await SupabaseService.client.storage
          .from('certificates')
          .remove([cert['fileName'] as String]);

      setState(() => _confirmedCerts.removeAt(index));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Certificate deleted'),
          backgroundColor: AppColors.indigo,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete. Please try again.'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  // ── Complete profile ───────────────────────────────────────────
  Future<void> _complete() async {
    if (_teachingSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least 1 skill you can teach'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = SupabaseService.currentUserId!;

      await SupabaseService.client
          .from('skills')
          .delete()
          .eq('user_id', userId);

      for (final skill in _teachingSkills) {
        await SupabaseService.client.from('skills').insert({
          'user_id':     userId,
          'name':        skill,
          'category':    SkillModel.detectCategory(skill),
          'is_teaching': true,
        });
      }

      for (final skill in _learningSkills) {
        await SupabaseService.client.from('skills').insert({
          'user_id':     userId,
          'name':        skill,
          'category':    SkillModel.detectCategory(skill),
          'is_teaching': false,
        });
      }

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
        (route) => false,
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _progress {
    double p = 0;
    if (_teachingSkills.isNotEmpty) p += 0.45;
    if (_learningSkills.isNotEmpty) p += 0.45;
    if (_confirmedCerts.isNotEmpty) p += 0.1;
    return p.clamp(0.0, 1.0);
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
          'Skills & Interests',
          style: AppTextStyles.heading2,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(32),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'STEP 2 OF 2',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: AppColors.textMuted,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      '${(_progress * 100).toInt()}%',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: AppColors.elevated,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.indigo,
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
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

              // ── Skills I Have ────────────────────────
              _buildSectionHeader(icon: '⭐', title: 'Skills I Have'),
              const SizedBox(height: AppSpacing.sm),
              if (_teachingSkills.isNotEmpty)
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: _teachingSkills.map((skill) {
                    return _buildSkillChip(
                      skill,
                      AppColors.indigo,
                      () => setState(
                        () => _teachingSkills.remove(skill),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: AppSpacing.sm),
              _buildSkillInput(
                controller: _teachSkillController,
                hint: 'Add a skill...',
                color: AppColors.indigo,
                onAdd: _addTeachSkill,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Add at least 1 skill you\'re proficient in.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── I Want to Learn ──────────────────────
              _buildSectionHeader(icon: '🎓', title: 'I Want to Learn'),
              const SizedBox(height: AppSpacing.sm),
              if (_learningSkills.isNotEmpty)
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: _learningSkills.map((skill) {
                    return _buildSkillChip(
                      skill,
                      AppColors.coral,
                      () => setState(
                        () => _learningSkills.remove(skill),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: AppSpacing.sm),
              _buildSkillInput(
                controller: _learnSkillController,
                hint: 'Add a skill...',
                color: AppColors.coral,
                onAdd: _addLearnSkill,
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Upload Certificates ──────────────────
              _buildSectionHeader(
                icon: '🏅',
                title: 'Upload Certificates',
              ),
              const SizedBox(height: AppSpacing.sm),

              // Upload area — only show if no pending cert
              if (_pendingCert == null)
                GestureDetector(
                  onTap: _isUploading ? null : _pickCertificate,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.elevated),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.indigo
                                .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.cloud_upload_outlined,
                            color: AppColors.indigo,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          'Drag or tap to upload',
                          style: AppTextStyles.bodyBold,
                        ),
                        const Text(
                          'JPG, PNG or PDF (Max 5MB)',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Pending cert preview ─────────────────
              if (_pendingCert != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.indigo.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [

                      // File info
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.indigo
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.insert_drive_file_outlined,
                              color: AppColors.indigo,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              _pendingCert!['name'] as String,
                              style: AppTextStyles.bodyBold,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.md),

                      const Text(
                        'Confirm to upload this certificate?',
                        style: AppTextStyles.body,
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: AppSpacing.md),

                      // Confirm / Cancel buttons
                      Row(
                        children: [

                          // Cancel button
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _cancelPendingCert,
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 16,
                              ),
                              label: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.red,
                                side: const BorderSide(
                                  color: AppColors.red,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(100),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: AppSpacing.md),

                          // Confirm button
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isUploading
                                  ? null
                                  : _confirmCertificate,
                              icon: _isUploading
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.check_rounded,
                                      size: 16,
                                    ),
                              label: Text(
                                _isUploading
                                    ? 'Uploading...'
                                    : 'Confirm',
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.green,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(100),
                                ),
                              ),
                            ),
                          ),

                        ],
                      ),

                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.md),

              // ── Confirmed certificates ───────────────
              if (_confirmedCerts.isNotEmpty) ...[
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: _confirmedCerts
                      .asMap()
                      .entries
                      .map((entry) => _buildCertCard(
                            entry.key,
                            entry.value['name'] as String,
                          ))
                      .toList(),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              const SizedBox(height: AppSpacing.xl),

              // ── Complete button ──────────────────────
              CoralButton(
                label: 'Complete Profile',
                onTap: _isLoading ? null : _complete,
                isLoading: _isLoading,
              ),

              const SizedBox(height: AppSpacing.md),

              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/home',
                      (route) => false,
                    );
                  },
                  child: const Text(
                    'Skip for now',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String icon,
    required String title,
  }) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSkillInput({
    required TextEditingController controller,
    required String hint,
    required Color color,
    required VoidCallback onAdd,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.elevated),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textPrimary,
              ),
              onSubmitted: (_) => onAdd(),
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              margin: const EdgeInsets.all(AppSpacing.xs),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillChip(
    String skill,
    Color color,
    VoidCallback onRemove,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            skill,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close_rounded,
              size: 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Confirmed cert card with delete button ─────────────────────
  Widget _buildCertCard(int index, String fileName) {
    return Container(
      width: 120,
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.elevated),
      ),
      child: Stack(
        children: [

          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.indigo.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: AppColors.indigo,
                    size: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  child: Text(
                    fileName,
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // ── Green check — confirmed ──────────────────
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: AppColors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 11,
                color: Colors.white,
              ),
            ),
          ),

          // ── Red X — delete from database ─────────────
          Positioned(
            top: 4,
            left: 4,
            child: GestureDetector(
              onTap: () => _deleteCert(index),
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: AppColors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 11,
                  color: Colors.white,
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }
}