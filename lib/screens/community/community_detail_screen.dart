import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme.dart';
import '../../supabase_service.dart';
import '../../models/community_model.dart';
import '../../models/community_post_model.dart';
import '../../widgets/gradient_avatar.dart';
import '../../widgets/loading_spinner.dart';
import '../../widgets/empty_state.dart';
import 'admin_actions_screen.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';

class CommunityDetailScreen extends StatefulWidget {
  final String communityId;
  final String role; // 'admin' | 'moderator' | 'member' | 'guest'

  const CommunityDetailScreen({
    super.key,
    required this.communityId,
    required this.role,
  });

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  CommunityModel? _community;
  List<CommunityPostModel> _posts = [];
  bool _isLoading = true;

  final Set<String> _likedPostIds = {};

  bool get _canPost =>
      widget.role == 'admin' ||
      widget.role == 'moderator' ||
      widget.role == 'member';

  bool get _canManage =>
      widget.role == 'admin' || widget.role == 'moderator';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final commRes = await SupabaseService.client
          .from('communities')
          .select()
          .eq('id', widget.communityId)
          .single();

      final postsRes = await SupabaseService.client
          .from('community_posts')
          .select('*, users(full_name, avatar_url)')
          .eq('community_id', widget.communityId)
          .order('created_at', ascending: false);

      final uid = SupabaseService.currentUserId;
      if (uid != null) {
        final likedRes = await SupabaseService.client
            .from('post_likes')
            .select('post_id')
            .eq('user_id', uid);
        setState(() {
          _likedPostIds.clear();
          for (final r in likedRes as List) {
            _likedPostIds.add(r['post_id'] as String);
          }
        });
      }

