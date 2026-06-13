import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import 'dart:io';
import '../../theme.dart';
import '../../supabase_service.dart';
import '../../widgets/coral_button.dart';

// Supabase free plan default max upload = 50 MB
const int _kMaxFileSizeMB = 50;

class CreatePostScreen extends StatefulWidget {
  final String communityId;
  const CreatePostScreen({super.key, required this.communityId});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _captionController    = TextEditingController();
  final _articleUrlController = TextEditingController();

  String _postType = 'article';

  Uint8List? _imageBytes;
  File?      _mediaFile;
  Uint8List? _mediaBytes;
  String?    _mediaFileName;
  String?    _mediaExt;
  int?       _mediaFileSizeBytes;

  bool   _isPicking   = false;
  bool   _isUploading = false;

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
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1200,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBytes         = bytes;
        _mediaFile          = null;
        _mediaBytes         = null;
        _mediaFileName      = picked.name;
        _mediaExt           = 'jpg';
        _mediaFileSizeBytes = bytes.length;
      });
    } catch (e) {
      _showError('Could not pick image');
    }
  }

  // ── Pick video / file ──────────────────────────────────────────
  // KEY FIX: Pick once with withData: true so we always get bytes
  // on the emulator without asking the user to pick twice.
  // On a real device the file path is used (fast, no RAM load).
  // On emulator the bytes fallback works automatically.
  Future<void> _pickFile({
    required List<String> exts,
    required String label,
  }) async {
    // Show overlay immediately before calling picker
    setState(() => _isPicking = true);

    try {
      // Single pick call — request BOTH path and bytes.
      // file_picker fills whichever it can:
      //   • Real device  → path is set, bytes may be null  → use File(path)
      //   • Emulator     → path may be content://, bytes set → use bytes
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: exts,
        withData: true, // always request bytes as fallback
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isPicking = false);
        return;
      }

      final pf = result.files.first;

      // ── Real path available and accessible (physical device) ──
      final path = pf.path;
      if (path != null &&
          !path.startsWith('content://') &&
          await File(path).exists()) {
        final fileSize = await File(path).length();
        if (fileSize > _kMaxFileSizeMB * 1024 * 1024) {
          setState(() => _isPicking = false);
          _showFileTooLargeDialog(fileSize);
          return;
        }
        setState(() {
          _mediaFile          = File(path);
          _mediaBytes         = null;
          _imageBytes         = null;
          _mediaFileName      = pf.name;
          _mediaExt           = pf.extension ?? exts.first;
          _mediaFileSizeBytes = fileSize;
          _isPicking          = false;
        });
        return;
      }

      // ── Bytes fallback (emulator / content:// URI) ─────────────
      if (pf.bytes != null) {
        final fileSize = pf.bytes!.length;
        if (fileSize > _kMaxFileSizeMB * 1024 * 1024) {
          setState(() => _isPicking = false);
          _showFileTooLargeDialog(fileSize);
          return;
        }
        setState(() {
          _mediaBytes         = pf.bytes;
          _mediaFile          = null;
          _imageBytes         = null;
          _mediaFileName      = pf.name;
          _mediaExt           = pf.extension ?? exts.first;
          _mediaFileSizeBytes = fileSize;
          _isPicking          = false;
        });
        return;
      }

      // Nothing worked
      setState(() => _isPicking = false);
      _showError('Could not load file. Try copying it to the Downloads folder first.');
    } catch (e) {
      setState(() => _isPicking = false);
      _showError('Could not pick file: $e');
    }
  }

  // ── File too large dialog ──────────────────────────────────────
  void _showFileTooLargeDialog(int sizeBytes) {
    final sizeMB = (sizeBytes / (1024 * 1024)).toStringAsFixed(1);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        title: const Text('File Too Large', style: AppTextStyles.heading3),
        content: Text(
          'Your file is ${sizeMB}MB. The maximum allowed size is ${_kMaxFileSizeMB}MB.\n\n'
          'Please trim or compress the video before uploading.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK',
                style: TextStyle(
                    color: AppColors.coral,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Upload ─────────────────────────────────────────────────────
  Future<String?> _uploadMedia(String userId) async {
    final fileName =
        'posts/$userId/${DateTime.now().millisecondsSinceEpoch}.$_mediaExt';

    setState(() => _isUploading = true);

    try {
      if (_postType == 'image' && _imageBytes != null) {
        await SupabaseService.client.storage
            .from('community-media')
            .uploadBinary(
              fileName,
              _imageBytes!,
              fileOptions: const FileOptions(upsert: true),
            );
      } else if (_mediaFile != null) {
        // Stream directly from disk — efficient on real device
        await SupabaseService.client.storage
            .from('community-media')
            .upload(
              fileName,
              _mediaFile!,
              fileOptions: const FileOptions(upsert: true),
            );
      } else if (_mediaBytes != null) {
        // Upload from bytes — emulator fallback
        await SupabaseService.client.storage
            .from('community-media')
            .uploadBinary(
              fileName,
              _mediaBytes!,
              fileOptions: const FileOptions(upsert: true),
            );
      } else {
        return null;
      }

      return SupabaseService.client.storage
          .from('community-media')
          .getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Upload error: $e');
      final msg = e.toString();
      if (msg.contains('413') ||
          msg.contains('too large') ||
          msg.contains('Payload')) {
        if (mounted) {
          _showError(
              'File is too large (max ${_kMaxFileSizeMB}MB). Please compress it first.');
        }
      } else {
        if (mounted) _showError('Upload failed. Please try again.');
      }
      return null;
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── Validate ───────────────────────────────────────────────────
  bool get _hasMedia =>
      _imageBytes != null || _mediaFile != null || _mediaBytes != null;

  bool get _isValid {
    if (_postType == 'article' || _postType == 'youtube') {
      return _captionController.text.trim().isNotEmpty ||
          _articleUrlController.text.trim().isNotEmpty;
    }
    return _hasMedia;
  }

  // ── Submit ─────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_isValid) {
      _showError('Please add content for your post');
      return;
    }

    String? fileUrl;
    String? articleUrl;

    if (_hasMedia) {
      final uid = SupabaseService.currentUserId!;
      fileUrl = await _uploadMedia(uid);
      if (fileUrl == null) return;
    }

    if (_postType == 'article' || _postType == 'youtube') {
      final raw = _articleUrlController.text.trim();
      articleUrl = raw.isEmpty ? null : raw;
    }

    try {
      await SupabaseService.client.from('community_posts').insert({
        'community_id': widget.communityId,
        'user_id':      SupabaseService.currentUserId!,
        'content_type': _postType,
        'caption': _captionController.text.trim().isEmpty
            ? null
            : _captionController.text.trim(),
        'file_url':    fileUrl,
        'article_url': articleUrl,
        'like_count':  0,
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Post shared! 🎉'),
            backgroundColor: AppColors.green),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to post: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.red));
  }

  bool get _isBusy => _isPicking || _isUploading;

  String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          onPressed: _isBusy ? null : () => Navigator.pop(context),
        ),
        title: const Text('Create Post', style: AppTextStyles.heading2),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Post type selector
                const Text('Post Type', style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.sm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _postTypes.map((t) {
                      final isSelected = _postType == t['type'];
                      return GestureDetector(
                        onTap: _isBusy
                            ? null
                            : () => setState(() {
                                  _postType           = t['type'] as String;
                                  _imageBytes         = null;
                                  _mediaFile          = null;
                                  _mediaBytes         = null;
                                  _mediaFileName      = null;
                                  _mediaExt           = null;
                                  _mediaFileSizeBytes = null;
                                }),
                        child: Container(
                          margin: const EdgeInsets.only(right: AppSpacing.sm),
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm),
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
                              Icon(t['icon'] as IconData,
                                  size: 18,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textMuted),
                              const SizedBox(width: 6),
                              Text(t['label'] as String,
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textMuted,
                                  )),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // Caption
                const Text('Caption / Text', style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _captionController,
                  maxLines: 4,
                  enabled: !_isBusy,
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textPrimary),
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
                      borderSide: const BorderSide(
                          color: AppColors.indigo, width: 1.5),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),
                _buildTypeInput(),
                const SizedBox(height: AppSpacing.xxl),

                CoralButton(
                  label: 'Share Post',
                  icon: Icons.send_rounded,
                  onTap: _isBusy ? null : _submit,
                  isLoading: _isUploading,
                ),

                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),

          // Picking overlay
          if (_isPicking) _buildPickingOverlay(),

          // Upload overlay
          if (_isUploading) _buildUploadOverlay(),
        ],
      ),
    );
  }

  // ── Picking overlay ────────────────────────────────────────────
  Widget _buildPickingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 48),
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.indigo.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.folder_open_rounded,
                    color: AppColors.indigo, size: 28),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('Preparing file…',
                  style: AppTextStyles.heading3,
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: const LinearProgressIndicator(
                  minHeight: 5,
                  backgroundColor: AppColors.elevated,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.indigo),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Upload overlay ─────────────────────────────────────────────
  Widget _buildUploadOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 48),
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.coral.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_upload_outlined,
                    color: AppColors.coral, size: 32),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _postType == 'video'
                    ? 'Uploading video…'
                    : _postType == 'file'
                        ? 'Uploading document…'
                        : 'Uploading…',
                style: AppTextStyles.heading3,
                textAlign: TextAlign.center,
              ),
              if (_mediaFileName != null) ...[
                const SizedBox(height: 4),
                Text(
                  _mediaFileName!,
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
              if (_mediaFileSizeBytes != null) ...[
                const SizedBox(height: 2),
                Text(
                  _formatSize(_mediaFileSizeBytes),
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textMuted),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: const LinearProgressIndicator(
                  value: null,
                  minHeight: 7,
                  backgroundColor: AppColors.elevated,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.coral),
                ),
              ),
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
          hasMedia: _imageBytes != null,
          onTap: _pickImage,
        );

      case 'video':
        return _buildMediaPicker(
          label: 'Video',
          icon: Icons.videocam_outlined,
          color: AppColors.coral,
          hint: 'MP4, MOV, AVI, MKV  •  Max ${_kMaxFileSizeMB}MB',
          hasMedia: _mediaFile != null || _mediaBytes != null,
          onTap: () => _pickFile(
              exts: ['mp4', 'mov', 'avi', 'mkv'], label: 'video'),
        );

      case 'file':
        return _buildMediaPicker(
          label: 'Document',
          icon: Icons.attach_file_rounded,
          color: AppColors.green,
          hint: 'PDF, DOC, PPTX  •  Max ${_kMaxFileSizeMB}MB',
          hasMedia: _mediaFile != null || _mediaBytes != null,
          onTap: () => _pickFile(
              exts: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt'],
              label: 'document'),
        );

      case 'youtube':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('YouTube URL', style: AppTextStyles.label),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _articleUrlController,
              enabled: !_isBusy,
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textPrimary),
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
                  borderSide:
                      const BorderSide(color: Colors.red, width: 1.5),
                ),
              ),
            ),
          ],
        );

      case 'article':
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Article Link (optional)', style: AppTextStyles.label),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _articleUrlController,
              enabled: !_isBusy,
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textPrimary),
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
                  borderSide: const BorderSide(
                      color: AppColors.indigo, width: 1.5),
                ),
              ),
            ),
          ],
        );
    }
  }

  Widget _buildMediaPicker({
    required String   label,
    required IconData icon,
    required Color    color,
    required String   hint,
    required bool     hasMedia,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.sm),
        GestureDetector(
          onTap: _isBusy ? null : onTap,
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
                      color: hasMedia ? color : AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!hasMedia) ...[
                  const SizedBox(height: 2),
                  Text(hint,
                      style: AppTextStyles.caption,
                      textAlign: TextAlign.center),
                ],
                if (hasMedia) ...[
                  if (_mediaFileSizeBytes != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatSize(_mediaFileSizeBytes),
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textMuted),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  const Text('Tap to change', style: AppTextStyles.caption),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}