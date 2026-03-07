import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class ProfileAvatar extends StatelessWidget {
  final String? photoUrl;
  final String? name;
  final double radius;
  final VoidCallback? onTap; // non-null = shows edit overlay

  const ProfileAvatar({
    super.key,
    this.photoUrl,
    this.name,
    this.radius = 28,
    this.onTap,
  });

  String _initials() {
    if (name == null || name!.isEmpty) return '?';
    final parts = name!.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary, AppColors.accent]),
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: radius,
              backgroundColor: AppColors.surface,
              backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
                  ? NetworkImage(photoUrl!)
                  : null,
              child: (photoUrl == null || photoUrl!.isEmpty)
                  ? Text(
                      _initials(),
                      style: AppTypography.textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
          // Edit overlay badge (only shown when onTap is provided)
          if (onTap != null)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: radius * 0.75,
                height: radius * 0.75,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 1.5),
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  size: radius * 0.42,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
