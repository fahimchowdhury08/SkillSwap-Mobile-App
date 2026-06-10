import 'package:flutter/material.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import '../../theme.dart';
import '../../models/user_model.dart';
import '../../supabase_service.dart';
import '../post_session/session_complete_screen.dart';

class CallScreen extends StatefulWidget {
  final String swapId;
  final UserModel otherUser;
  final String currentUserName;
  final String? sessionId;
  final bool cameraOn;
  final bool micOn;

  const CallScreen({
    super.key,
    required this.swapId,
    required this.otherUser,
    required this.currentUserName,
    this.sessionId,
    required this.cameraOn,
    required this.micOn,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _jitsiMeet = JitsiMeet();
  bool _isJoining = true;
  bool _hasError  = false;

  @override
  void initState() {
    super.initState();
    _joinCall();
  }

  @override
  void dispose() {
    _jitsiMeet.hangUp();
    super.dispose();
  }

  Future<void> _joinCall() async {
    try {
      // Room name = swapId — unique private room per matched pair
      final roomName = 'skillswap-${widget.swapId.replaceAll('-', '')}';

      final options = JitsiMeetConferenceOptions(
        serverURL: 'https://meet.jit.si',
        room: roomName,
        configOverrides: {
          'startWithVideoMuted':  !widget.cameraOn,
          'startWithAudioMuted':  !widget.micOn,
          'prejoinPageEnabled':   false,
          'disableInviteFunctions': true,
        },
        featureFlags: {
          'invite.enabled':        false,
          'add-people.enabled':    false,
          'meeting-name.enabled':  false,
          'recording.enabled':     false,
          'live-streaming.enabled': false,
          'call-integration.enabled': false,
        },
        userInfo: JitsiMeetUserInfo(
          displayName: widget.currentUserName,
        ),
      );

      final listener = JitsiMeetEventListener(
        conferenceTerminated: (url, error) async {
          // Update session status if sessionId provided
          if (widget.sessionId != null) {
            try {
              await SupabaseService.client
                  .from('sessions')
                  .update({'status': 'completed'})
                  .eq('id', widget.sessionId!);
            } catch (e) {
              debugPrint('Session update error: $e');
            }
          }

          if (!mounted) return;

          // Navigate to session complete screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => SessionCompleteScreen(
                sessionId: widget.sessionId,
                otherUser: widget.otherUser,
                swapId:    widget.swapId,
              ),
            ),
          );
        },
        conferenceJoined: (url) {
          if (mounted) setState(() => _isJoining = false);
        },
        conferenceWillJoin: (url) {
          debugPrint('Joining Jitsi room: $url');
        },
      );

      await _jitsiMeet.join(options, listener);

    } catch (e) {
      debugPrint('Jitsi error: $e');
      if (mounted) setState(() { _isJoining = false; _hasError = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Video Call', style: AppTextStyles.heading2),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam_off_rounded, color: AppColors.coral, size: 64),
                const SizedBox(height: AppSpacing.md),
                const Text('Could not start call', style: AppTextStyles.heading3),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Check your internet connection and try again.',
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: () {
                    setState(() { _isJoining = true; _hasError = false; });
                    _joinCall();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: const Text('Try Again',
                      style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      )),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Loading state while Jitsi launches
    if (_isJoining) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.indigo),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Connecting to ${widget.otherUser.displayName}...',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Black scaffold — Jitsi native UI takes over
    return const Scaffold(backgroundColor: Colors.black);
  }
}