import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tokigo/core/theme/tokigo_colors.dart';
import 'package:tokigo/core/theme/app_spacing.dart';
import 'package:tokigo/core/theme/app_typography.dart';
import 'package:tokigo/core/widgets/ai_entrance_animation.dart';
import 'package:tokigo/core/widgets/page_header.dart';
import 'package:tokigo/features/notifications/domain/app_notification.dart';
import 'package:tokigo/features/notifications/providers/notifications_providers.dart';
import 'package:tokigo/l10n/app_localizations.dart';

/// Notifications surface — booking updates, offers and trip alerts.
///
/// **OWNER DECISION (2026-10-19): no fabricated content.** v1 shipped a
/// hardcoded "prioritised feed" of four invented notifications — including a
/// confirmation for a booking reference (`WT-482913`) that never existed. It is
/// gone: the feed is empty until REAL notifications arrive (push/backend), and
/// the surface says so.
///
/// The page is DATA-driven ([notifications]) so the geometry below is the real
/// one the moment a backend delivers a feed: rows of at least 72pt, an ⌀8
/// unread marker, a 1px divider and the "Today" / "Earlier" group headers.
/// The default feed is empty — nothing is invented to fill it.
///
/// Geometry (doc 23 §4):
/// * row — min height **72**, padding `lg` 16;
/// * unread marker — ⌀8 `brand` at the start, `md` 12 before the text;
/// * row title — `bodyLargeMedium` 17/600;
/// * row body — `caption` 13/400 `textSecondary`, at most two lines;
/// * time — `caption` 13/400 `textTertiary`, at the end;
/// * divider — 1px `divider`, inset `lg` 16;
/// * group headers — `label` 11/600 `textTertiary`, tracking +0.3;
/// * empty — a 48px `textTertiary` glyph, a 17/600 title, a 15/400 body.
///
/// **No swipe to dismiss** (doc 23 §4): a destructive gesture with no undo is
/// not adopted.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key, this.notifications});

  /// Optional explicit feed (tests/standalone hosts). When null the page reads
  /// the live [notificationsProvider] — the same source as Home's bell — so
  /// the page never invents or duplicates notification business logic.
  final List<AppNotification>? notifications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final List<AppNotification> feed =
        notifications ?? ref.watch(notificationsProvider);
    // Doc 23 §0 — the page ends with `xxl` 32 plus the safe area.
    final double bottom = AppSpacing.xxl + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: context.tokigoColors.background,
      body: SafeArea(
        // `bottom: false` left the list's last row under the Android
        // navigation bar (the pill it was written for is gone).
        child: AiEntranceAnimation(
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: AppPageHeader(title: l10n.notifications),
              ),
              if (feed.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _NotificationsEmptyState(),
                )
              else ...<Widget>[
                ..._feedSlivers(context, l10n, feed),
                SliverToBoxAdapter(child: SizedBox(height: bottom)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The feed, split into the two real groups: what happened today and what
  /// happened earlier. The split is derived from the timestamps, never from a
  /// hardcoded list.
  List<Widget> _feedSlivers(
    BuildContext context,
    AppLocalizations l10n,
    List<AppNotification> feed,
  ) {
    final DateTime now = DateTime.now();
    final List<AppNotification> today = <AppNotification>[];
    final List<AppNotification> earlier = <AppNotification>[];
    for (final AppNotification notification in feed) {
      if (_isSameDay(notification.timestamp, now)) {
        today.add(notification);
      } else {
        earlier.add(notification);
      }
    }

    return <Widget>[
      if (today.isNotEmpty) ...<Widget>[
        _GroupHeader(label: l10n.notificationToday),
        _rows(today, today: true),
      ],
      if (earlier.isNotEmpty) ...<Widget>[
        _GroupHeader(label: l10n.notificationEarlier),
        _rows(earlier, today: false),
      ],
    ];
  }

  Widget _rows(List<AppNotification> group, {required bool today}) {
    return SliverList.builder(
      itemCount: group.length,
      itemBuilder: (context, index) {
        final AppNotification notification = group[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _NotificationRow(notification: notification, today: today),
            if (index < group.length - 1) const _RowDivider(),
          ],
        );
      },
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// "Today" / "Earlier" — `label` 11/600 `textTertiary`, tracking +0.3.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Text(
          label,
          style: typography.label.copyWith(
            color: context.tokigoColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

/// The 1px hairline between two rows, inset `lg` 16 on both sides.
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: AppSpacing.lg,
      endIndent: AppSpacing.lg,
      color: context.tokigoColors.divider,
    );
  }
}

/// One notification row — at least 72 tall, the text block and the time.
class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification, required this.today});

  final AppNotification notification;

  /// Whether the entry belongs to the "Today" group (its time reads as a
  /// clock time instead of a date).
  final bool today;

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 72),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (notification.unread) ...<Widget>[
              Semantics(
                label: l10n.notificationUnread,
                child: Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: context.tokigoColors.brand,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    notification.title,
                    style: typography.bodyLargeMedium.copyWith(
                      color: context.tokigoColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    notification.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: typography.caption.copyWith(
                      color: context.tokigoColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              _timeLabel(context),
              style: typography.caption.copyWith(
                color: context.tokigoColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel(BuildContext context) {
    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );
    if (today) {
      return localizations.formatTimeOfDay(
        TimeOfDay.fromDateTime(notification.timestamp),
      );
    }
    return localizations.formatMediumDate(notification.timestamp);
  }
}

/// The honest empty state: a 48px `textTertiary` glyph, a 17/600 title and a
/// 15/400 body, centred.
class _NotificationsEmptyState extends StatelessWidget {
  const _NotificationsEmptyState();

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.forLight();
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xxxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.notifications_none_rounded,
              size: 48,
              color: context.tokigoColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.notificationsEmptyTitle,
              textAlign: TextAlign.center,
              style: typography.bodyLargeMedium.copyWith(
                color: context.tokigoColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.notificationsEmptyBody,
              textAlign: TextAlign.center,
              style: typography.body.copyWith(
                color: context.tokigoColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
