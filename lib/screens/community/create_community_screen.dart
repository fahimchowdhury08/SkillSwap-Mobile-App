
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import '../../theme.dart';
import '../../supabase_service.dart';
import '../../widgets/coral_button.dart';
import '../../widgets/loading_spinner.dart';
import 'community_detail_screen.dart';

class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final _nameController        = TextEditingController();
  final _descController        = TextEditingController();
  final _skillTagController    = TextEditingController();
  final _questionController    = TextEditingController();

  bool _isLoading = false;
  Uint8List? _iconBytes;

  // Join questions list
  final List<String> _questions = [];

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _skillTagController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  // ── Pick icon ──────────────────────────────────────────────────
  Future<void> _pickIcon() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 400,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() => _iconBytes = bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not pick image'), backgroundColor: AppColors.red),
      );
    }
  }

  // ── Add question ───────────────────────────────────────────────
  void _addQuestion() {
    final q = _questionController.text.trim();
    if (q.isEmpty) return;
    if (_questions.contains(q)) {
      _questionController.clear();
      return;
    }
    setState(() {
      _questions.add(q);
      _questionController.clear();
    });
  }

  // ── Create community ───────────────────────────────────────────
  Future<void> _create() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a community name'),
            backgroundColor: AppColors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = SupabaseService.currentUserId!;

      // 1 — Insert community
      final commRes = await SupabaseService.client
          .from('communities')
          .insert({
            'name':         _nameController.text.trim(),
            'description':  _descController.text.trim().isEmpty
                            ? null
                            : _descController.text.trim(),
            'skill_tag':    _skillTagController.text.trim().isEmpty
                            ? null
                            : _skillTagController.text.trim(),
            'admin_id':     uid,
            'member_count': 1,
          })
          .select()
          .single();

      final communityId = commRes['id'] as String;

      // 2 — Upload icon if selected
      if (_iconBytes != null) {
        final fileName = 'community-icons/$communityId.jpg';
        await SupabaseService.client.storage
            .from('community-media')
            .uploadBinary(
              fileName,
              _iconBytes!,
              fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
            );
        final url = SupabaseService.client.storage
            .from('community-media')
            .getPublicUrl(fileName);
        await SupabaseService.client
            .from('communities')
            .update({'avatar_url': url})
            .eq('id', communityId);
      }

      // 3 — Insert creator as admin member
      await SupabaseService.client.from('community_members').insert({
        'community_id': communityId,
        'user_id':      uid,
        'status':       'member',
        'role':         'admin',
      });

      // 4 — Insert join questions
      for (int i = 0; i < _questions.length; i++) {
        await SupabaseService.client.from('community_join_questions').insert({
          'community_id': communityId,
          'question':     _questions[i],
          'order_index':  i,
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Community created! 🎉'),
          backgroundColor: AppColors.green,
        ),
      );

      // Navigate to the new community
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CommunityDetailScreen(
            communityId: communityId,
            role: 'admin',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.red),
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
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Create Community', style: AppTextStyles.heading2),
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Community icon ─────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: _pickIcon,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: _iconBytes == null
                          ? AppColors.indigoCoralGradient
                          : null,
                      color: _iconBytes != null ? AppColors.cardSurface : null,
                    ),
                    child: _iconBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.memory(_iconBytes!, fit: BoxFit.cover),
                          )
                        : const Icon(
                            Icons.groups_rounded,
                            size: 44,
                            color: Colors.white,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Center(
                child: Text(
                  'TAP TO ADD ICON',
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

              // ── Form ───────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildField(
                      controller: _nameController,
                      label: 'Community Name *',
                      hint: 'e.g. Python World',
                      icon: Icons.groups_outlined,
                    ),
                    const Divider(color: AppColors.elevated, height: 1,
                        indent: 16, endIndent: 16),
                    _buildField(
                      controller: _descController,
                      label: 'Description',
                      hint: 'What is this community about?',
                      icon: Icons.description_outlined,
                      maxLines: 3,
                    ),
                    const Divider(color: AppColors.elevated, height: 1,
                        indent: 16, endIndent: 16),
                    _buildField(
                      controller: _skillTagController,
                      label: 'Skill Tag',
                      hint: 'e.g. Python, UI/UX Design',
                      icon: Icons.tag_rounded,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Join Questions section ─────────────────────────
              Row(
                children: [
                  const Text('❓ Join Questions', style: AppTextStyles.heading3),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '(optional)',
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Members must answer these before joining.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.md),

              // Existing questions
              if (_questions.isNotEmpty) ...[
                ..._questions.asMap().entries.map((entry) {
                  final i = entry.key;
                  final q = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.elevated),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: AppColors.indigo,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text(q, style: AppTextStyles.body)),
                        GestureDetector(
                          onTap: () => setState(() => _questions.removeAt(i)),
                          child: const Icon(Icons.close_rounded,
                              size: 18, color: AppColors.red),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: AppSpacing.sm),
              ],

              // Add question input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _questionController,
                      style: AppTextStyles.body.copyWith(
                          color: AppColors.textPrimary),
                      onSubmitted: (_) => _addQuestion(),
                      decoration: InputDecoration(
                        hintText: 'Type a question and tap +',
                        hintStyle: const TextStyle(
                            color: AppColors.textMuted,
                            fontFamily: 'Nunito',
                            fontSize: 13),
                        filled: true,
                        fillColor: AppColors.cardSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.indigo, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md, vertical: AppSpacing.md),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  GestureDetector(
                    onTap: _addQuestion,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.indigo,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add_rounded,
                          color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xxl),

              // ── Create button ──────────────────────────────────
              CoralButton(
                label: 'Create Community',
                onTap: _isLoading ? null : _create,
                isLoading: _isLoading,
              ),

              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 18, color: AppColors.textMuted),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: maxLines,
                  style: AppTextStyles.bodyBold,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(
                        color: AppColors.textMuted,
                        fontFamily: 'Nunito',
                        fontSize: 14),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}