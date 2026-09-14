import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_icon.dart';
import 'app_strings.dart';
import 'launcher_entries_controller.dart';
import 'launcher_entry.dart';
import 'locale_controller.dart';
import 'secret_apps_controller.dart';

/// Asks for the secret folder's password - or sets one on first use, or takes
/// the recovery code instead - and opens the folder on success. The entry point
/// for the first row of [AppCustomizeScreen]; nothing else may push
/// [_SecretFolderScreen], since only this can produce the unlock it needs.
Future<void> openSecretFolder(BuildContext context) async {
  final controller = SecretAppsController.instance;
  await controller.load();
  if (!context.mounted) return;
  final s = AppStrings(LocaleController.instance.value);

  if (!controller.hasPassword) {
    await _firstRun(context, s);
    return;
  }

  final result = await showDialog<_PasswordResult>(
    context: context,
    builder: (context) => _PasswordDialog(
      s: s,
      title: s.enterPassword,
      confirm: false,
      // No way past the prompt is offered when there is nothing to offer -
      // a folder restored from a backup without the code has none.
      allowRecovery: controller.hasRecoveryCode,
    ),
  );
  if (result == null || !context.mounted) return;

  if (result.recovery) {
    await _recover(context, s);
    return;
  }

  final unlock = controller.unlock(result.password);
  if (!context.mounted) return;
  if (unlock == null) {
    _say(context, s.wrongPassword);
    return;
  }
  await _openFolder(context, unlock);
}

/// First use: password, then the recovery code that goes with it. The code is
/// made right here rather than being offered later, because "later" is after
/// the password has been forgotten.
Future<void> _firstRun(BuildContext context, AppStrings s) async {
  final chosen = await showDialog<_PasswordResult>(
    context: context,
    builder: (context) => _PasswordDialog(
      s: s,
      title: s.setPassword,
      // Typed twice: a typo here would lock the folder before there is any
      // code to get back in with.
      confirm: true,
      allowRecovery: false,
      note: s.secretFolderNoRecovery,
    ),
  );
  if (chosen == null || !context.mounted) return;

  final unlock = await SecretAppsController.instance.setPassword(
    chosen.password,
  );
  if (unlock == null || !context.mounted) return;

  await _showNewRecoveryCode(context, s, unlock);
  if (!context.mounted) return;
  await _openFolder(context, unlock);
}

/// The way back in: the code, then a new password straight away, then a fresh
/// code to replace the one just used.
///
/// Cancelling along the way is safe - the old password and the old code both
/// keep working, so a half-finished recovery cannot lock the folder.
Future<void> _recover(BuildContext context, AppStrings s) async {
  final code = await showDialog<String>(
    context: context,
    builder: (context) => _RecoveryCodeEntryDialog(s: s),
  );
  if (code == null || !context.mounted) return;

  final unlock = SecretAppsController.instance.unlockWithRecoveryCode(code);
  if (!context.mounted) return;
  if (unlock == null) {
    _say(context, s.wrongRecoveryCode);
    return;
  }

  final chosen = await showDialog<_PasswordResult>(
    context: context,
    builder: (context) => _PasswordDialog(
      s: s,
      title: s.setNewPassword,
      confirm: true,
      allowRecovery: false,
    ),
  );
  if (!context.mounted) return;

  if (chosen != null) {
    final changed = await SecretAppsController.instance.changePassword(
      unlock,
      chosen.password,
    );
    if (!context.mounted) return;
    // A code that has been used is a code that has been out in the open, so
    // it is retired together with the password it just replaced.
    if (changed) await _showNewRecoveryCode(context, s, unlock);
    if (!context.mounted) return;
  }

  await _openFolder(context, unlock);
}

Future<void> _showNewRecoveryCode(
  BuildContext context,
  AppStrings s,
  SecretUnlock unlock,
) async {
  final code = await SecretAppsController.instance.newRecoveryCode(unlock);
  if (code == null || !context.mounted) return;
  await showDialog<void>(
    context: context,
    // Not dismissible by tapping beside it: this is the one moment the code
    // can be read.
    barrierDismissible: false,
    builder: (context) => _RecoveryCodeDialog(s: s, code: code),
  );
}

