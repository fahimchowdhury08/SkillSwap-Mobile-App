
// lib/screens/video_call/prejoin_screen.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../theme.dart';
import '../../models/user_model.dart';
import '../../widgets/coral_button.dart';
import '../../widgets/gradient_avatar.dart';
import 'call_screen.dart';

class PrejoinScreen extends StatefulWidget {
  final String swapId;
  final UserModel otherUser;
  final String currentUserName;
  final String? sessionId;

  const PrejoinScreen({
    super.key,
    required this.swapId,
    required this.otherUser,
    required this.currentUserName,
    this.sessionId,
  });

  @override
  State<PrejoinScreen> createState() => _PrejoinScreenState();
}

class _PrejoinScreenState extends State<PrejoinScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _cameraOn = true;
  bool _micOn = true;
  bool _cameraInitialized = false;
  bool _cameraError = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _cameraError = true);
        return;
      }

      // Prefer front camera for video calls
      final frontCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() => _cameraInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cameraError = true);
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  void _toggleCamera() => setState(() => _cameraOn = !_cameraOn);
  void _toggleMic() => setState(() => _micOn = !_micOn);

  void _joinCall() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          swapId: widget.swapId,
          otherUser: widget.otherUser,
          currentUserName: widget.currentUserName,
          sessionId: widget.sessionId,
          cameraOn: _cameraOn,
          micOn: _micOn,
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_cameraOn) {
      return Container(
        color: AppColors.background,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off, color: Colors.white54, size: 48),
              const SizedBox(height: 8),
              Text(
                'Camera is off',
                style: AppTextStyles.body.copyWith(color: Colors.white54),
              ),
            ],
          ),
        ),
      );
    }

    if (_cameraError || !_cameraInitialized || _cameraController == null) {
      return Container(
        color: AppColors.background,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person, color: Colors.white30, size: 64),
              const SizedBox(height: 8),
              Text(
                _cameraError ? 'Camera unavailable' : 'Initializing...',
                style: AppTextStyles.body.copyWith(color: Colors.white38),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: CameraPreview(_cameraController!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Ready to join?',
          style: AppTextStyles.heading2.copyWith(fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.md),

              // "Calling" header with other user info
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GradientAvatar(
                    imageUrl: widget.otherUser.avatarUrl,
                    name: widget.otherUser.displayName,
                    size: 36,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Calling ${widget.otherUser.fullName ?? 'your partner'}...',
                    style: AppTextStyles.body.copyWith(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // Camera preview
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _buildCameraPreview(),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Mic + Camera toggles
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ToggleButton(
                    icon: _micOn ? Icons.mic : Icons.mic_off,
                    label: _micOn ? 'Mic On' : 'Mic Off',
                    active: _micOn,
                    onTap: _toggleMic,
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  _ToggleButton(
                    icon: _cameraOn ? Icons.videocam : Icons.videocam_off,
                    label: _cameraOn ? 'Camera On' : 'Camera Off',
                    active: _cameraOn,
                    onTap: _toggleCamera,
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // Join Call button
              CoralButton(
                label: 'Join Call 📹',
                onTap: _joinCall,
              ),

              const SizedBox(height: AppSpacing.sm),

              // Cancel link
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white54,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white54,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Toggle button widget ──────────────────────────────────────────────────────

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? AppColors.indigo.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.08),
              border: Border.all(
                color: active ? AppColors.indigo : Colors.white24,
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: active ? AppColors.indigo : Colors.white38,
              size: 26,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTextStyles.body.copyWith(
              fontSize: 11,
              color: active ? Colors.white70 : Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}