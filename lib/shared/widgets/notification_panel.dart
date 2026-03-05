/**
 * WHAT:
 * NotificationPanel renders the in-app inbox list used by teacher and mentor
 * workspaces.
 * WHY:
 * Notifications should share one calm, high-signal UI pattern so review alerts
 * do not become scattered across role screens.
 * HOW:
 * Render the unread count, show each notification as a tappable card, and fall
 * back to an empty-state message when the inbox is clear.
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
  });

  final String title;
  final String subtitle;
  final List<AppNotification> notifications;
  final int unreadCount;
  final String emptyMessage;
  final ValueChanged<AppNotification> onTapNotification;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      colors: const [Color(0xFFFFFBF2), Color(0xFFFFF0D3)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  unreadCount == 0 ? 'All read' : '$unreadCount unread',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppPalette.navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.section),
          if (notifications.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.item),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Text(
                emptyMessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppPalette.textMuted,
                ),
              ),
            )
          else
            ...notifications.map(
              (notification) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.compact),
                child: _NotificationCard(
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
  });

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
          padding: const EdgeInsets.all(AppSpacing.item),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    notification.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (!notification.isRead)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppPalette.sun.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'New',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppPalette.navy,
                        ),
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
              const SizedBox(height: 8),
              Text(
                notification.message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if ((notification.studentName ?? '').isNotEmpty ||
                  (notification.criterionTitle ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if ((notification.studentName ?? '').isNotEmpty)
                      _MiniPill(label: notification.studentName!),
                    if ((notification.criterionTitle ?? '').isNotEmpty)
                      _MiniPill(label: notification.criterionTitle!),
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
  const _MiniPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppPalette.backgroundTop,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppPalette.navy,
        ),
      ),
    );
  }
}
