import 'package:flutter/material.dart';

import 'package:tokigo/core/theme/app_colors.dart';
import 'package:tokigo/core/theme/app_radius.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Notifications surface — booking updates, offers and trip alerts.
///
/// v1 renders a prioritised mock feed with read/unread states; live push
/// handling arrives with the notifications backend phase.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  static const List<_Notification> _feed = <_Notification>[
    _Notification(
      title: 'Booking confirmed',
      body: 'Your booking WT-482913 is confirmed. Check your trip for details.',
      icon: Icons.check_circle_rounded,
      hue: AppColors.success,
      timeLabel: '2m ago',
      unread: true,
    ),
    _Notification(
      title: 'Price drop alert',
      body: 'Sharm El Sheikh hotels dropped 18% for your watched dates.',
      icon: Icons.trending_down_rounded,
      hue: AppColors.info,
      timeLabel: '1h ago',
      unread: true,
    ),
    _Notification(
      title: 'Check-in opens soon',
      body: 'Online check-in for flight MS985 opens in 24 hours.',
      icon: Icons.flight_takeoff_rounded,
      hue: AppColors.brand,
      timeLabel: '5h ago',
      unread: false,
    ),
    _Notification(
      title: 'Weekend deal',
      body: 'Luxor heritage tours at 25% off — this weekend only.',
      icon: Icons.local_offer_rounded,
      hue: AppColors.accent,
      timeLabel: 'Yesterday',
      unread: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: Row(
                children: <Widget>[
                  Text(
                    l10n.notifications,
                    style: typography.display.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: _feed.length,
                itemBuilder: (context, index) {
                  final n = _feed[index];
                  return _NotificationTile(notification: n);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final _Notification notification;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: notification.unread
              ? AppColors.brandContainer.withValues(alpha: 0.45)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.outline),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: notification.hue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                notification.icon,
                size: 20,
                color: notification.hue,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          notification.title,
                          style: typography.bodyLargeMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (notification.unread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.brand,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    notification.body,
                    style: typography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    notification.timeLabel,
                    style: typography.label,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _Notification {
  const _Notification({
    required this.title,
    required this.body,
    required this.icon,
    required this.hue,
    required this.timeLabel,
    required this.unread,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color hue;
  final String timeLabel;
  final bool unread;
}