      setState(() {
        _community = CommunityModel.fromJson(commRes);
        _posts = (postsRes as List)
            .map((j) => CommunityPostModel.fromJson(j))
            .toList();
      });
    } catch (e) {
      debugPrint('Community detail load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Like toggle ────────────────────────────────────────────────
  Future<void> _toggleLike(CommunityPostModel post) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;

    final wasLiked = _likedPostIds.contains(post.id);
    setState(() {
      if (wasLiked) {
        _likedPostIds.remove(post.id);
        final idx = _posts.indexWhere((p) => p.id == post.id);
        if (idx != -1) {
          _posts[idx] = CommunityPostModel.fromJson({
            ..._posts[idx].toJson(),
            'like_count': (_posts[idx].likeCount - 1).clamp(0, 9999),
            'users': {
              'full_name': _posts[idx].posterName,
              'avatar_url': _posts[idx].posterAvatarUrl,
            },
          });
        }
      } else {
        _likedPostIds.add(post.id);
        final idx = _posts.indexWhere((p) => p.id == post.id);
        if (idx != -1) {
          _posts[idx] = CommunityPostModel.fromJson({
            ..._posts[idx].toJson(),
            'like_count': _posts[idx].likeCount + 1,
            'users': {
              'full_name': _posts[idx].posterName,
              'avatar_url': _posts[idx].posterAvatarUrl,
            },
          });
        }
      }
    });

    try {
      if (wasLiked) {
        await SupabaseService.client
            .from('post_likes')
            .delete()
            .eq('post_id', post.id)
            .eq('user_id', uid);
        await SupabaseService.client
            .from('community_posts')
            .update({'like_count': post.likeCount - 1})
            .eq('id', post.id);
      } else {
        await SupabaseService.client
            .from('post_likes')
            .insert({'post_id': post.id, 'user_id': uid});
        await SupabaseService.client
            .from('community_posts')
            .update({'like_count': post.likeCount + 1})
            .eq('id', post.id);
      }
    } catch (e) {
      setState(() {
        if (wasLiked) {
          _likedPostIds.add(post.id);
        } else {
          _likedPostIds.remove(post.id);
        }
      });
    }
  }

  // ── Delete post ────────────────────────────────────────────────
  Future<void> _deletePost(CommunityPostModel post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        title: const Text('Delete Post', style: AppTextStyles.heading3),
        content: const Text(
            'This post will be permanently deleted.', style: AppTextStyles.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted, fontFamily: 'Nunito')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.red, fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await SupabaseService.client
          .from('community_posts')
          .delete()
          .eq('id', post.id);
      setState(() => _posts.removeWhere((p) => p.id == post.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Post deleted'), backgroundColor: AppColors.indigo),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.red),
      );
    }
  }

  // ── Delete community ───────────────────────────────────────────
  Future<void> _deleteCommunity() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        title: const Text('Delete Community', style: AppTextStyles.heading3),
        content: const Text(
          'All posts, members and data will be permanently deleted. This cannot be undone.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted, fontFamily: 'Nunito')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.red, fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await SupabaseService.client
          .from('communities')
          .delete()
          .eq('id', widget.communityId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Community deleted'),
            backgroundColor: AppColors.indigo),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.red),
      );
    }
  }

  // ── Open URL ───────────────────────────────────────────────────
  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Open URL error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const LoadingSpinner()
          : _community == null
              ? const Center(
                  child: Text('Community not found', style: AppTextStyles.body))
              : _buildContent(),
      floatingActionButton: _canPost
          ? FloatingActionButton(
              backgroundColor: AppColors.coral,
              child: const Icon(Icons.add_rounded, color: Colors.white),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CreatePostScreen(communityId: widget.communityId),
                ),
              ).then((_) => _load()),
            )
          : null,
    );
  }

  Widget _buildContent() {
    final c = _community!;
    return RefreshIndicator(
      color: AppColors.indigo,
      backgroundColor: AppColors.cardSurface,
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── App bar ───────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: AppColors.background,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded,
                  color: AppColors.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (_canManage)
                IconButton(
                  icon: const Icon(Icons.people_alt_outlined,
                      color: AppColors.textPrimary),
                  tooltip: 'Manage Members',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminActionsScreen(
                          communityId: widget.communityId),
                    ),
                  ).then((_) => _load()),
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppColors.textPrimary),
                color: AppColors.cardSurface,
                onSelected: (val) {
                  if (val == 'delete' && widget.role == 'admin') {
                    _deleteCommunity();
                  }
                },
                itemBuilder: (_) => [
                  if (widget.role == 'admin')
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              color: AppColors.red, size: 18),
                          SizedBox(width: 8),
                          Text('Delete Community',
                              style: TextStyle(
                                  fontFamily: 'Nunito',
                                  color: AppColors.red,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHero(c),
            ),
          ),

          // ── Posts ─────────────────────────────────────────────
          if (_posts.isEmpty)
            SliverFillRemaining(
              child: EmptyState(
                icon: Icons.post_add_rounded,
                title: 'No posts yet',
                subtitle: _canPost
                    ? 'Be the first to share something!'
                    : 'No posts in this community yet',
                buttonLabel: _canPost ? 'Create Post' : null,
                onButtonTap: _canPost
                    ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreatePostScreen(
                                communityId: widget.communityId),
                          ),
                        ).then((_) => _load())
                    : null,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.md),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _buildPostCard(_posts[i]),
                  ),
                  childCount: _posts.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Hero header ────────────────────────────────────────────────
  Widget _buildHero(CommunityModel c) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.indigo.withValues(alpha: 0.3),
            AppColors.background,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(72, 16, 16, 16),
          child: Row(
            children: [
              _buildCommunityIcon(c, 64),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(c.name,
                        style: AppTextStyles.heading2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (c.description != null)
                      Text(c.description!,
                          style: AppTextStyles.caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people_outline_rounded,
                                size: 12, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text('${c.memberCount} members',
                                style: AppTextStyles.caption),
                          ],
                        ),
                        if (c.skillTag != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.coral.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(c.skillTag!,
                                style: const TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.coral)),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: _roleColor(widget.role)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            _roleLabel(widget.role),
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _roleColor(widget.role),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':     return AppColors.gold;
      case 'moderator': return AppColors.indigo;
      case 'member':    return AppColors.green;
      default:          return AppColors.textMuted;
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':     return ' Admin';
      case 'moderator': return ' Mod';
      case 'member':    return ' Member';
      default:          return 'Guest';
    }
  }

  Widget _buildCommunityIcon(CommunityModel c, double size) {
    if (c.avatarUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: CachedNetworkImage(
          imageUrl: c.avatarUrl!,
          width: size, height: size,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _fallbackIcon(c, size),
        ),
      );
    }
    return _fallbackIcon(c, size);
  }

  Widget _fallbackIcon(CommunityModel c, double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: AppColors.indigoCoralGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
            fontSize: size * 0.4,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ── Post card ──────────────────────────────────────────────────
  Widget _buildPostCard(CommunityPostModel post) {
    final isLiked = _likedPostIds.contains(post.id);

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
                  size: 38,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.posterDisplayName, style: AppTextStyles.bodyBold),
                      Text(timeago.format(post.createdAt),
                          style: AppTextStyles.caption),
                    ],
                  ),
                ),
                if (_canManage)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.red, size: 20),
                    onPressed: () => _deletePost(post),
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

          // Content
          _buildPostContent(post),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _toggleLike(post),
                  child: Row(
                    children: [
                      Icon(
                        isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 20,
                        color: isLiked ? AppColors.coral : AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text('${post.likeCount}', style: AppTextStyles.caption),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PostDetailScreen(
                        post: post,
                        canManage: _canManage,
                      ),
                    ),
                  ).then((_) => _load()),
                  child: const Row(
                    children: [
                      Icon(Icons.comment_outlined,
                          size: 20, color: AppColors.textMuted),
                      SizedBox(width: 4),
                      Text('Comment', style: AppTextStyles.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Post content by type ───────────────────────────────────────
  Widget _buildPostContent(CommunityPostModel post) {
    if (post.isImage && post.fileUrl != null) {
      return GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _FullScreenImageScreen(imageUrl: post.fileUrl!),
          ),
        ),
        child: Hero(
          tag: post.fileUrl!,
          child: CachedNetworkImage(
            imageUrl: post.fileUrl!,
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              height: 220,
              color: AppColors.elevated,
              child: const Center(
                child: CircularProgressIndicator(
                    color: AppColors.indigo, strokeWidth: 2),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              height: 80,
              color: AppColors.elevated,
              child: const Center(
                child: Icon(Icons.broken_image_outlined,
                    color: AppColors.textMuted),
              ),
            ),
          ),
        ),
      );
    }

    if (post.isVideo && post.fileUrl != null) {
      return _InlineVideoPlayer(videoUrl: post.fileUrl!);
    }

    if (post.isFile && post.fileUrl != null) {
      return GestureDetector(
        onTap: () => _openUrl(post.fileUrl!),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.elevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.insert_drive_file_outlined,
                  color: AppColors.indigo, size: 24),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Tap to open document', style: AppTextStyles.body),
              ),
              Icon(Icons.open_in_new_rounded,
                  color: AppColors.textMuted, size: 16),
            ],
          ),
        ),
      );
    }

    if (post.isArticle && post.articleUrl != null) {
      return GestureDetector(
        onTap: () => _openUrl(post.articleUrl!),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.indigo.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: AppColors.indigo.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.link_rounded, color: AppColors.indigo, size: 20),
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
        ),
      );
    }

    if (post.isYoutube && post.articleUrl != null) {
      return GestureDetector(
        onTap: () => _openUrl(post.articleUrl!),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          height: 100,
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.smart_display_rounded, color: Colors.red, size: 36),
                SizedBox(height: 4),
                Text('Tap to watch on YouTube', style: AppTextStyles.caption),
              ],
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

