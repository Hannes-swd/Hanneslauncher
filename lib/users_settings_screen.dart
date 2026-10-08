import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'design_tokens.dart';
import 'haptics.dart';
import 'locale_controller.dart';
import 'users_controller.dart';

/// What a user is called on screen. The main user has no name of its own
/// until it is given one, so it reads "Standard" or "Main" in whichever
/// language is on.
String userDisplayName(LauncherUser user, AppStrings s) =>
    user.name.isNotEmpty ? user.name : (user.isMain ? s.mainUser : user.id);

/// The icons a user can be shown with, by the name [LauncherUser.icon]
/// stores. Things a home screen tends to be *for* - work, a hobby, the
/// night - rather than a set of faces, because what tells two of them
/// apart at a glance is what they are used for.
const Map<String, IconData> userIcons = {
  'person': Icons.person_outline,
  'home': Icons.home_outlined,
  'work': Icons.work_outline,
  'school': Icons.school_outlined,
  'book': Icons.menu_book_outlined,
  'code': Icons.code,
  'game': Icons.sports_esports_outlined,
  'music': Icons.music_note_outlined,
  'camera': Icons.camera_alt_outlined,
  'palette': Icons.palette_outlined,
  'fitness': Icons.fitness_center,
  'nature': Icons.park_outlined,
  'travel': Icons.flight_outlined,
  'beach': Icons.beach_access_outlined,
  'car': Icons.directions_car_outlined,
  'coffee': Icons.local_cafe_outlined,
  'shop': Icons.shopping_bag_outlined,
  'party': Icons.celebration_outlined,
  'heart': Icons.favorite_border,
  'star': Icons.star_border,
  'sun': Icons.wb_sunny_outlined,
  'night': Icons.bedtime_outlined,
  'pets': Icons.pets,
  'child': Icons.child_care,
};

/// A user as a round badge: their icon, or their initial when they have
/// none. Filled with the accent while [active].
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.user,
    required this.s,
    this.size = 32,
    this.active = false,
  });

  final LauncherUser user;
  final AppStrings s;
  final double size;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final ink = active ? design.onAccent : design.textPrimary;
    final icon = userIcons[user.icon];
    final name = userDisplayName(user, s);
    return AnimatedContainer(
      duration: design.motionFast,
      curve: design.motionCurve,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? design.accent : design.fillSubtle,
      ),
      child: icon != null
          ? Icon(icon, size: size * 0.56, color: ink)
          : Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: TextStyle(
                fontSize: size * 0.44,
                fontWeight: FontWeight.w600,
                color: ink,
                height: 1,
              ),
            ),
    );
  }
}

/// The users: switch between them, add one, change one's name and icon,
/// delete one.
class UsersSettingsScreen extends StatefulWidget {
  const UsersSettingsScreen({super.key});

  @override
  State<UsersSettingsScreen> createState() => _UsersSettingsScreenState();
}

class _UsersSettingsScreenState extends State<UsersSettingsScreen> {
  // A switch rewrites every setting and has every controller read again;
  // short, but long enough for a second tap to land in the middle of it.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    UsersController.instance.load();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return ValueListenableBuilder<UsersState>(
          valueListenable: UsersController.instance,
          builder: (context, state, child) {
            return Scaffold(
              appBar: AppBar(
                title: Text(s.users),
                bottom: _busy
                    ? const PreferredSize(
                        preferredSize: Size.fromHeight(2),
                        child: LinearProgressIndicator(minHeight: 2),
                      )
                    : null,
              ),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: _busy ? null : () => _add(context, s),
                icon: const Icon(Icons.person_add_alt_outlined),
                label: Text(s.addUser),
              ),
              body: ListView(
                // Room at the bottom so the last row isn't hidden behind the
                // floating button.
                padding: const EdgeInsets.only(bottom: 88),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      s.usersHint,
                      style: TextStyle(color: context.design.textSecondary),
                    ),
                  ),
                  for (final user in state.users)
                    _row(context, s, user, active: user.id == state.activeId),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _row(
    BuildContext context,
    AppStrings s,
    LauncherUser user, {
    required bool active,
  }) {
    return ListTile(
      leading: UserAvatar(user: user, s: s, size: 40, active: active),
      title: Text(userDisplayName(user, s)),
      subtitle: active ? Text(s.userActive) : null,
      enabled: !_busy,
      onTap: active ? null : () => _run(() => _switch(context, s, user)),
      trailing: PopupMenuButton<String>(
        enabled: !_busy,
        onSelected: (choice) {
          switch (choice) {
            case 'edit':
              _edit(context, s, user);
            case 'delete':
              _delete(context, s, user);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: 'edit', child: Text(s.editUser)),
          if (!user.isMain)
            PopupMenuItem(value: 'delete', child: Text(s.deleteUser)),
        ],
      ),
    );
  }

