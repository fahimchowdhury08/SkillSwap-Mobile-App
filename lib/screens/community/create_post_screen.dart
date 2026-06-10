
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import 'dart:io';
import '../../theme.dart';
import '../../supabase_service.dart';
import '../../widgets/coral_button.dart';
import '../../widgets/loading_spinner.dart';

class CreatePostScreen extends StatefulWidget {
  final String communityId;

  const CreatePostScreen({super.key, required this.communityId});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _captionController   = TextEditingController();
  final _articleUrlController = TextEditingController();

  // Selected post type
  String _postType = 'article'; // article | image | video | file | youtube

  // Media state
  Uint8List? _mediaBytes;
  String?    _mediaFileName;
  String?    _mediaExt;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _postTypes = [
    {'type': 'article', 'icon': Icons.article_outlined,     'label': 'Article'},
    {'type': 'image',   'icon': Icons.image_outlined,        'label': 'Image'},
    {'type': 'video',   'icon': Icons.videocam_outlined,     'label': 'Video'},
    {'type': 'file',    'icon': Icons.attach_file_rounded,   'label': 'File'},
    {'type': 'youtube', 'icon': Icons.smart_display_rounded, 'label': 'YouTube'},
  ];

  @override
  void dispose() {
    _captionController.dispose();
    _articleUrlController.dispose();
    super.dispose();
  }