// ══════════════════════════════════════════════════════════════════
// Fullscreen Image Viewer
// ══════════════════════════════════════════════════════════════════
class _FullScreenImageScreen extends StatelessWidget {
  final String imageUrl;
  const _FullScreenImageScreen({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PhotoView(
        imageProvider: NetworkImage(imageUrl),
        heroAttributes: PhotoViewHeroAttributes(tag: imageUrl),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Inline Video Preview — shows first frame as thumbnail
// ══════════════════════════════════════════════════════════════════
class _InlineVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const _InlineVideoPlayer({required this.videoUrl});

  @override
  State<_InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<_InlineVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _initThumbnail();
  }

  Future<void> _initThumbnail() async {
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );
    await _controller.initialize();
    // Seek to first frame so it shows as thumbnail
    await _controller.seekTo(Duration.zero);
    if (mounted) setState(() => _isReady = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _FullScreenVideoScreen(videoUrl: widget.videoUrl),
          fullscreenDialog: true,
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 220,
        child: Stack(
          fit: StackFit.expand,
          children: [

            // ── Thumbnail (first frame) or black bg ─────────────
            if (_isReady)
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              )
            else
              Container(
                color: Colors.black,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.coral,
                    strokeWidth: 2,
                  ),
                ),
              ),

            // ── Dark overlay so play button is visible ──────────
            Container(
              color: Colors.black.withValues(alpha: 0.25),
            ),

            // ── Coral play button ───────────────────────────────
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.coral.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.coral.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),

            // ── "Tap to play" pill ──────────────────────────────
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fullscreen_rounded,
                        color: Colors.white, size: 15),
                    SizedBox(width: 4),
                    Text(
                      'Tap to play',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Fullscreen Video Player Screen
// ══════════════════════════════════════════════════════════════════
class _FullScreenVideoScreen extends StatefulWidget {
  final String videoUrl;
  const _FullScreenVideoScreen({required this.videoUrl});

  @override
  State<_FullScreenVideoScreen> createState() =>
      _FullScreenVideoScreenState();
}

class _FullScreenVideoScreenState extends State<_FullScreenVideoScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPlaying     = false;
  bool _showControls  = true;

  @override
  void initState() {
    super.initState();
    // Force landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    )..initialize().then((_) {
        if (mounted) {
          setState(() => _isInitialized = true);
          _controller.play();
          setState(() => _isPlaying = true);
          _scheduleHideControls();
        }
      });

