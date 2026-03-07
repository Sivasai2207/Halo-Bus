import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../data/providers.dart';
import '../../../data/models/user_notification.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(userNotificationsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  color: AppColors.textPrimary,
                ),
                Text('Notifications', style: AppTypography.h1),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: notificationsAsync.when(
            data: (notifications) {
              if (notifications.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.notifications_off_outlined, size: 48, color: AppColors.primary),
                      ),
                      const SizedBox(height: 16),
                      Text('Your inbox is empty', style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return _NotificationCard(notification: notification);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (err, _) => Center(child: Text('Error: $err', style: AppTypography.bodyMd)),
          ),
        ),
      ],
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  final UserNotification notification;
  const _NotificationCard({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeStr = DateFormat('MMM dd, hh:mm a').format(notification.createdAt);

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) {
        ref.read(firestoreProvider).collection('user_notifications').doc(notification.id).delete();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.read ? AppColors.bgCard.withOpacity(0.6) : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: notification.read ? AppColors.borderSubtle : AppColors.primarySoft,
            width: 1,
          ),
          boxShadow: notification.read ? [] : [AppShadows.cardShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: notification.read ? AppColors.bgDeep : AppColors.primarySoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          notification.type == 'HANDOVER_OTP' 
                              ? Icons.vpn_key_rounded 
                              : (notification.title.contains('⚠️') ? Icons.warning_amber_rounded : Icons.notifications_active_rounded),
                          size: 18,
                          color: notification.read ? AppColors.textTertiary : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification.title,
                              style: AppTypography.h3.copyWith(
                                color: notification.read ? AppColors.textSecondary : AppColors.textPrimary,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              timeStr,
                              style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textTertiary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    ref.read(firestoreProvider).collection('user_notifications').doc(notification.id).delete();
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              notification.body,
              style: AppTypography.bodyMd.copyWith(
                color: notification.read ? AppColors.textSecondary : AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            if (notification.type == 'HANDOVER_OTP' && notification.otp != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.bgDeep,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSubtle, width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('OTP: ', style: AppTypography.label.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(width: 8),
                    Text(
                      notification.otp!,
                      style: AppTypography.h1.copyWith(
                        letterSpacing: 4,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!notification.read) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    ref.read(firestoreProvider)
                        .collection('user_notifications')
                        .doc(notification.id)
                        .update({'read': true});
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    backgroundColor: AppColors.primarySoft,
                  ),
                  child: Text('Mark as read', style: AppTypography.label.copyWith(color: AppColors.primary)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
