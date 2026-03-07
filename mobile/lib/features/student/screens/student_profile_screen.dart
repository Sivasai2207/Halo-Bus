import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:typed_data';
import '../../auth/controllers/auth_controller.dart';
import '../../../data/providers.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../core/widgets/photo_picker_sheet.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';

class StudentProfileScreen extends ConsumerStatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  ConsumerState<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends ConsumerState<StudentProfileScreen> {
  bool _isUploading = false;

  Future<void> _handlePhotoUpload({required bool fromCamera}) async {
    final photoService = ref.read(photoServiceProvider);
    final profile = ref.read(userProfileProvider).value;
    if (profile == null) return;

    try {
      final xFile = fromCamera
          ? await photoService.pickFromCamera()
          : await photoService.pickFromGallery();

      if (xFile == null) return;

      setState(() => _isUploading = true);

      final bytes = await xFile.readAsBytes();
      final croppedBytes = await photoService.detectFaceAndCrop(xFile.path, bytes);
      final base64Image = photoService.encodeToBase64(croppedBytes);

      final userRepo = ref.read(userRepositoryProvider);
      await userRepo.updatePhotoUrl(
        collegeId: profile.collegeId,
        uid: profile.id,
        role: profile.role,
        photoUrl: base64Image,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update photo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showPicker() {
    PhotoPickerSheet.show(
      context,
      onCamera: () => _handlePhotoUpload(fromCamera: true),
      onGallery: () => _handlePhotoUpload(fromCamera: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final selectedCollege = ref.watch(selectedCollegeProvider);
    final collegeName = selectedCollege?['collegeName'] ?? '';

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text('Profile', style: AppTypography.h1),
              const SizedBox(height: 24),

              // Avatar Card
              profileAsync.when(
                data: (profile) => Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.bgCard, AppColors.bgSurface],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      _isUploading
                          ? const SizedBox(
                              width: 68,
                              height: 68,
                              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                            )
                          : ProfileAvatar(
                              photoUrl: profile?.photoUrl,
                              name: profile?.name,
                              radius: 34,
                              onTap: _showPicker,
                            ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(profile?.name ?? "Student", style: AppTypography.h2),
                            const SizedBox(height: 2),
                            Text(profile?.email ?? "", style: AppTypography.caption),
                            const SizedBox(height: 6),
                            if (collegeName.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.business_rounded, size: 10, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        collegeName,
                                        style: AppTypography.caption.copyWith(color: AppColors.primary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap photo to update',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.primary.withValues(alpha: 0.7),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (e, _) => Text("Error loading profile", style: AppTypography.bodyMd),
              ),
              
              const SizedBox(height: 32),
              
              // ACCOUNT section
              _sectionHeader("ACCOUNT"),
              const SizedBox(height: 8),
              
              _settingsTile(
                icon: Icons.notifications_outlined,
                title: "Notifications",
                subtitle: "Manage alert preferences",
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Manage from device Settings > Notifications.")),
                  );
                },
              ),
              _settingsTile(
                icon: Icons.directions_bus_outlined,
                title: "My Assigned Bus",
                subtitle: "View transport details",
                onTap: () => GoRouter.of(context).push('/student/buses'),
              ),
              _settingsTile(
                icon: Icons.location_on_outlined,
                title: "Location Preferences",
                subtitle: "GPS and tracking settings",
                onTap: () {},
              ),

              const SizedBox(height: 24),
              _sectionHeader("SUPPORT"),
              const SizedBox(height: 8),

              _settingsTile(
                icon: Icons.help_outline_rounded,
                title: "Help & FAQ",
                subtitle: "Common questions answered",
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.bgSurface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: Text("Help & Support", style: AppTypography.h2),
                      content: Text(
                        "For technical support, please contact your college's transport coordinator.\n\n"
                        "Common issues:\n"
                        "• Bus not showing? Pull down to refresh.\n"
                        "• Notifications not working? Check device settings.\n"
                        "• Wrong college? Log out and re-select.",
                        style: AppTypography.bodyMd,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text("OK", style: TextStyle(color: AppColors.primary)),
                        ),
                      ],
                    ),
                  );
                },
              ),
              _settingsTile(
                icon: Icons.mail_outline_rounded,
                title: "Contact Support",
                subtitle: "Reach out for help",
                onTap: () {},
              ),

              const SizedBox(height: 24),

              _settingsTile(
                icon: Icons.logout_rounded,
                title: "Sign Out",
                subtitle: "Log out of your account",
                isDestructive: true,
                onTap: () {
                  ref.read(authControllerProvider.notifier).signOut();
                },
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: AppTypography.caption.copyWith(
          color: AppColors.textTertiary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isDestructive ? AppColors.error.withOpacity(0.1) : AppColors.primarySoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
            color: isDestructive ? AppColors.error : AppColors.primary,
            size: 18,
          ),
        ),
        title: Text(title, style: AppTypography.bodyLg.copyWith(color: AppColors.textPrimary)),
        subtitle: Text(subtitle, style: AppTypography.caption),
        trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 18),
      ),
    );
  }
}
