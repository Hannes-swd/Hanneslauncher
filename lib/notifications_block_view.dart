import 'package:flutter/material.dart';

import 'app_icon.dart';
import 'app_strings.dart';
import 'design_tokens.dart';
import 'haptics.dart';
import 'launcher_entries_controller.dart';
import 'notification_badges_controller.dart';
import 'notifications_controller.dart';
import 'panel_blocks_controller.dart';

/// What is waiting, on the panel.
///
/// The launcher already holds Android's notification access - it is what the
/// badge on a pinned icon counts with. Having the access and showing only a
/// number meant the panel, the thing you pull down from the top of the
/// screen, was the one pull-down on the phone that could not tell you what
/// had arrived; the system shade above it could, and you had to use both.
///
/// So this block draws them: tap to go where the notification points, swipe
/// to clear it. See [NotificationsController] for what is and is not read.
class NotificationsBlockView extends StatefulWidget {
  const NotificationsBlockView({
    super.key,
    required this.block,
    required this.s,
  });

  final PanelBlock block;
  final AppStrings s;

  @override
  State<NotificationsBlockView> createState() => _NotificationsBlockViewState();
}

class _NotificationsBlockViewState extends State<NotificationsBlockView> {
  /// Asked for once when the block is built, which is when the panel opens.
  /// Three states again, as everywhere this permission is touched: null is
  /// "not asked yet" and must not be drawn as a refusal.
  NotificationAccess? _access;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final access = await NotificationCounts.state();
    if (!mounted) return;
    setState(() => _access = access);
  }

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final s = widget.s;
    final access = _access;
    if (access != null && !access.working) {
      return _Missing(s: s, access: access, onRetry: _checkAccess);
    }
    return ValueListenableBuilder<List<WaitingNotification>>(
      valueListenable: NotificationsController.instance,
      builder: (context, waiting, child) {
        if (waiting.isEmpty) {
          return Text(
            s.notificationsNoneWaiting,
            style: design.textStyle(TypeRole.caption),
          );
        }
        // Capped by the block's own setting rather than scrolled: the panel
        // scrolls as a whole, and a list that scrolls inside a list that
        // scrolls is a thing nobody can aim at.
        final limit = widget.block.daysAhead.clamp(1, 20);
        final shown = waiting.take(limit).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final notification in shown)
              _NotificationRow(notification: notification, s: s),
            if (waiting.length > shown.length)
              Padding(
                padding: EdgeInsets.only(top: design.spaceSm),
                child: Text(
                  s.notificationsMore(waiting.length - shown.length),
                  style: design.textStyle(TypeRole.caption),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification, required this.s});

  final WaitingNotification notification;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final entry = LauncherEntriesController.instance.byKey(
      notification.package,
    );
    return Dismissible(
      key: ValueKey(notification.key),
      // Either way, because a swipe has no preferred direction here - this
      // is the same gesture the system shade takes, and it takes both.
      onDismissed: (_) {
        Haptics.fire(HapticEvent.snap);
        NotificationsController.instance.dismiss(notification);
      },
      background: const SizedBox.shrink(),
      child: InkWell(
        onTap: () async {
          final opened = await NotificationsController.instance.open(
            notification,
          );
          // Nothing to open is not a failure worth a message - plenty of
          // notifications are purely informational - but the tap should
          // still not look ignored, so it clears instead.
          if (!opened) {
            await NotificationsController.instance.dismiss(notification);
          }
        },
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: design.spaceSm / 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: design.typeBody * 1.6,
                child: entry == null
                    // An app with no entry is one in the secret folder or one
                    // uninstalled since it posted. A neutral glyph rather
                    // than nothing, so the row still lines up.
                    ? Icon(
                        Icons.notifications_none,
                        size: design.typeBody * 1.3,
                        color: design.textSecondary,
                      )
                    : AppIcon(entry: entry, size: design.typeBody * 1.3),
              ),
              SizedBox(width: design.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (notification.title.isNotEmpty)
                      Text(
                        notification.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: design.textStyle(TypeRole.body),
                      ),
                    if (notification.text.isNotEmpty)
                      Text(
                        notification.text,
                        // Two lines, not one: a message cut off after four
                        // words is a row that makes you open the app to find
                        // out what it said, which is the thing this block
                        // exists to save.
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: design.textStyle(TypeRole.caption),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown in place of the list while Android is not handing anything over.
///
/// Says which of the two halves is missing and offers the screen that fixes
/// it, exactly as the badge settings do - "switched off" and "switched on
/// but not actually connected" look identical from here and need different
/// things done about them.
class _Missing extends StatelessWidget {
  const _Missing({
    required this.s,
    required this.access,
    required this.onRetry,
  });

  final AppStrings s;
  final NotificationAccess access;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          // The same two answers the badge settings give, for the same
          // reason: switched off and switched on but not handing anything
          // over look identical from here and need different things done.
          access.stalled
              ? s.pinnedBadgesPermissionStalledHint
              : s.pinnedBadgesPermissionHint,
          style: design.textStyle(TypeRole.caption),
        ),
        SizedBox(height: design.spaceSm),
        TextButton(
          onPressed: () async {
            await NotificationCounts.requestPermission();
            // Rechecked on return rather than assumed: the Android screen
            // can be left without the switch being touched.
            await onRetry();
          },
          child: Text(
            access.stalled
                ? s.pinnedBadgesPermissionStalled
                : s.pinnedBadgesPermission,
          ),
        ),
      ],
    );
  }
}