Future<void> _openFolder(BuildContext context, SecretUnlock unlock) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => _SecretFolderScreen(unlock: unlock),
    ),
  );
}

void _say(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// The unlocked folder: the hidden apps, the way back out for each of them,
/// and a picker to put another one in.
///
/// Adding is only possible from in here, which is the point - otherwise
/// anyone holding the phone could hide apps without knowing the password.
class _SecretFolderScreen extends StatefulWidget {
  const _SecretFolderScreen({required this.unlock});

  final SecretUnlock unlock;

  @override
  State<_SecretFolderScreen> createState() => _SecretFolderScreenState();
}

class _SecretFolderScreenState extends State<_SecretFolderScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Locks again as soon as the launcher leaves the foreground - which is
  /// exactly what starting a secret app from here does, so the folder is
  /// never left standing open behind an app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused) return;
    SecretAppsController.instance.lock();
    if (!mounted) return;
    // Any dialog on top of this screen first (a password prompt, the app
    // picker), then the screen itself - a plain pop() would only close the
    // dialog and leave the folder standing open.
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    navigator.popUntil((candidate) => candidate == route);
    navigator.pop();
  }

  Future<void> _openOptions(LauncherEntry entry, AppStrings s) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(entry.name),
        children: [
          _option(context, Icons.open_in_new, s.openApp, 'open'),
          _option(
            context,
            Icons.visibility_outlined,
            s.removeFromSecretFolder,
            'remove',
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'open':
        await entry.launch();
      case 'remove':
        await SecretAppsController.instance.remove(widget.unlock, entry.key);
    }
  }

  /// Offers what is currently visible in the app list, narrowed to apps and
  /// web apps: a folder or one of the launcher's own screens has nothing to
  /// hide, and hiding one would only produce odd corners elsewhere.
  Future<void> _addApp(AppStrings s) async {
    final candidates = [
      for (final entry in LauncherEntriesController.instance.entries)
        if (entry.app != null || entry.isWebApp) entry,
    ];

    final key = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(s.whichApp),
        children: [
          for (final entry in candidates)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(entry.key),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: AppIcon(entry: entry, size: 36),
                title: Text(entry.name),
              ),
            ),
        ],
      ),
    );
    if (key == null) return;

    final wasPinned = await SecretAppsController.instance.add(
      widget.unlock,
      key,
    );
    if (wasPinned && mounted) _say(context, s.secretAppUnpinned);
  }

  Future<void> _changePassword(AppStrings s) async {
    final chosen = await showDialog<_PasswordResult>(
      context: context,
      builder: (context) => _PasswordDialog(
        s: s,
        title: s.changePassword,
        confirm: true,
        allowRecovery: false,
      ),
    );
    if (chosen == null || !mounted) return;
    final changed = await SecretAppsController.instance.changePassword(
      widget.unlock,
      chosen.password,
    );
    if (changed && mounted) _say(context, s.passwordChanged);
  }

  Future<void> _replaceRecoveryCode(AppStrings s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.newRecoveryCode),
        content: Text(s.newRecoveryCodeNote),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(s.save),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _showNewRecoveryCode(context, s, widget.unlock);
  }

  Widget _option(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return SimpleDialogOption(
      onPressed: () => Navigator.of(context).pop(value),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return Scaffold(
          appBar: AppBar(
            title: Text(s.secretFolder),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) => value == 'password'
                    ? _changePassword(s)
                    : _replaceRecoveryCode(s),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'password',
                    child: Text(s.changePassword),
                  ),
                  PopupMenuItem(value: 'code', child: Text(s.newRecoveryCode)),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _addApp(s),
            icon: const Icon(Icons.add),
            label: Text(s.addToSecretFolder),
          ),
          body: ListenableBuilder(
            // Both: the entry list for renames and newly installed apps, the
            // secret list for what was just put in or taken out.
            listenable: Listenable.merge([
              LauncherEntriesController.instance,
              SecretAppsController.instance,
            ]),
            builder: (context, child) {
              final entries = LauncherEntriesController.instance.secretEntries(
                widget.unlock,
              );
              return ListView(
                // Room at the bottom so the last row isn't hidden behind the
                // floating button.
                padding: const EdgeInsets.only(bottom: 88),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      s.secretFolderWarning,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                  if (entries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        s.secretFolderEmpty,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
                  for (final entry in entries)
                    ListTile(
                      leading: AppIcon(entry: entry, size: 36),
                      title: Text(entry.name),
                      onTap: () => _openOptions(entry, s),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// What a password prompt comes back with: either what was typed, or the wish
/// to use the recovery code instead.
class _PasswordResult {
  const _PasswordResult.typed(this.password) : recovery = false;
  const _PasswordResult.recovery() : password = '', recovery = true;

  final String password;
  final bool recovery;
}

/// Password prompt. Pops a [_PasswordResult], or null when cancelled.
///
/// Stateful so it owns its controllers - see [TextPromptDialog] for why that
/// matters with a dialog that is still animating out.
class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({
    required this.s,
    required this.title,
    required this.confirm,
    required this.allowRecovery,
    this.note,
  });

  final AppStrings s;
  final String title;

  /// Whether a second field has to match - used when a password is being set,
  /// where a typo would otherwise lock the folder.
  final bool confirm;

  /// Whether to offer the recovery code as a way past this prompt.
  final bool allowRecovery;

  /// Shown small under the fields, for the note about what happens if both the
  /// password and the code are lost.
  final String? note;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final TextEditingController _field = TextEditingController();
  final TextEditingController _repeatField = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _field.dispose();
    _repeatField.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _field.text;
    if (password.isEmpty) return;
    if (widget.confirm && password != _repeatField.text) {
      setState(() => _error = widget.s.passwordsDiffer);
      return;
    }
    Navigator.of(context).pop(_PasswordResult.typed(password));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _field,
            autofocus: true,
            obscureText: true,
            textInputAction: widget.confirm
                ? TextInputAction.next
                : TextInputAction.done,
            decoration: InputDecoration(
              labelText: s.passwordLabel,
              errorText: _error,
            ),
            onSubmitted: widget.confirm ? null : (_) => _submit(),
          ),
          if (widget.confirm)
            TextField(
              controller: _repeatField,
              obscureText: true,
              decoration: InputDecoration(labelText: s.passwordRepeatLabel),
              onSubmitted: (_) => _submit(),
            ),
          if (widget.allowRecovery)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(const _PasswordResult.recovery()),
                child: Text(s.forgotPassword),
              ),
            ),
          if (widget.note != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                widget.note!,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        TextButton(onPressed: _submit, child: Text(s.save)),
      ],
    );
  }
}

