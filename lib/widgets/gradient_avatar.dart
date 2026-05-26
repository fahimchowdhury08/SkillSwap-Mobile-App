
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme.dart';

class GradientAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double size;
  final double borderWidth;

  const GradientAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 48,
    this.borderWidth = 2.5,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.indigoCoralGradient,
      ),
      child: Padding(
        padding: EdgeInsets.all(borderWidth),
        child: ClipOval(
          child: _buildInner(),
        ),
      ),
    );
  }

  // ── Inner content ──────────────────────────────────────────────
  // Shows image if available, otherwise shows initials
  Widget _buildInner() {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildInitials(),
        errorWidget: (context, url, error) => _buildInitials(),
      );
    }
    return _buildInitials();
  }

  // ── Initials fallback ──────────────────────────────────────────
  // Shows first letter of name on a dark background
  // when no image is available
  Widget _buildInitials() {
    final initial = _getInitial();
    return Container(
      color: AppColors.elevated,
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
            fontSize: size * 0.35,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  // ── Get first letter of name ───────────────────────────────────
  String _getInitial() {
    if (name != null && name!.isNotEmpty) {
      return name![0].toUpperCase();
    }
    return '?';
  }
}