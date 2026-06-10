
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme.dart';
import '../../supabase_service.dart';
import '../../models/community_post_model.dart';
import '../../widgets/gradient_avatar.dart';
import '../../widgets/loading_spinner.dart';

class PostDetailScreen extends StatefulWidget {
  final CommunityPostModel post;
  final bool canManage;

  const PostDetailScreen({
    super.key,
    required this.post,
    required this.canManage,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _commentController = TextEditingController();
  final _scrollController  = ScrollController();

  List<Map<String, dynamic>> _comments = [];
  bool _isLoading  = true;
  bool _isSending  = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final res = await SupabaseService.client
          .from('post_comments')
          .select('*, users(full_name, avatar_url)')
          .eq('post_id', widget.post.id)
          .order('created_at');

      setState(() {
        _comments = (res as List)
            .map((j) => Map<String, dynamic>.from(j))
            .toList();
      });
    } catch (e) {
      debugPrint('Load comments error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final uid = SupabaseService.currentUserId;
    if (uid == null) return;

    setState(() => _isSending = true);
    _commentController.clear();

    try {
      final res = await SupabaseService.client
          .from('post_comments')
          .insert({
            'post_id':  widget.post.id,
            'user_id':  uid,
            'content':  text,
          })
          .select('*, users(full_name, avatar_url)')
          .single();

      setState(() => _comments.add(Map<String, dynamic>.from(res)));

      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.red),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await SupabaseService.client
          .from('post_comments')
          .delete()
          .eq('id', commentId);
      setState(() =>
          _comments.removeWhere((c) => c['id'] == commentId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.red),
      );
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
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Post', style: AppTextStyles.heading2),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const LoadingSpinner()
                : ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      // ── Post card ──────────────────────────────
                      _buildPostCard(),
                      const SizedBox(height: AppSpacing.lg),

                      // ── Comments heading ───────────────────────
                      Text(
                        '${_comments.length} Comment${_comments.length == 1 ? '' : 's'}',
                        style: AppTextStyles.heading3,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // ── Comments ───────────────────────────────
                      if (_comments.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          child: Center(
                            child: Text(
                              'No comments yet. Be the first!',
                              style: AppTextStyles.body,
                            ),
                          ),
                        )
                      else
                        ..._comments.map((c) => _buildCommentRow(c)),

                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
          ),

          // ── Comment input ──────────────────────────────────────
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildPostCard() {
    final post = widget.post;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.elevated),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                GradientAvatar(
                  imageUrl: post.posterAvatarUrl,
                  name: post.posterDisplayName,
                  size: 40,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.posterDisplayName,
                          style: AppTextStyles.bodyBold),
                      Text(timeago.format(post.createdAt),
                          style: AppTextStyles.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Caption
          if (post.caption != null && post.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(post.caption!, style: AppTextStyles.body),
            ),

          const SizedBox(height: AppSpacing.sm),

          // Media
          _buildMedia(post),

          // Like count
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                const Icon(Icons.favorite_rounded,
                    size: 16, color: AppColors.coral),
                const SizedBox(width: 4),
                Text('${post.likeCount} likes', style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedia(CommunityPostModel post) {
    if (post.isImage && post.fileUrl != null) {
      return CachedNetworkImage(
        imageUrl: post.fileUrl!,
        width: double.infinity,
        height: 220,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    if ((post.isVideo || post.isFile) && post.fileUrl != null) {
      return GestureDetector(
        onTap: () {/* open url */},
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.elevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Icon(Icons.play_circle_outline_rounded,
                size: 40, color: AppColors.indigo),
          ),
        ),
      );
    }
    if ((post.isArticle || post.isYoutube) && post.articleUrl != null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.indigo.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              post.isYoutube
                  ? Icons.smart_display_rounded
                  : Icons.link_rounded,
              color: AppColors.indigo,
              size: 18,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                post.articleUrl!,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  color: AppColors.indigo,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildCommentRow(Map<String, dynamic> comment) {
    final user      = comment['users'] as Map<String, dynamic>? ?? {};
    final name      = user['full_name'] as String? ?? 'User';
    final avatar    = user['avatar_url'] as String?;
    final content   = comment['content'] as String? ?? '';
    final createdAt = DateTime.tryParse(comment['created_at'] ?? '') ??
        DateTime.now();
    final commentId = comment['id'] as String? ?? '';
    final uid       = SupabaseService.currentUserId;
    final isOwn     = comment['user_id'] == uid;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GradientAvatar(imageUrl: avatar, name: name, size: 34),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(name, style: AppTextStyles.bodyBold),
                      const Spacer(),
                      Text(timeago.format(createdAt),
                          style: AppTextStyles.caption.copyWith(fontSize: 10)),
                      if (isOwn || widget.canManage) ...[
                        const SizedBox(width: AppSpacing.xs),
                        GestureDetector(
                          onTap: () => _deleteComment(commentId),
                          child: const Icon(Icons.delete_outline_rounded,
                              size: 14, color: AppColors.red),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(content, style: AppTextStyles.body),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.only(
        left:   AppSpacing.md,
        right:  AppSpacing.md,
        top:    AppSpacing.sm,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        border: Border(top: BorderSide(color: AppColors.elevated)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendComment(),
              decoration: const InputDecoration(
                hintText: 'Add a comment...',
                hintStyle: TextStyle(
                    color: AppColors.textMuted, fontFamily: 'Nunito'),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            onTap: _isSending ? null : _sendComment,
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.coral,
                shape: BoxShape.circle,
              ),
              child: _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}