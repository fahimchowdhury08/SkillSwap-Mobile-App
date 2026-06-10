import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:photo_view/photo_view.dart';
import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../../theme.dart';
import '../../supabase_service.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../widgets/gradient_avatar.dart';
import '../../widgets/loading_spinner.dart';
import '../video_call/prejoin_screen.dart';
import '../schedule/book_session_screen.dart';

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
  final _messageController = TextEditingController();
  final _scrollController  = ScrollController();

  final List<MessageModel> _messages = [];
  final List<Map<String, dynamic>> _pendingAttachments = [];

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
    if (_channel != null) SupabaseService.client.removeChannel(_channel!);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserName() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      final res = await SupabaseService.client
          .from('users').select('full_name').eq('id', userId).single();
      setState(() => _currentUserName = res['full_name']);
    } catch (e) { debugPrint('Load name error: $e'); }
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final res = await SupabaseService.client
          .from('messages').select()
          .eq('swap_id', widget.swapId)
          .order('created_at', ascending: true);

      setState(() {
        _messages.clear();
        _messages.addAll((res as List).map((j) => MessageModel.fromJson(j)));
      });

      await SupabaseService.client
          .from('messages').update({'is_read': true})
          .eq('swap_id', widget.swapId)
          .neq('sender_id', SupabaseService.currentUserId!);

      _scrollToBottom();
    } catch (e) { debugPrint('Load messages error: $e'); }
    finally { if (mounted) setState(() => _isLoading = false); }
  }

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
            final msg    = MessageModel.fromJson(payload.newRecord);
            final exists = _messages.any((m) => m.id == msg.id);
            if (!exists) {
              setState(() => _messages.add(msg));
              _scrollToBottom();
            }
          },
        ).subscribe();
  }

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

  // ── Video call ─────────────────────────────────────────────────
  Future<void> _startVideoCall() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PrejoinScreen(
        swapId:          widget.swapId,
        otherUser:       widget.otherUser,
        currentUserName: _currentUserName ?? 'Me',
        sessionId:       null,
      ),
    ));
  }

  // ── Book session — opens BookSessionScreen ─────────────────────
  void _openBookSession() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => BookSessionScreen(
        swapId:       widget.swapId,
        otherUserId:  widget.otherUser.id,
        otherUserName: widget.otherUser.displayName,
      ),
    )).then((success) {
      if (success == true) _loadMessages();
    });
  }

  // ── Edit existing session proposal ────────────────────────────
  void _editProposal(Map<String, dynamic>? metadata) {
    if (metadata == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => BookSessionScreen(
        swapId:           widget.swapId,
        otherUserId:      widget.otherUser.id,
        otherUserName:    widget.otherUser.displayName,
        editingSessionId: metadata['session_id'] as String?,
        existingData:     {
          'scheduled_at':  metadata['scheduled_at'],
          'topic':         metadata['topic'],
          'duration_mins': metadata['duration_mins'],
        },
      ),
    )).then((success) {
      if (success == true) _loadMessages();
    });
  }

  // ── Accept session proposal ───────────────────────────────────
  Future<void> _acceptProposal(String? sessionId) async {
    if (sessionId == null) return;
    try {
      await SupabaseService.client
          .from('sessions')
          .update({'status': 'upcoming'})
          .eq('id', sessionId);

      // Notify proposer
      final session = await SupabaseService.client
          .from('sessions').select().eq('id', sessionId).single();

      await SupabaseService.sendNotification(
        userId: session['proposed_by'] as String,
        type:   'session_accepted',
        title:  '${widget.otherUser.displayName} accepted your session! 🎉',
        body:   'Session added to both schedules.',
        data:   {'swap_id': widget.swapId},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session confirmed! Added to schedule ✓'),
          backgroundColor: AppColors.green,
        ),
      );
      setState(() {}); // Rebuild to show updated status
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not accept: $e'), backgroundColor: AppColors.red),
      );
    }
  }

  // ── Reject session proposal ───────────────────────────────────
  Future<void> _rejectProposal(String? sessionId) async {
    if (sessionId == null) return;
    try {
      await SupabaseService.client
          .from('sessions')
          .update({'status': 'rejected'})
          .eq('id', sessionId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session proposal declined'),
          backgroundColor: AppColors.indigo,
        ),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not reject: $e'), backgroundColor: AppColors.red),
      );
    }
  }

  // ── Get session status from DB ────────────────────────────────
  Future<String> _getSessionStatus(String? sessionId) async {
    if (sessionId == null) return 'pending';
    try {
      final res = await SupabaseService.client
          .from('sessions').select('status').eq('id', sessionId).single();
      return res['status'] as String? ?? 'pending';
    } catch (_) { return 'pending'; }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (_pendingAttachments.isNotEmpty) { await _sendPendingAttachments(); return; }
    if (text.isEmpty) return;
    _messageController.clear();
    setState(() => _isSending = true);
    try {
      await SupabaseService.client.from('messages').insert({
        'swap_id':      widget.swapId,
        'sender_id':    SupabaseService.currentUserId!,
        'content':      text,
        'message_type': 'text',
        'is_read':      false,
      });
      await SupabaseService.sendNotification(
        userId: widget.otherUser.id,
        type:   'message_received',
        title:  '${_currentUserName ?? 'Someone'}: $text',
        body:   text,
        data:   {'swap_id': widget.swapId},
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not send message. Please try again.'),
        backgroundColor: AppColors.red,
      ));
    } finally { if (mounted) setState(() => _isSending = false); }
  }

  void _showAttachmentPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.elevated, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              leading: const Icon(Icons.image_outlined, color: AppColors.indigo),
              title: const Text('Add Images', style: AppTextStyles.bodyBold),
              subtitle: const Text('Pick one or more images', style: AppTextStyles.caption),
              onTap: () { Navigator.pop(context); _pickImages(); },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined, color: AppColors.coral),
              title: const Text('Add Documents', style: AppTextStyles.bodyBold),
              subtitle: const Text('Pick one or more PDF/DOC files', style: AppTextStyles.caption),
              onTap: () { Navigator.pop(context); _pickFiles(); },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImages() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickMultiImage(imageQuality: 70);
      if (picked.isEmpty) return;
      for (final img in picked) {
        final bytes = await img.readAsBytes();
        setState(() => _pendingAttachments.add({'type': 'image', 'name': img.name, 'bytes': bytes}));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick images: $e'), backgroundColor: AppColors.red));
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx', 'txt'], allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;
      for (final file in result.files) {
        late Uint8List bytes;
        if (file.bytes != null) { bytes = file.bytes!; }
        else if (file.path != null) { bytes = await File(file.path!).readAsBytes(); }
        else { continue; }
        setState(() => _pendingAttachments.add({
          'type': 'file', 'name': file.name, 'bytes': bytes, 'ext': file.extension ?? 'pdf',
        }));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick files: $e'), backgroundColor: AppColors.red));
    }
  }

  void _removePending(int index) => setState(() => _pendingAttachments.removeAt(index));

  Future<void> _sendPendingAttachments() async {
    if (_pendingAttachments.isEmpty) return;
    setState(() => _isUploading = true);
    try {
      for (final attachment in _pendingAttachments) {
        final bytes   = attachment['bytes'] as Uint8List;
        final name    = attachment['name'] as String;
        final type    = attachment['type'] as String;
        final isImage = type == 'image';
        final ext     = isImage ? 'jpg' : (attachment['ext'] as String? ?? 'pdf');
        final fileName = 'chat_${widget.swapId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        await SupabaseService.client.storage.from('chat-media').uploadBinary(
          fileName, bytes,
          fileOptions: FileOptions(
            contentType: isImage ? 'image/jpeg' : 'application/octet-stream', upsert: true,
          ),
        );
        final url = SupabaseService.client.storage.from('chat-media').getPublicUrl(fileName);
        await SupabaseService.client.from('messages').insert({
          'swap_id':      widget.swapId,
          'sender_id':    SupabaseService.currentUserId!,
          'content':      isImage ? '📷 Image' : name,
          'message_type': isImage ? 'image' : 'file',
          'file_url':     url,
          'is_read':      false,
        });
      }
      setState(() => _pendingAttachments.clear());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All files sent ✓'), backgroundColor: AppColors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send files: $e'), backgroundColor: AppColors.red));
    } finally { if (mounted) setState(() => _isUploading = false); }
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) { debugPrint('Open URL error: $e'); }
  }

  Future<void> _downloadUrl(String url) async {
    try {
      final downloadUrl = url.contains('?') ? '$url&download=1' : '$url?download=1';
      final uri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) { debugPrint('Download URL error: $e'); }
  }

  void _openImageFullScreen(String url) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _FullScreenImageViewer(
        imageUrl: url, onDownload: () => _saveImageToGallery(url),
      ),
    ));
  }

  Future<void> _saveImageToGallery(String url) async {
    try {
      PermissionStatus status;
      if (Platform.isAndroid) {
        final v = await _getAndroidVersion();
        status = v >= 33 ? await Permission.photos.request() : await Permission.storage.request();
      } else { status = await Permission.photos.request(); }
      if (!status.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Storage permission denied'), backgroundColor: AppColors.red));
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Saving image...'), backgroundColor: AppColors.indigo, duration: Duration(seconds: 1)));
      final dio = Dio();
      final res = await dio.get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
      final dir = await getExternalStorageDirectory();
      final savePath = '${dir!.path}/SkillSwap_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(savePath).writeAsBytes(res.data!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Image saved to Downloads ✓'), backgroundColor: AppColors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save image: $e'), backgroundColor: AppColors.red));
    }
  }

  Future<void> _openDocumentMobile(String url, String fileName) async {
  try {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Opening document...'), backgroundColor: AppColors.indigo, duration: Duration(seconds: 1)));
    final dio = Dio();
      final dir = await getTemporaryDirectory();
      await dio.download(url, '${dir.path}/$fileName');
      await OpenFile.open('${dir.path}/$fileName');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open document: $e'), backgroundColor: AppColors.red));
    }
  }

  Future<void> _downloadDocumentMobile(String url, String fileName) async {
    try {
      PermissionStatus status;
      if (Platform.isAndroid) {
        final v = await _getAndroidVersion();
        status = v >= 33 ? PermissionStatus.granted : await Permission.storage.request();
      } else { status = await Permission.storage.request(); }
      if (!status.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Storage permission denied'), backgroundColor: AppColors.red));
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Downloading...'), backgroundColor: AppColors.indigo, duration: Duration(seconds: 1)));
      final dio = Dio();
      final dir = await getExternalStorageDirectory();
      await dio.download(url, '${dir!.path}/$fileName');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$fileName saved ✓'), backgroundColor: AppColors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not download: $e'), backgroundColor: AppColors.red));
    }
  }

  Future<int> _getAndroidVersion() async {
    try {
      final sdkInt = await const MethodChannel('skillswap/android_version').invokeMethod<int>('getSdkInt');
      return sdkInt ?? 30;
    } catch (_) { return 30; }
  }

  Widget _buildDateHeader(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.elevated)),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
            decoration: BoxDecoration(color: AppColors.elevated, borderRadius: BorderRadius.circular(100)),
            child: Text(_formatDateHeader(date),
                style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600,
                    fontSize: 11, color: AppColors.textMuted)),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(child: Divider(color: AppColors.elevated)),
        ],
      ),
    );
  }

  String _formatDateHeader(DateTime date) {
    final now    = DateTime.now();
    final today  = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(date.year, date.month, date.day);
    final diff   = today.difference(msgDay).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) {
      const days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
      return days[date.weekday - 1];
    }
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    if (date.year == now.year) return '${date.day} ${months[date.month - 1]}';
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatTime(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            GradientAvatar(imageUrl: widget.otherUser.avatarUrl,
                name: widget.otherUser.displayName, size: 36),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.otherUser.displayName, style: AppTextStyles.bodyBold,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const Text('Tap to view profile', style: AppTextStyles.caption),
              ]),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_rounded, color: AppColors.indigo),
            onPressed: _startVideoCall, tooltip: 'Start video call',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _isLoading ? const LoadingSpinner() : _buildMessagesList()),
          if (_isUploading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              color: AppColors.cardSurface,
              child: const Row(children: [
                SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.indigo)),
                SizedBox(width: AppSpacing.sm),
                Text('Uploading files...', style: AppTextStyles.caption),
              ]),
            ),
          if (_pendingAttachments.isNotEmpty) _buildPendingPreview(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildPendingPreview() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        border: Border(top: BorderSide(color: AppColors.elevated)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.sm, bottom: AppSpacing.xs),
          child: Text('${_pendingAttachments.length} file(s) ready to send',
              style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600,
                  fontSize: 12, color: AppColors.indigo)),
        ),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _pendingAttachments.length,
            itemBuilder: (context, index) {
              final item    = _pendingAttachments[index];
              final isImage = item['type'] == 'image';
              final bytes   = item['bytes'] as Uint8List;
              final name    = item['name'] as String;
              return Container(
                width: 72, margin: const EdgeInsets.only(right: AppSpacing.sm),
                child: Stack(children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.elevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.indigo.withValues(alpha: 0.4)),
                    ),
                    child: isImage
                        ? ClipRRect(borderRadius: BorderRadius.circular(7),
                            child: Image.memory(bytes, fit: BoxFit.cover))
                        : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.insert_drive_file_outlined, color: AppColors.coral, size: 28),
                            const SizedBox(height: 2),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(name, style: const TextStyle(fontFamily: 'Nunito',
                                  fontSize: 9, color: AppColors.textMuted),
                                  maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                            ),
                          ]),
                  ),
                  Positioned(top: 0, right: 0,
                    child: GestureDetector(
                      onTap: () => _removePending(index),
                      child: Container(width: 20, height: 20,
                          decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, size: 12, color: Colors.white)),
                    ),
                  ),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _buildMessagesList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          GradientAvatar(imageUrl: widget.otherUser.avatarUrl,
              name: widget.otherUser.displayName, size: 64),
          const SizedBox(height: AppSpacing.md),
          Text(widget.otherUser.displayName, style: AppTextStyles.heading3),
          const SizedBox(height: AppSpacing.sm),
          const Text("You're both connected! Start swapping skills 🤝",
              style: AppTextStyles.body, textAlign: TextAlign.center),
        ]),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMine  = message.senderId == SupabaseService.currentUserId;
        final showDateHeader = index == 0 ||
            !_isSameDay(_messages[index - 1].createdAt, message.createdAt);
        return Column(children: [
          if (showDateHeader) _buildDateHeader(message.createdAt),
          _buildBubble(message, isMine),
        ]);
      },
    );
  }

  Widget _buildBubble(MessageModel message, bool isMine) {
    // Session proposal — full width card, no bubble
    if (message.messageType == 'session_proposal') {
      return _buildSessionProposalCard(message, isMine);
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 2, bottom: 2,
                left: isMine ? 60 : 0, right: isMine ? 0 : 60),
            decoration: BoxDecoration(
              color: isMine ? AppColors.indigo : AppColors.cardSurface,
              borderRadius: BorderRadius.only(
                topLeft:     const Radius.circular(16),
                topRight:    const Radius.circular(16),
                bottomLeft:  Radius.circular(isMine ? 16 : 4),
                bottomRight: Radius.circular(isMine ? 4  : 16),
              ),
            ),
            child: _buildBubbleContent(message, isMine),
          ),
          Padding(
            padding: EdgeInsets.only(left: isMine ? 0 : 4, right: isMine ? 4 : 0, bottom: 6),
            child: Text(_formatTime(message.createdAt),
                style: const TextStyle(fontFamily: 'Nunito', fontSize: 10, color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }

  // ── Session proposal card — full width ─────────────────────────
  Widget _buildSessionProposalCard(MessageModel message, bool isMine) {
    final metadata    = message.metadata;
    final sessionId   = metadata?['session_id'] as String?;
    final topic       = metadata?['topic'] as String? ?? 'Session';
    final dateDisplay = metadata?['date_display'] as String? ?? '';
    final timeDisplay = metadata?['time_display'] as String? ?? '';
    final durLabel    = metadata?['duration_label'] as String? ?? '';
    final isUpdate    = metadata?['is_update'] as bool? ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sender label
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              isMine ? 'You proposed a session' : '${widget.otherUser.displayName} proposed a session',
              style: AppTextStyles.caption,
            ),
          ),

          // Proposal card
          FutureBuilder<String>(
            future: _getSessionStatus(sessionId),
            builder: (context, snapshot) {
              final status = snapshot.data ?? 'pending';
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: status == 'upcoming'
                        ? AppColors.green.withValues(alpha: 0.5)
                        : status == 'rejected'
                            ? AppColors.red.withValues(alpha: 0.4)
                            : AppColors.indigo.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: status == 'upcoming'
                            ? AppColors.green.withValues(alpha: 0.1)
                            : status == 'rejected'
                                ? AppColors.red.withValues(alpha: 0.08)
                                : AppColors.indigo.withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          topRight: Radius.circular(14),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            status == 'upcoming'
                                ? Icons.check_circle_rounded
                                : status == 'rejected'
                                    ? Icons.cancel_rounded
                                    : Icons.calendar_today_rounded,
                            size: 16,
                            color: status == 'upcoming'
                                ? AppColors.green
                                : status == 'rejected'
                                    ? AppColors.red
                                    : AppColors.indigo,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              isUpdate ? '📅 Updated Session Proposal' : '📅 Session Proposal',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: status == 'upcoming'
                                    ? AppColors.green
                                    : status == 'rejected'
                                        ? AppColors.red
                                        : AppColors.indigo,
                              ),
                            ),
                          ),
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: status == 'upcoming'
                                  ? AppColors.green.withValues(alpha: 0.15)
                                  : status == 'rejected'
                                      ? AppColors.red.withValues(alpha: 0.15)
                                      : AppColors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              status == 'upcoming'
                                  ? '✓ Confirmed'
                                  : status == 'rejected'
                                      ? '✕ Declined'
                                      : '⏳ Pending',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                                color: status == 'upcoming'
                                    ? AppColors.green
                                    : status == 'rejected'
                                        ? AppColors.red
                                        : AppColors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Details
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(topic,
                              style: const TextStyle(fontFamily: 'Nunito',
                                  fontWeight: FontWeight.w700, fontSize: 15,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: AppSpacing.sm),
                          _InfoRow(icon: Icons.calendar_today_outlined, text: dateDisplay),
                          _InfoRow(icon: Icons.access_time_rounded, text: '$timeDisplay · $durLabel'),
                        ],
                      ),
                    ),

                    // Action buttons — only show if pending
                    if (status == 'pending') ...[
                      const Divider(color: AppColors.elevated, height: 1),
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: isMine
                            // Sender can edit
                            ? Row(children: [
                                Expanded(
                                  child: TextButton.icon(
                                    onPressed: () => _editProposal(metadata),
                                    icon: const Icon(Icons.edit_rounded, size: 14, color: AppColors.indigo),
                                    label: const Text('Edit Proposal',
                                        style: TextStyle(fontFamily: 'Nunito',
                                            fontWeight: FontWeight.w600, fontSize: 12,
                                            color: AppColors.indigo)),
                                  ),
                                ),
                              ])
                            // Receiver can accept or reject
                            : Row(children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _rejectProposal(sessionId),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.red,
                                      side: const BorderSide(color: AppColors.red),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(100)),
                                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                                    ),
                                    child: const Text('✕ Decline',
                                        style: TextStyle(fontFamily: 'Nunito',
                                            fontWeight: FontWeight.w700, fontSize: 13)),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _acceptProposal(sessionId),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.green,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(100)),
                                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                                    ),
                                    child: const Text('✓ Accept',
                                        style: TextStyle(fontFamily: 'Nunito',
                                            fontWeight: FontWeight.w700, fontSize: 13)),
                                  ),
                                ),
                              ]),
                      ),
                    ],

                    // Confirmed message
                    if (status == 'upcoming')
                      const Padding(
                        padding: EdgeInsets.fromLTRB(
                            AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                        child: Text(
                          '🎉 Session confirmed! Added to both schedules.',
                          style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                              color: AppColors.green, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          // Time below
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Text(_formatTime(message.createdAt),
                style: const TextStyle(fontFamily: 'Nunito', fontSize: 10, color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }

  Widget _buildBubbleContent(MessageModel message, bool isMine) {
    switch (message.messageType) {
      case 'image':
        if (message.fileUrl == null) {
          return const Padding(padding: EdgeInsets.all(AppSpacing.md),
              child: Text('📷 Image', style: TextStyle(color: AppColors.textPrimary, fontFamily: 'Nunito', fontSize: 14)));
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: () => kIsWeb ? _openUrl(message.fileUrl!) : _openImageFullScreen(message.fileUrl!),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              child: Image.network(message.fileUrl!, width: 220, fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(width: 220, height: 140, color: AppColors.elevated,
                      child: const Center(child: CircularProgressIndicator(color: AppColors.indigo, strokeWidth: 2)));
                },
                errorBuilder: (_, __, ___) => Container(width: 220, height: 80, color: AppColors.elevated,
                    child: const Center(child: Icon(Icons.broken_image_outlined, color: AppColors.textMuted))),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              GestureDetector(
                onTap: () => kIsWeb ? _openUrl(message.fileUrl!) : _openImageFullScreen(message.fileUrl!),
                child: Row(children: [
                  Icon(Icons.open_in_new_rounded, size: 13, color: isMine ? Colors.white70 : AppColors.indigo),
                  const SizedBox(width: 3),
                  Text('Open', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600, fontSize: 12,
                      color: isMine ? Colors.white70 : AppColors.indigo)),
                ]),
              ),
              const SizedBox(width: AppSpacing.md),
              GestureDetector(
                onTap: () => kIsWeb ? _downloadUrl(message.fileUrl!) : _saveImageToGallery(message.fileUrl!),
                child: Row(children: [
                  Icon(Icons.download_rounded, size: 13, color: isMine ? Colors.white70 : AppColors.coral),
                  const SizedBox(width: 3),
                  Text('Download', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600, fontSize: 12,
                      color: isMine ? Colors.white70 : AppColors.coral)),
                ]),
              ),
            ]),
          ),
        ]);

      case 'file':
        final fileName = message.content.replaceAll('📄 ', '');
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(
                color: isMine ? Colors.white.withValues(alpha: 0.2) : AppColors.indigo.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.insert_drive_file_outlined,
                  color: isMine ? Colors.white : AppColors.indigo, size: 24),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(message.content,
                  style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600, fontSize: 13,
                      color: isMine ? Colors.white : AppColors.textPrimary),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              if (message.fileUrl != null)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  GestureDetector(
                    onTap: () => kIsWeb ? _openUrl(message.fileUrl!) : _openDocumentMobile(message.fileUrl!, fileName),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isMine ? Colors.white.withValues(alpha: 0.2) : AppColors.indigo.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.open_in_new_rounded, size: 12, color: isMine ? Colors.white : AppColors.indigo),
                        const SizedBox(width: 3),
                        Text('Open', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 11,
                            color: isMine ? Colors.white : AppColors.indigo)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  GestureDetector(
                    onTap: () => kIsWeb ? _downloadUrl(message.fileUrl!) : _downloadDocumentMobile(message.fileUrl!, fileName),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isMine ? Colors.white.withValues(alpha: 0.2) : AppColors.coral.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.download_rounded, size: 12, color: isMine ? Colors.white : AppColors.coral),
                        const SizedBox(width: 3),
                        Text('Download', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 11,
                            color: isMine ? Colors.white : AppColors.coral)),
                      ]),
                    ),
                  ),
                ]),
            ])),
          ]),
        );

      default:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Text(message.content,
              style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w400,
                  fontSize: 14, color: AppColors.textPrimary)),
        );
    }
  }

  Widget _buildInputBar() {
    final hasPending = _pendingAttachments.isNotEmpty;
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.md, right: AppSpacing.md, top: AppSpacing.sm,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        border: Border(top: BorderSide(color: AppColors.elevated)),
      ),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.attach_file_rounded, color: AppColors.textMuted),
          onPressed: _isUploading ? null : _showAttachmentPicker,
        ),
        // Book session button
        IconButton(
          icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.indigo),
          onPressed: _openBookSession,
          tooltip: 'Book a session',
        ),
        if (!hasPending)
          Expanded(
            child: TextField(
              controller: _messageController,
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: AppColors.textMuted, fontFamily: 'Nunito', fontSize: 14),
                border: InputBorder.none, enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none, isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
              ),
            ),
          ),
        if (hasPending)
          Expanded(
            child: Text('Tap ➤ to send ${_pendingAttachments.length} file(s)',
                style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600,
                    fontSize: 13, color: AppColors.indigo)),
          ),
        GestureDetector(
          onTap: (_isSending || _isUploading) ? null
              : hasPending ? _sendPendingAttachments : _sendMessage,
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: hasPending ? AppColors.green : AppColors.coral,
              shape: BoxShape.circle,
            ),
            child: (_isSending || _isUploading)
                ? const Padding(padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
          ),
        ),
      ]),
    );
  }
}

// ── Info row for proposal card ─────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(icon, size: 13, color: AppColors.indigo),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontFamily: 'Nunito', fontSize: 13,
            color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ── Full screen image viewer ───────────────────────────────────────
class _FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final VoidCallback onDownload;
  const _FullScreenImageViewer({required this.imageUrl, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.download_rounded, color: Colors.white),
              onPressed: onDownload, tooltip: 'Save to gallery'),
        ],
      ),
      body: PhotoView(
        imageProvider: NetworkImage(imageUrl),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        loadingBuilder: (context, event) =>
            const Center(child: CircularProgressIndicator(color: AppColors.indigo)),
        errorBuilder: (context, error, stackTrace) =>
            const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white, size: 64)),
      ),
    );
  }
}