    _controller.addListener(() {
      if (mounted) setState(() => _isPlaying = _controller.value.isPlaying);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    // Restore portrait
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _showControls = true;
      } else {
        _controller.play();
        _scheduleHideControls();
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls && _controller.value.isPlaying) {
      _scheduleHideControls();
    }
  }

  void _scheduleHideControls() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [

            // ── Video ──────────────────────────────────────────
            Center(
              child: _isInitialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    )
                  : const CircularProgressIndicator(
                      color: AppColors.coral, strokeWidth: 2),
            ),

            // ── Controls overlay ───────────────────────────────
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [

                      // ── Top: close button ────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: Colors.white, size: 28),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),

                      // ── Center: play/pause ───────────────────
                      Expanded(
                        child: Center(
                          child: GestureDetector(
                            onTap: _togglePlay,
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 44,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ── Bottom: scrub + timestamps ───────────
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            VideoProgressIndicator(
                              _controller,
                              allowScrubbing: true,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8),
                              colors: const VideoProgressColors(
                                playedColor:     AppColors.coral,
                                bufferedColor:   Colors.white38,
                                backgroundColor: Colors.white24,
                              ),
                            ),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(
                                      _controller.value.position),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontFamily: 'Nunito',
                                  ),
                                ),
                                Text(
                                  _formatDuration(
                                      _controller.value.duration),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontFamily: 'Nunito',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    ],
                  ),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}