/// Asks for the recovery code. Not obscured: it is being copied from paper,
/// and hiding it would only make a twenty-character code harder to get right.
class _RecoveryCodeEntryDialog extends StatefulWidget {
  const _RecoveryCodeEntryDialog({required this.s});

  final AppStrings s;

  @override
  State<_RecoveryCodeEntryDialog> createState() =>
      _RecoveryCodeEntryDialogState();
}

class _RecoveryCodeEntryDialogState extends State<_RecoveryCodeEntryDialog> {
  final TextEditingController _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return AlertDialog(
      title: Text(s.enterRecoveryCode),
      content: TextField(
        controller: _field,
        autofocus: true,
        autocorrect: false,
        enableSuggestions: false,
        textCapitalization: TextCapitalization.characters,
        style: const TextStyle(fontFamily: 'monospace'),
        decoration: InputDecoration(labelText: s.recoveryCode),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_field.text),
          child: Text(s.save),
        ),
      ],
    );
  }
}

/// Shows a freshly made recovery code - the one and only time it is readable.
class _RecoveryCodeDialog extends StatelessWidget {
  const _RecoveryCodeDialog({required this.s, required this.code});

  final AppStrings s;
  final String code;

  @override
  Widget build(BuildContext context) {
    // Not dismissible by the back button either: the code is already stored by
    // the time this shows, so backing out would leave a code in place that
    // nobody has ever read.
    return PopScope(canPop: false, child: _dialog(context));
  }

  Widget _dialog(BuildContext context) {
    return AlertDialog(
      title: Text(s.recoveryCode),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            code,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 20,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            s.recoveryCodeIntro,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: code));
            if (context.mounted) _say(context, s.codeCopied);
          },
          child: Text(s.copyCode),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.savedTheCode),
        ),
      ],
    );
  }
}