  Future<void> _switch(
    BuildContext context,
    AppStrings s,
    LauncherUser user,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    await UsersController.instance.switchTo(user.id);
    Haptics.fire(HapticEvent.snap);
    messenger.showSnackBar(
      SnackBar(content: Text(s.switchedToUser(userDisplayName(user, s)))),
    );
  }

  Future<void> _add(BuildContext context, AppStrings s) async {
    final result = await showDialog<_UserEdit>(
      context: context,
      builder: (context) => _UserEditDialog(title: s.addUser, s: s),
    );
    if (result == null || !context.mounted) return;
    if (result.name.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.nameRequired)));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    await _run(() async {
      final user = await UsersController.instance.create(
        result.name,
        icon: result.icon,
      );
      // Straight into it: a new user is empty, and the next step is always
      // setting it up.
      await UsersController.instance.switchTo(user.id);
      Haptics.fire(HapticEvent.snap);
      messenger.showSnackBar(
        SnackBar(content: Text(s.newUserReady(userDisplayName(user, s)))),
      );
    });
  }

  Future<void> _edit(
    BuildContext context,
    AppStrings s,
    LauncherUser user,
  ) async {
    final result = await showDialog<_UserEdit>(
      context: context,
      builder: (context) => _UserEditDialog(
        title: s.editUser,
        s: s,
        initialName: userDisplayName(user, s),
        initialIcon: user.icon,
      ),
    );
    if (result == null) return;
    // The main user may go back to having no name - and with it back to
    // "Standard"/"Main" in whichever language is on, which is also what
    // saving that word unchanged means. Any other user needs a name to be
    // told apart by, so an empty one keeps the old name and only the icon
    // is taken.
    final trimmed = result.name.trim();
    final String? name;
    if (user.isMain) {
      name = trimmed == s.mainUser ? '' : trimmed;
    } else {
      name = trimmed.isEmpty ? null : trimmed;
    }
    await UsersController.instance.edit(user.id, name: name, icon: result.icon);
  }

  Future<void> _delete(
    BuildContext context,
    AppStrings s,
    LauncherUser user,
  ) async {
    // Asked first: a user takes its wallpaper, widgets and notes with it.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.deleteUserQuestion(userDisplayName(user, s))),
        content: Text(s.deleteUserWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(s.deleteUserConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() => UsersController.instance.remove(user.id));
  }
}

/// What the edit dialog hands back.
typedef _UserEdit = ({String name, String icon});

/// Name and icon in one dialog - for a new user and for changing one.
///
/// Stateful so it owns its text controller, for the reason
/// text_prompt_dialog.dart gives.
class _UserEditDialog extends StatefulWidget {
  const _UserEditDialog({
    required this.title,
    required this.s,
    this.initialName = '',
    this.initialIcon = '',
  });

  final String title;
  final AppStrings s;
  final String initialName;
  final String initialIcon;

  @override
  State<_UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends State<_UserEditDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  late String _icon = widget.initialIcon;

