import 'package:flutter/material.dart';

import 'app_icon.dart';
import 'app_launcher.dart';
import 'app_pairs_controller.dart';
import 'app_strings.dart';
import 'design_tokens.dart';
import 'launcher_entries_controller.dart';
import 'launcher_entry.dart';
import 'locale_controller.dart';
import 'text_prompt_dialog.dart';

/// Where app pairs are made: two apps, a name, and from then on one entry
/// that opens both side by side.
///
/// The screen says so itself when the phone cannot do it. A split screen
/// needs Android 7 or newer, and some manufacturers switch it off entirely
/// on small screens - offering a pair that will silently open one app is
/// worse than saying up front that this one cannot.
class AppPairsSettingsScreen extends StatefulWidget {
  const AppPairsSettingsScreen({super.key});

  @override
  State<AppPairsSettingsScreen> createState() => _AppPairsSettingsScreenState();
}

class _AppPairsSettingsScreenState extends State<AppPairsSettingsScreen> {
  /// Null until asked. Three states, not two: "not yet known" must not look
  /// like "no", or the screen flashes a warning on every open.
  bool? _supported;

  @override
  void initState() {
    super.initState();
    AppPairsController.instance.load();
    LauncherEntriesController.instance.load();
    _checkSupport();
  }

  Future<void> _checkSupport() async {
    final supported = await AppLauncher.supportsSplitScreen();
    if (!mounted) return;
    setState(() => _supported = supported);
  }

  /// Only installed apps. A web app opens a browser and a folder opens a
  /// sheet - neither is a window Android can put beside another one, so
  /// offering them here would be offering something that cannot work.
  List<LauncherEntry> get _candidates => [
    for (final entry in LauncherEntriesController.instance.entries)
      if (entry.app != null) entry,
  ];

  Future<void> _create(AppStrings s) async {
    final first = await _pickApp(s, s.appPairPickFirst);
    if (first == null || !mounted) return;
    final second = await _pickApp(s, s.appPairPickSecond, exclude: first);
    if (second == null || !mounted) return;

    final name = await showDialog<String>(
      context: context,
      builder: (context) => TextPromptDialog(
        title: s.appPairName,
        label: s.appPairName,
        // Offered rather than imposed: it is almost always too long for an
        // icon, but it is a better starting point than an empty field.
        initialValue: '${first.name} + ${second.name}',
        s: s,
      ),
    );
    if (name == null || name.trim().isEmpty) return;

    await AppPairsController.instance.add(
      name,
      first.app!.packageName,
      second.app!.packageName,
    );
  }

  Future<LauncherEntry?> _pickApp(
    AppStrings s,
    String title, {
    LauncherEntry? exclude,
  }) {
    final options = [
      for (final entry in _candidates)
        if (entry.key != exclude?.key) entry,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return showDialog<LauncherEntry>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final entry = options[index];
              return ListTile(
                leading: AppIcon(entry: entry, size: 32),
                title: Text(entry.name),
                onTap: () => Navigator.of(context).pop(entry),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(s.cancel),
          ),
        ],
      ),
    );
  }

  String _describe(AppPair pair) {
    final first = LauncherEntriesController.instance.byKey(pair.first);
    final second = LauncherEntriesController.instance.byKey(pair.second);
    // Falls back to the package name rather than to nothing: a pair whose
    // app was uninstalled should say which one is missing, not go blank.
    return '${first?.name ?? pair.first} · ${second?.name ?? pair.second}';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        final design = context.design;
        return Scaffold(
          appBar: AppBar(title: Text(s.appPairs)),
          floatingActionButton: _supported == false
              ? null
              : FloatingActionButton(
                  onPressed: () => _create(s),
                  child: const Icon(Icons.add),
                ),
          body: ValueListenableBuilder<List<AppPair>>(
            valueListenable: AppPairsController.instance,
            builder: (context, pairs, child) {
              return ListView(
                padding: EdgeInsets.all(design.spaceMd),
                children: [
                  Text(
                    s.appPairsHint,
                    style: TextStyle(color: design.textSecondary),
                  ),
                  if (_supported == false) ...[
                    SizedBox(height: design.spaceMd),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: design.textSecondary),
                        SizedBox(width: design.spaceSm),
                        Expanded(
                          child: Text(
                            s.appPairsUnsupported,
                            style: TextStyle(color: design.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: design.spaceMd),
                  if (pairs.isEmpty && _supported != false)
                    Text(
                      s.appPairsNone,
                      style: design.textStyle(TypeRole.caption),
                    ),
                  for (final pair in pairs)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.vertical_split_outlined),
                      title: Text(pair.name),
                      subtitle: Text(_describe(pair)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: s.deleteBlock,
                        onPressed: () =>
                            AppPairsController.instance.remove(pair.id),
                      ),
                      onTap: () async {
                        final name = await showDialog<String>(
                          context: context,
                          builder: (context) => TextPromptDialog(
                            title: s.appPairName,
                            label: s.appPairName,
                            initialValue: pair.name,
                            s: s,
                          ),
                        );
                        if (name == null || name.trim().isEmpty) return;
                        await AppPairsController.instance.update(
                          AppPair(
                            id: pair.id,
                            name: name.trim(),
                            first: pair.first,
                            second: pair.second,
                          ),
                        );
                      },
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