  // ── Pick image ─────────────────────────────────────────────────
  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
          source: ImageSource.gallery, imageQuality: 70);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _mediaBytes    = bytes;
        _mediaFileName = picked.name;
        _mediaExt      = 'jpg';
      });
    } catch (e) {
      _showError('Could not pick image');
    }
  }

  // ── Pick video or file ─────────────────────────────────────────
  Future<void> _pickFile({required List<String> exts}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: exts,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;

      late Uint8List bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      } else {
        return;
      }

      setState(() {
        _mediaBytes    = bytes;
        _mediaFileName = file.name;
        _mediaExt      = file.extension ?? exts.first;
      });
    } catch (e) {
      _showError('Could not pick file');
    }
  }

  // ── Upload media ───────────────────────────────────────────────
  Future<String?> _uploadMedia(String communityId, String userId) async {
    if (_mediaBytes == null) return null;
    try {
      final fileName =
          'posts/$userId/${DateTime.now().millisecondsSinceEpoch}.$_mediaExt';
      await SupabaseService.client.storage
          .from('community-media')
          .uploadBinary(
            fileName,
            _mediaBytes!,
            fileOptions: const FileOptions(upsert: true),
          );
      return SupabaseService.client.storage
          .from('community-media')
          .getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  // ── Validate ───────────────────────────────────────────────────
  bool get _isValid {
    if (_captionController.text.trim().isEmpty &&
        _mediaBytes == null &&
        _articleUrlController.text.trim().isEmpty) {
      return false;
    }

    if (_postType == 'article' || _postType == 'youtube') {
      // Article needs either caption or URL
      return _captionController.text.trim().isNotEmpty ||
          _articleUrlController.text.trim().isNotEmpty;
    }
    if (_postType == 'image' || _postType == 'video' || _postType == 'file') {
      return _mediaBytes != null;
    }
    return false;
  }

  // ── Submit post ────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_isValid) {
      _showError('Please add content for your post');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = SupabaseService.currentUserId!;

      String? fileUrl;
      String? articleUrl;

      // Upload media if needed
      if (_mediaBytes != null) {
        fileUrl = await _uploadMedia(widget.communityId, uid);
      }

      // Article / YouTube URL
      if (_postType == 'article' || _postType == 'youtube') {
        articleUrl = _articleUrlController.text.trim().isEmpty
            ? null
            : _articleUrlController.text.trim();
      }

      await SupabaseService.client.from('community_posts').insert({
        'community_id': widget.communityId,
        'user_id':      uid,
        'content_type': _postType,
        'caption':      _captionController.text.trim().isEmpty
                        ? null
                        : _captionController.text.trim(),
        'file_url':     fileUrl,
        'article_url':  articleUrl,
        'like_count':   0,
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post shared! 🎉'),
          backgroundColor: AppColors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to post: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Create Post', style: AppTextStyles.heading2),
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Post type selector ─────────────────────────────
              const Text('Post Type', style: AppTextStyles.label),
              const SizedBox(height: AppSpacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _postTypes.map((t) {
                    final isSelected = _postType == t['type'];
                    return GestureDetector(
                      onTap: () => setState(() {
                        _postType      = t['type'] as String;
                        _mediaBytes    = null;
                        _mediaFileName = null;
                        _mediaExt      = null;
                      }),
                      child: Container(
                        margin: const EdgeInsets.only(right: AppSpacing.sm),
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.indigo
                              : AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.indigo
                                : AppColors.elevated,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              t['icon'] as IconData,
                              size: 18,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              t['label'] as String,
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Caption ────────────────────────────────────────
              const Text('Caption / Text', style: AppTextStyles.label),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _captionController,
                maxLines: 4,
                style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: _postType == 'article'
                      ? 'Write your article or post here...'
                      : 'Add a caption (optional)...',
                  hintStyle: const TextStyle(
                      color: AppColors.textMuted, fontFamily: 'Nunito'),
                  filled: true,
                  fillColor: AppColors.cardSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.indigo, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Type-specific input ────────────────────────────
              _buildTypeInput(),

              const SizedBox(height: AppSpacing.xxl),

              // ── Submit ─────────────────────────────────────────
              CoralButton(
                label: 'Share Post',
                icon: Icons.send_rounded,
                onTap: _isLoading ? null : _submit,
                isLoading: _isLoading,
              ),

              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeInput() {
    switch (_postType) {
      case 'image':
        return _buildMediaPicker(
          label: 'Image',
          icon: Icons.image_outlined,
          color: AppColors.indigo,
          hint: 'JPG, PNG',
          hasMedia: _mediaBytes != null,
          onTap: _pickImage,
        );

      case 'video':
        return _buildMediaPicker(
          label: 'Video',
          icon: Icons.videocam_outlined,
          color: AppColors.coral,
          hint: 'MP4, MOV, AVI',
          hasMedia: _mediaBytes != null,
          onTap: () => _pickFile(exts: ['mp4', 'mov', 'avi', 'mkv']),
        );

      case 'file':
        return _buildMediaPicker(
          label: 'Document',
          icon: Icons.attach_file_rounded,
          color: AppColors.green,
          hint: 'PDF, DOC, PPTX',
          hasMedia: _mediaBytes != null,
          onTap: () =>
              _pickFile(exts: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt']),
        );

      case 'youtube':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('YouTube URL', style: AppTextStyles.label),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _articleUrlController,
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'https://youtube.com/watch?v=...',
                hintStyle: const TextStyle(
                    color: AppColors.textMuted, fontFamily: 'Nunito'),
                prefixIcon: const Icon(Icons.smart_display_rounded,
                    color: Colors.red, size: 20),
                filled: true,
                fillColor: AppColors.cardSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red, width: 1.5),
                ),
              ),
            ),
          ],
        );

      case 'article':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Article Link (optional)', style: AppTextStyles.label),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _articleUrlController,
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'https://...',
                hintStyle: const TextStyle(
                    color: AppColors.textMuted, fontFamily: 'Nunito'),
                prefixIcon: const Icon(Icons.link_rounded,
                    color: AppColors.indigo, size: 20),
                filled: true,
                fillColor: AppColors.cardSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.indigo, width: 1.5),
                ),
              ),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMediaPicker({
    required String label,
    required IconData icon,
    required Color color,
    required String hint,
    required bool hasMedia,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.sm),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: hasMedia
                  ? color.withValues(alpha: 0.1)
                  : AppColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasMedia
                    ? color.withValues(alpha: 0.4)
                    : AppColors.elevated,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  hasMedia ? Icons.check_circle_rounded : icon,
                  size: 36,
                  color: hasMedia ? color : AppColors.textMuted,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  hasMedia
                      ? _mediaFileName ?? 'File selected ✓'
                      : 'Tap to pick $label',
                  style: AppTextStyles.bodyBold.copyWith(
                    color: hasMedia ? color : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!hasMedia)
                  Text(hint, style: AppTextStyles.caption),

                if (hasMedia) ...[
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Tap to change',
                    style: AppTextStyles.caption,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}