import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class PhotoPickerSheet extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const PhotoPickerSheet({
    super.key,
    required this.onCamera,
    required this.onGallery,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onCamera,
    required VoidCallback onGallery,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => PhotoPickerSheet(onCamera: onCamera, onGallery: onGallery),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text('Update Profile Photo', style: AppTypography.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'We\'ll automatically focus on your face.',
              style: AppTypography.textTheme.bodyMedium?.copyWith(color: AppColors.textTertiary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _optionTile(
              icon: Icons.camera_alt_rounded,
              label: 'Take a Photo',
              onTap: () {
                Navigator.pop(context);
                onCamera();
              },
            ),
            const SizedBox(height: 12),
            _optionTile(
              icon: Icons.photo_library_rounded,
              label: 'Choose from Gallery',
              onTap: () {
                Navigator.pop(context);
                onGallery();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _optionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(width: 16),
            Text(label, style: AppTypography.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
