import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'design_tokens.dart';
import 'locale_controller.dart';
import 'notification_badges_controller.dart';
import 'panel_blocks_controller.dart';

/// Settings for a notifications block: how many rows it shows, and - when
/// Android is not handing anything over - the way to fix that.
///
/// The permission is the whole first half of this screen rather than a line
/// at the bottom, because without it the block is an empty card and there is
/// nothing else worth adjusting.
class NotificationsBlockSettingsScreen extends StatefulWidget {
  const NotificationsBlockSettingsScreen({super.key, required this.blockId});

  final String blockId;

  @override
  State<NotificationsBlockSettingsScreen> createState() =>
      _NotificationsBlockSettingsScreenState();
}

class _NotificationsBlockSettingsScreenState
    extends State<NotificationsBlockSettingsScreen> {
  /// Null until asked - "not known yet" must not be drawn as "refused".
  NotificationAccess? _access;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final access = await NotificationCounts.state();
    if (!mounted) return;
    setState(() => _access = access);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        final design = context.design;
        return ValueListenableBuilder<List<PanelBlock>>(
          valueListenable: PanelBlocksController.instance,
          builder: (context, blocks, child) {
            final block = PanelBlocksController.instance.byId(widget.blockId);
            // Deleted from this very screen.
            if (block == null) return const SizedBox.shrink();
            final access = _access;
            return Scaffold(
              appBar: AppBar(
                title: Text(s.notifications),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: s.deleteBlock,
                    onPressed: () async {
                      await PanelBlocksController.instance.remove(block.id);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    s.notificationsHint,
                    style: TextStyle(color: design.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  if (access != null && !access.working) ...[
                    // The same three-state wording the badge settings use,
                    // and the same two ways out: the Android screen, and -
                    // when that switch will not stay on at all - this app's
                    // own page, where "Allow restricted settings" sits.
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        access.stalled
                            ? Icons.sync_problem_outlined
                            : Icons.lock_outline,
                      ),
                      title: Text(
                        access.stalled
                            ? s.pinnedBadgesPermissionStalled
                            : s.pinnedBadgesPermission,
                      ),
                      subtitle: Text(
                        access.stalled
                            ? s.pinnedBadgesPermissionStalledHint
                            : s.pinnedBadgesPermissionHint,
                      ),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () async {
                        await NotificationCounts.requestPermission();
                        await _check();
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.app_settings_alt_outlined),
                      title: Text(s.pinnedBadgesRestricted),
                      subtitle: Text(s.pinnedBadgesRestrictedHint),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () async {
                        await NotificationCounts.openAppSettings();
                        await _check();
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    '${s.notificationsCount} (${block.daysAhead})',
                    style: TextStyle(
                      fontSize: design.typeLabel,
                      fontWeight: FontWeight.bold,
                      color: design.textSecondary,
                    ),
                  ),
                  Slider(
                    value: block.daysAhead.toDouble().clamp(1, 20),
                    min: 1,
                    max: 20,
                    divisions: 19,
                    onChanged: (value) => PanelBlocksController.instance.update(
                      block.copyWith(daysAhead: value.round()),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
