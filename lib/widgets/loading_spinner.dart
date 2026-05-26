
import 'package:flutter/material.dart';
import '../theme.dart';

class LoadingSpinner extends StatelessWidget {
  final String? message;
  final Color? color;

  const LoadingSpinner({
    super.key,
    this.message,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // ── Spinner ─────────────────────────────────────────
          CircularProgressIndicator(
            color: color ?? AppColors.indigo,
            strokeWidth: 3,
          ),

          // ── Optional message below spinner ──────────────────
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              message!,
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
          ],

        ],
      ),
    );
  }
}

// ── Full Screen Loading ────────────────────────────────────────
// Use this when an entire screen is loading
// Example: loading profile data on initState
class FullScreenLoader extends StatelessWidget {
  final String? message;

  const FullScreenLoader({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LoadingSpinner(
        message: message ?? 'Loading...',
      ),
    );
  }
}

// ── Overlay Loading ────────────────────────────────────────────
// Use this as a transparent overlay on top of a screen
// while a button action is processing
// Example: while uploading a file or saving a form
class LoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String? message;

  const LoadingOverlay({
    super.key,
    required this.child,
    required this.isLoading,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [

        // ── The actual screen content ────────────────────────
        child,

        // ── Overlay shown only when isLoading is true ────────
        if (isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: LoadingSpinner(
              message: message ?? 'Please wait...',
            ),
          ),

      ],
    );
  }
}