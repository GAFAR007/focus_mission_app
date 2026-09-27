/**
 * WHAT:
 * NotificationPanel renders the in-app inbox list used by teacher and mentor
 * workspaces.
 * WHY:
 * Notifications should share one calm, high-signal UI pattern so review alerts
 * do not become scattered across role screens.
 * HOW:
 * Render the unread count, show each notification as a tappable card, and fall
 * back to an empty-state message when the inbox is clear. Teacher dashboards
 * can opt into compact spacing and a neutral surface.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

import '../../core/constants/app_palette.dart';
import '../../core/constants/app_spacing.dart';
import '../models/focus_mission_models.dart';
import 'soft_panel.dart';

class NotificationPanel extends StatelessWidget {
  const NotificationPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.notifications,
    required this.unreadCount,
    required this.emptyMessage,
    required this.onTapNotification,
    this.compact = false,
  });

  final bool compact;
  final String title;
  final String subtitle;
  final List<AppNotification> notifications;
  final int unreadCount;
  final String emptyMessage;
  final ValueChanged<AppNotification> onTapNotification;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      solid: compact,
      padding: EdgeInsets.all(compact ? AppSpacing.item : AppSpacing.section),
      colors: compact
          ? const [AppPalette.surface, AppPalette.surface]
          : const [Color(0xFFFFFBF2), Color(0xFFFFF0D3)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // WHY: Use the same inbox data/actions with a smaller teacher-only
          // header; warm colour remains confined to the icon and unread badge.
          if (compact) ...[
            Row(
              children: [
                const Icon(
                  Icons.notifications_outlined,
                  color: AppPalette.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: unreadCount == 0
                              ? Colors.white
                              : AppPalette.sun.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(AppSpacing.chip),
                        ),
                        child: Text(
                          unreadCount == 0 ? 'All read' : '$unreadCount unread',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppPalette.navy),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
            ),
          ] else
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [AppPalette.sun, AppPalette.orange],
                    ),
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: AppSpacing.item),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppPalette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppPalette.surface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppPalette.sun.withValues(alpha: 0.34),
                    ),
                  ),
                  child: Text(
                    unreadCount == 0 ? 'All read' : '$unreadCount unread',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppPalette.navy),
                  ),
                ),
              ],
            ),
          SizedBox(height: compact ? AppSpacing.compact : AppSpacing.section),
          if (notifications.isEmpty && compact)
            Text(
              emptyMessage,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
            )
          else if (notifications.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.item),
              decoration: BoxDecoration(
                color: AppPalette.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                  color: AppPalette.sun.withValues(alpha: 0.24),
                ),
              ),
              child: Text(
                emptyMessage,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
              ),
            )
          else
            ...notifications.map(
              (notification) => Padding(
                padding: EdgeInsets.only(
                  bottom: compact
                      ? (notification == notifications.last ? 0 : 8)
                      : AppSpacing.compact,
                ),
                child: _NotificationCard(
                  compact: compact,
                  notification: notification,
                  onTap: () => onTapNotification(notification),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onTap,
    this.compact = false,
  });

  final bool compact;

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = notification.isRead
        ? Colors.white.withValues(alpha: 0.68)
        : Colors.white.withValues(alpha: 0.92);
    final border = notification.isRead
        ? Colors.transparent
        : AppPalette.sun.withValues(alpha: 0.48);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Ink(
          padding: EdgeInsets.all(
            compact ? AppSpacing.compact : AppSpacing.item,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: compact ? 6 : 10,
                runSpacing: compact ? 6 : 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    notification.title,
                    style: compact
                        ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppPalette.navy,
                            fontWeight: FontWeight.w700,
                          )
                        : Theme.of(context).textTheme.titleMedium,
                  ),
                  if (!notification.isRead)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 8 : 10,
                        vertical: compact ? 3 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppPalette.sun.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'New',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppPalette.navy),
                      ),
                    ),
                  if ((notification.createdAt ?? '').isNotEmpty)
                    Text(
                      _formatCreatedAt(notification.createdAt!),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                    ),
                ],
              ),
              SizedBox(height: compact ? 4 : 8),
              Text(
                notification.message,
                style: compact
                    ? Theme.of(context).textTheme.bodySmall
                    : Theme.of(context).textTheme.bodyMedium,
              ),
              if ((notification.studentName ?? '').isNotEmpty ||
                  (notification.criterionTitle ?? '').isNotEmpty) ...[
                SizedBox(height: compact ? 6 : 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if ((notification.studentName ?? '').isNotEmpty)
                      _MiniPill(
                        label: notification.studentName!,
                        compact: compact,
                      ),
                    if ((notification.criterionTitle ?? '').isNotEmpty)
                      _MiniPill(
                        label: notification.criterionTitle!,
                        compact: compact,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatCreatedAt(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return value;
    }

    final now = DateTime.now();
    final sameDay =
        parsed.year == now.year &&
        parsed.month == now.month &&
        parsed.day == now.day;

    if (sameDay) {
      final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
      final minute = parsed.minute.toString().padLeft(2, '0');
      final suffix = parsed.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $suffix';
    }

    return '${parsed.month}/${parsed.day}/${parsed.year}';
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label, this.compact = false});

  final bool compact;

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: AppPalette.backgroundTop,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppPalette.navy),
      ),
    );
  }
}