  @override
  void initState() {
    super.initState();
    // The initial follows the name as it is typed.
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _done() =>
      Navigator.of(context).pop<_UserEdit>((name: _name.text, icon: _icon));

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final design = context.design;
    // Only for the preview tiles: what the choice will look like, with the
    // name as typed so far.
    LauncherUser preview(String icon) =>
        LauncherUser(id: '', name: _name.text.trim(), icon: icon);

    Widget choice(String icon, {String? tooltip}) {
      final tile = InkResponse(
        onTap: () => setState(() => _icon = icon),
        radius: 24,
        child: UserAvatar(
          user: preview(icon),
          s: s,
          size: 40,
          active: icon == _icon,
        ),
      );
      return tooltip == null ? tile : Tooltip(message: tooltip, child: tile);
    }

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: widget.initialName.isEmpty,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: s.userName),
              onSubmitted: (_) => _done(),
            ),
            SizedBox(height: design.spaceLg),
            Text(
              s.userIcon,
              style: TextStyle(
                fontSize: design.typeLabel,
                fontWeight: FontWeight.bold,
                color: design.textSecondary,
              ),
            ),
            SizedBox(height: design.spaceSm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                choice('', tooltip: s.userIconInitial),
                for (final name in userIcons.keys) choice(name),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        TextButton(onPressed: _done, child: Text(s.save)),
      ],
    );
  }
}

/// The quick way between users, at the top left of the panel: one round
/// icon per user, the active one filled. Up to three fit as they are; past
/// that it is two and a "+N" that opens the rest as a dropdown - always
/// with the active user among the two, so the header says who is on.
///
/// Nothing at all while there is only one user, so the header stays what it
/// always was for anyone who never makes a second.
class UserQuickSwitch extends StatelessWidget {
  const UserQuickSwitch({super.key, required this.s});

  final AppStrings s;

  static const int _shownWhenAllFit = 3;
  static const int _shownWithOverflow = 2;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UsersState>(
      valueListenable: UsersController.instance,
      builder: (context, state, child) {
        final users = state.users;
        if (users.length < 2) return const SizedBox.shrink();

        final shown = users.length <= _shownWhenAllFit
            ? users
            : _withActive(users, state.activeId);
        final rest = [
          for (final user in users)
            if (!shown.contains(user)) user,
        ];

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final user in shown)
              _UserButton(
                user: user,
                s: s,
                active: user.id == state.activeId,
              ),
            if (rest.isNotEmpty) _MoreUsers(users: rest, s: s),
          ],
        );
      },
    );
  }

  /// The first two in list order, except that the active user takes the
  /// second place when it isn't one of them.
  static List<LauncherUser> _withActive(
    List<LauncherUser> users,
    String activeId,
  ) {
    final shown = users.take(_shownWithOverflow).toList();
    if (!shown.any((user) => user.id == activeId)) {
      shown[_shownWithOverflow - 1] = users.firstWhere(
        (user) => user.id == activeId,
      );
    }
    return shown;
  }
}

/// One user in the panel header. A tap switches to them; the active one
/// takes no tap - it already is what is on screen.
class _UserButton extends StatelessWidget {
  const _UserButton({
    required this.user,
    required this.s,
    required this.active,
  });

  final LauncherUser user;
  final AppStrings s;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final name = userDisplayName(user, s);
    return Semantics(
      button: true,
      selected: active,
      label: name,
      excludeSemantics: true,
      child: Tooltip(
        message: name,
        child: InkResponse(
          onTap: active ? null : () => _switchTo(user),
          radius: 22,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: UserAvatar(user: user, s: s, size: 32, active: active),
          ),
        ),
      ),
    );
  }
}

/// "+N": the users that did not fit, as a dropdown.
class _MoreUsers extends StatelessWidget {
  const _MoreUsers({required this.users, required this.s});

  final List<LauncherUser> users;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return PopupMenuButton<String>(
      tooltip: s.moreUsers(users.length),
      position: PopupMenuPosition.under,
      onSelected: (id) {
        for (final user in users) {
          if (user.id == id) _switchTo(user);
        }
      },
      itemBuilder: (context) => [
        for (final user in users)
          PopupMenuItem(
            value: user.id,
            child: Row(
              children: [
                UserAvatar(user: user, s: s, size: 28),
                SizedBox(width: design.spaceMd),
                Flexible(
                  child: Text(
                    userDisplayName(user, s),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Container(
          height: 32,
          constraints: const BoxConstraints(minWidth: 32),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: design.fillSubtle,
          ),
          child: Text(
            '+${users.length}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: design.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

void _switchTo(LauncherUser user) {
  Haptics.fire(HapticEvent.snap);
  UsersController.instance.switchTo(user.id);
}
