import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../theme.dart';
import '../../supabase_service.dart';
import '../../widgets/coral_button.dart';
import '../../widgets/loading_spinner.dart';

class SkillVerificationScreen extends StatefulWidget {
  final String skillId;
  final String skillName;

  const SkillVerificationScreen({
    super.key,
    required this.skillId,
    required this.skillName,
  });

  @override
  State<SkillVerificationScreen> createState() =>
      _SkillVerificationScreenState();
}

class _SkillVerificationScreenState
    extends State<SkillVerificationScreen> {
  bool _isUploading    = false;
  bool _isVerified     = false;
  String? _uploadedFileName;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyVerified();
  }

  Future<void> _checkIfAlreadyVerified() async {
    try {
      final res = await SupabaseService.client
          .from('skills')
          .select('is_verified')
          .eq('id', widget.skillId)
          .single();
      setState(() => _isVerified = res['is_verified'] ?? false);
    } catch (e) {
      debugPrint('Check verified error: $e');
    }
  }

  Future<void> _uploadCertificate() async {
    try {
      // Step 1 — Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;

      setState(() {
        _isUploading      = true;
        _uploadedFileName = file.name;
      });

      final userId   = SupabaseService.currentUserId!;
      final fileName =
          'cert_${userId}_${widget.skillId}.${file.extension}';

      // Step 2 — Get bytes
      late final Uint8List bytes;

      if (file.bytes != null) {
        // Web — bytes already available
        bytes = file.bytes!;
      } else if (file.path != null) {
        // Mobile — read from file path
        bytes = await File(file.path!).readAsBytes();
      } else {
        throw Exception('No file data available');
      }

      // Step 3 — Upload to Supabase Storage
      await SupabaseService.client.storage
          .from('certificates')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      // Step 4 — Get public URL
      final certUrl = SupabaseService.client.storage
          .from('certificates')
          .getPublicUrl(fileName);

      // Step 5 — Update skill as verified
      await SupabaseService.client.from('skills').update({
        'is_verified':     true,
        'verified_via':    'certificate',
        'certificate_url': certUrl,
      }).eq('id', widget.skillId);

      setState(() => _isVerified = true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.skillName} verified! ✓'),
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
          'Verify Skill',
          style: AppTextStyles.heading2,
        ),
      ),
      body: _isUploading
          ? const LoadingSpinner(message: 'Uploading certificate...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Skill name card ──────────────────────
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.indigo.withValues(alpha: 0.2),
                          AppColors.coral.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.indigo.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.workspace_premium_rounded,
                          color: AppColors.indigo,
                          size: 32,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Skill to verify',
                              style: AppTextStyles.caption,
                            ),
                            Text(
                              widget.skillName,
                              style: AppTextStyles.heading2,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // ── Already verified ─────────────────────
                  if (_isVerified) ...[
                    _buildVerifiedCard(),
                  ] else ...[

                    const Text(
                      'How verification works',
                      style: AppTextStyles.heading3,
                    ),

                    const SizedBox(height: AppSpacing.md),

                    _buildStep(
                      number: '1',
                      title: 'Upload a certificate',
                      subtitle:
                          'Any certificate or credential that proves your skill',
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    _buildStep(
                      number: '2',
                      title: 'Get the verified badge',
                      subtitle:
                          'Your skill chip will show a ✓ badge on your profile',
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    _buildStep(
                      number: '3',
                      title: 'Get more swaps',
                      subtitle:
                          'Verified skills attract more swap requests',
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    const Text(
                      'Accepted formats',
                      style: AppTextStyles.label,
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    const Row(
                      children: [
                        _FormatChip(label: 'PDF'),
                        SizedBox(width: AppSpacing.sm),
                        _FormatChip(label: 'JPG'),
                        SizedBox(width: AppSpacing.sm),
                        _FormatChip(label: 'PNG'),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ── Uploaded file name ────────────────
                    if (_uploadedFileName != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.indigo.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.insert_drive_file_outlined,
                              color: AppColors.indigo,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                _uploadedFileName!,
                                style: AppTextStyles.body,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // ── Upload button ─────────────────────
                    CoralButton(
                      label: 'Upload Certificate',
                      icon: Icons.upload_file_rounded,
                      onTap: _isUploading ? null : _uploadCertificate,
                      isLoading: _isUploading,
                    ),

                  ],

                  const SizedBox(height: AppSpacing.lg),

                ],
              ),
            ),
    );
  }

  Widget _buildVerifiedCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.green.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.verified_rounded,
            color: AppColors.green,
            size: 64,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Skill Verified! ✓',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              fontSize: 22,
              color: AppColors.green,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${widget.skillName} now shows a verified badge on your profile',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required String number,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: AppColors.indigo,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.bodyBold),
              Text(subtitle, style: AppTextStyles.caption),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Format chip ────────────────────────────────────────────────────
class _FormatChip extends StatelessWidget {
  final String label;
  const _FormatChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.elevated),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}