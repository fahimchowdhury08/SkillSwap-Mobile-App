
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../theme.dart';
import '../../supabase_service.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../widgets/gradient_avatar.dart';
import '../../widgets/loading_spinner.dart';

class ChatScreen extends StatefulWidget {
  final String swapId;
  final UserModel otherUser;

  const ChatScreen({
    super.key,
    required this.swapId,
    required this.otherUser,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // ── Controllers ───────────────────────────────────────────────
  final _messageController = TextEditingController();
  final _scrollController  = ScrollController();

  // ── State ──────────────────────────────────────────────────────
  final List<MessageModel> _messages = [];
  bool _isLoading   = true;
  bool _isSending   = false;
  bool _isUploading = false;
  String? _currentUserName;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeToMessages();
    _loadCurrentUserName();
  }

  @override
  void dispose() {
    if (_channel != null) {
      SupabaseService.client.removeChannel(_channel!);
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Load current user name ─────────────────────────────────────
  Future<void> _loadCurrentUserName() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      final res = await SupabaseService.client
          .from('users')
          .select('full_name')
          .eq('id', userId)
          .single();
      setState(() => _currentUserName = res['full_name']);
    } catch (e) {
      debugPrint('Load name error: $e');
    }
  }

  // ── Load existing messages ─────────────────────────────────────
  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final res = await SupabaseService.client
          .from('messages')
          .select()
          .eq('swap_id', widget.swapId)
          .order('created_at');

      setState(() {
        _messages.clear();
        _messages.addAll(
          (res as List).map((j) => MessageModel.fromJson(j)),
        );
      });

      // Mark all as read
      await SupabaseService.client
          .from('messages')
          .update({'is_read': true})
          .eq('swap_id', widget.swapId)
          .neq('sender_id', SupabaseService.currentUserId!);

      _scrollToBottom();

    } catch (e) {
      debugPrint('Load messages error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Subscribe to realtime messages ────────────────────────────
  void _subscribeToMessages() {
    _channel = SupabaseService.client
        .channel('messages:${widget.swapId}')
        .onPostgresChanges(
          event:  PostgresChangeEvent.insert,
          schema: 'public',
          table:  'messages',
          filter: PostgresChangeFilter(
            type:   PostgresChangeFilterType.eq,
            column: 'swap_id',
            value:  widget.swapId,
          ),
          callback: (payload) {
            final msg = MessageModel.fromJson(payload.newRecord);
            // Only add if not already in list
            final exists = _messages.any((m) => m.id == msg.id);
            if (!exists) {
              setState(() => _messages.add(msg));
              _scrollToBottom();
            }
          },
        )
        .subscribe();
  }

  // ── Scroll to bottom ───────────────────────────────────────────
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Send text message ──────────────────────────────────────────
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    setState(() => _isSending = true);

    try {
      final currentUserId = SupabaseService.currentUserId!;

      await SupabaseService.client.from('messages').insert({
        'swap_id':      widget.swapId,
        'sender_id':    currentUserId,
        'content':      text,
        'message_type': 'text',
        'is_read':      false,
      });

      // Send notification
      await SupabaseService.sendNotification(
        userId: widget.otherUser.id,
        type:   'message_received',
        title:  '${_currentUserName ?? 'Someone'}: $text',
        body:   text,
        data:   {'swap_id': widget.swapId},
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send message. Please try again.'),
          backgroundColor: AppColors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── Show attachment picker ─────────────────────────────────────
  void _showAttachmentPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              leading: const Icon(
                Icons.image_outlined,
                color: AppColors.indigo,
              ),
              title: const Text(
                'Send Image',
                style: AppTextStyles.bodyBold,
              ),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.insert_drive_file_outlined,
                color: AppColors.coral,
              ),
              title: const Text(
                'Send Document',
                style: AppTextStyles.bodyBold,
              ),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendFile();
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  // ── Pick and send image ────────────────────────────────────────
  Future<void> _pickAndSendImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (picked == null) return;

      setState(() => _isUploading = true);

      final bytes    = await File(picked.path).readAsBytes();
      final fileName =
          'chat_${widget.swapId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await SupabaseService.client.storage
          .from('chat-media')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      final url = SupabaseService.client.storage
          .from('chat-media')
          .getPublicUrl(fileName);

      await SupabaseService.client.from('messages').insert({
        'swap_id':      widget.swapId,
        'sender_id':    SupabaseService.currentUserId!,
        'content':      '📷 Image',
        'message_type': 'image',
        'file_url':     url,
        'is_read':      false,
      });

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send image. Please try again.'),
          backgroundColor: AppColors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── Pick and send file ─────────────────────────────────────────
  Future<void> _pickAndSendFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      setState(() => _isUploading = true);

      late final Uint8List bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      } else {
        return;
      }

      final fileName =
          'chat_${widget.swapId}_${DateTime.now().millisecondsSinceEpoch}.${file.extension}';

      await SupabaseService.client.storage
          .from('chat-media')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final url = SupabaseService.client.storage
          .from('chat-media')
          .getPublicUrl(fileName);

      await SupabaseService.client.from('messages').insert({
        'swap_id':      widget.swapId,
        'sender_id':    SupabaseService.currentUserId!,
        'content':      '📄 ${file.name}',
        'message_type': 'file',
        'file_url':     url,
        'is_read':      false,
      });

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send file. Please try again.'),
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
        title: Row(
          children: [
            GradientAvatar(
              imageUrl: widget.otherUser.avatarUrl,
              name: widget.otherUser.displayName,
              size: 36,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUser.displayName,
                    style: AppTextStyles.bodyBold,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'Tap to view profile',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Video call button
          IconButton(
            icon: const Icon(
              Icons.videocam_rounded,
              color: AppColors.indigo,
            ),
            onPressed: () {
              // TODO: replace when video call is built
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Video call — coming soon'),
                  backgroundColor: AppColors.indigo,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [

          // ── Messages list ──────────────────────────────
          Expanded(
            child: _isLoading
                ? const LoadingSpinner()
                : _buildMessagesList(),
          ),

          // ── Upload indicator ───────────────────────────
          if (_isUploading)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              color: AppColors.cardSurface,
              child: const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.indigo,
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    'Uploading...',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),

          // ── Input bar ─────────────────────────────────
          _buildInputBar(),

        ],
      ),
    );
  }

  // ── Messages list ──────────────────────────────────────────────
  Widget _buildMessagesList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GradientAvatar(
              imageUrl: widget.otherUser.avatarUrl,
              name: widget.otherUser.displayName,
              size: 64,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              widget.otherUser.displayName,
              style: AppTextStyles.heading3,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              "You're both connected! Start swapping skills 🤝",
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message  = _messages[index];
        final isMine   = message.senderId ==
            SupabaseService.currentUserId;
        final showTime = index == 0 ||
            message.createdAt
                .difference(_messages[index - 1].createdAt)
                .inMinutes > 15;

        return Column(
          children: [
            if (showTime)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  timeago.format(message.createdAt),
                  style: AppTextStyles.caption,
                ),
              ),
            _buildBubble(message, isMine),
          ],
        );
      },
    );
  }

  // ── Message bubble ─────────────────────────────────────────────
  Widget _buildBubble(MessageModel message, bool isMine) {
    return Align(
      alignment: isMine
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: AppSpacing.xs,
          bottom: AppSpacing.xs,
          left:  isMine ? 60 : 0,
          right: isMine ? 0  : 60,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isMine
              ? AppColors.indigo
              : AppColors.cardSurface,
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(16),
            topRight:    const Radius.circular(16),
            bottomLeft:  Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4  : 16),
          ),
        ),
        child: _buildBubbleContent(message),
      ),
    );
  }

  // ── Bubble content ─────────────────────────────────────────────
  Widget _buildBubbleContent(MessageModel message) {
    switch (message.messageType) {
      case 'image':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.fileUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  message.fileUrl!,
                  width: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
          ],
        );

      case 'file':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.insert_drive_file_outlined,
              color: AppColors.textPrimary,
              size: 18,
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                message.content,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        );

      default:
        return Text(
          message.content,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w400,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        );
    }
  }

  // ── Input bar ──────────────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left:   AppSpacing.md,
        right:  AppSpacing.md,
        top:    AppSpacing.sm,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        border: Border(
          top: BorderSide(color: AppColors.elevated),
        ),
      ),
      child: Row(
        children: [

          // ── Attachment button ──────────────────────
          IconButton(
            icon: const Icon(
              Icons.attach_file_rounded,
              color: AppColors.textMuted,
            ),
            onPressed: _isUploading
                ? null
                : _showAttachmentPicker,
          ),

          // ── Book session button ────────────────────
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: AppColors.indigo,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Book session — coming soon'),
                  backgroundColor: AppColors.indigo,
                ),
              );
            },
          ),

          // ── Text field ─────────────────────────────
          Expanded(
            child: TextField(
              controller: _messageController,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textPrimary,
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(
                  color: AppColors.textMuted,
                  fontFamily: 'Nunito',
                  fontSize: 14,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
              ),
            ),
          ),

          // ── Send button ────────────────────────────
          GestureDetector(
            onTap: _isSending ? null : _sendMessage,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.coral,
                shape: BoxShape.circle,
              ),
              child: _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
            ),
          ),

        ],
      ),
    );
  }
}