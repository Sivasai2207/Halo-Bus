import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:typed_data';
import '../../auth/controllers/auth_controller.dart';
import '../../../data/providers.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../core/widgets/photo_picker_sheet.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';

class DriverProfileScreen extends ConsumerStatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  ConsumerState<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends ConsumerState<DriverProfileScreen> {
  bool _isUploading = false;

  Future<void> _handlePhotoUpload({required bool fromCamera}) async {
    final photoService = ref.read(photoServiceProvider);
    final profile = ref.read(userProfileProvider).value;
    if (profile == null) return;

    try {
      final xFile = fromCamera
          ? await photoService.pickFromCamera()
          : await photoService.pickFromGallery();

      if (xFile == null) return; // user cancelled

      setState(() => _isUploading = true);

      final bytes = await xFile.readAsBytes();
      final croppedBytes = await photoService.detectFaceAndCrop(xFile.path, bytes);
      final url = await photoService.uploadCroppedPhoto(
        userId: profile.id,
        role: profile.role,
        imageBytes: croppedBytes,
      );

      // Save URL to Firestore
      final userRepo = ref.read(userRepositoryProvider);
      await userRepo.updatePhotoUrl(
        collegeId: profile.collegeId,
        uid: profile.id,
        role: profile.role,
        photoUrl: url,
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

    return AppScaffold(
      body: SafeArea(
        child: profileAsync.when(
          data: (profile) {
            if (profile == null) {
              return Center(child: Text("Profile not found", style: AppTypography.bodyMd));
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text('Profile', style: AppTypography.h1),
                  const SizedBox(height: 32),

                  // Avatar card
                  Container(
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
                                width: 64,
                                height: 64,
                                child: Center(
                                  child: CircularProgressIndicator(color: AppColors.primary),
                                ),
                              )
                            : ProfileAvatar(
                                photoUrl: profile.photoUrl,
                                name: profile.name,
                                radius: 32,
                                onTap: _showPicker,
                              ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(profile.name ?? 'Driver', style: AppTypography.h2),
                              Text(profile.email, style: AppTypography.caption),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  profile.role.toUpperCase(),
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
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

                  const SizedBox(height: 48),

                  PrimaryButton(
                    text: 'Logout',
                    backgroundColor: AppColors.error,
                    onPressed: () {
                      ref.read(authControllerProvider.notifier).signOut();
                      context.go('/login');
                    },
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (err, _) => Center(child: Text("Error: $err", style: AppTypography.bodyMd)),
        ),
      ),
    );
  }
}
