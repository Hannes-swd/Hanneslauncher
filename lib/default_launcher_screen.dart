import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'default_launcher_controller.dart';
import 'locale_controller.dart';

/// Explains how to make this the app the home button opens, and offers the
/// one button that gets there directly.
///
/// The written steps stay on screen even when the button works: which of
/// Android's screens actually opens differs by version and manufacturer, so
/// the text has to cover the case where none of them does.
class DefaultLauncherScreen extends StatefulWidget {
  const DefaultLauncherScreen({super.key});

  @override
  State<DefaultLauncherScreen> createState() => _DefaultLauncherScreenState();
}

class _DefaultLauncherScreenState extends State<DefaultLauncherScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DefaultLauncherController.instance.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The default is set outside this app, so the answer can only have
  /// changed while it was in the background - coming back is exactly when to
  /// look again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      DefaultLauncherController.instance.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return ValueListenableBuilder<DefaultLauncherState>(
          valueListenable: DefaultLauncherController.instance,
          builder: (context, state, child) {
            return Scaffold(
              appBar: AppBar(title: Text(s.defaultLauncher)),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _status(s, state),
                  const SizedBox(height: 16),
                  if (!state.isDefault) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: () => chooseDefaultLauncher(context, s),
                        icon: const Icon(Icons.home_outlined),
                        label: Text(s.setAsDefaultLauncher),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(s.defaultLauncherSteps),
                    const SizedBox(height: 16),
                    Text(
                      s.defaultLauncherManual,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _status(AppStrings s, DefaultLauncherState state) {
    if (state.isDefault) {
      return Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Color(0xFF2E7D32)),
          const SizedBox(width: 12),
          Expanded(child: Text(s.defaultLauncherIsDefault)),
        ],
      );
    }
    return Text(
      state.otherName == null
          ? s.defaultLauncherNone
          : s.defaultLauncherCurrently(state.otherName!),
      style: const TextStyle(color: Colors.black54),
    );
  }
}

/// Sends the user to Android's own picker. Shared by the screen and the card
/// in the settings, including the one case worth reporting: Android offering
/// no screen at all, where the written steps are all that's left.
Future<void> chooseDefaultLauncher(BuildContext context, AppStrings s) async {
  final opened = await DefaultLauncherController.instance.chooseDefault();
  if (opened || !context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(s.defaultLauncherOpenFailed)));
}

/// The one nudge a fresh install gets: shown on startup when the home button
/// still opens another launcher, and never again afterwards.
///
/// Once, because someone who installed this on purpose only needs telling
/// once - and because a launcher that isn't the home app is otherwise a dead
/// end nobody stumbles over: it opens by tapping its icon, so the reason it
/// exists never happens and nothing points at why. Where to do it later is
/// part of the text, since this is the only time it asks.
Future<void> showDefaultLauncherPrompt(BuildContext host) {
  return showDialog<void>(
    context: host,
    builder: (dialogContext) {
      return ValueListenableBuilder<AppLanguage>(
        valueListenable: LocaleController.instance,
        builder: (context, language, child) {
          final s = AppStrings(language);
          return AlertDialog(
            title: Text(s.defaultLauncherCardTitle),
            content: Text(
              '${s.defaultLauncherCardText}\n\n${s.defaultLauncherFindAgain}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(s.later),
              ),
              FilledButton(
                onPressed: () {
                  // Closed first: what comes next is Android's own dialog or
                  // settings screen, and coming back to a dialog that is
                  // still open would be asking again about something that
                  // has just been answered. The screen behind it is what
                  // carries on from here - the dialog's own context is gone
                  // by then, snack bar included.
                  Navigator.of(dialogContext).pop();
                  chooseDefaultLauncher(host, s);
                },
                child: Text(s.setAsDefaultLauncher),
              ),
            ],
          );
        },
      );
    },
  );
}

/// The nudge at the top of the settings while this isn't the home app -
/// which is the state a fresh install is in, and the one where an app that
/// only opens by tapping its own icon looks broken.
///
/// Nothing to dismiss: it disappears by itself the moment it's no longer
/// true, so it can't get in the way permanently.
class DefaultLauncherCard extends StatelessWidget {
  const DefaultLauncherCard({super.key, required this.s});

  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DefaultLauncherState>(
      valueListenable: DefaultLauncherController.instance,
      builder: (context, state, child) {
        // Nothing until the first answer is in, so this can't flash up at
        // someone for whom it was never true.
        if (!state.checked || state.isDefault) return const SizedBox.shrink();
        return Card(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.home_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        s.defaultLauncherCardTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(s.defaultLauncherCardText),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton(
                      onPressed: () => chooseDefaultLauncher(context, s),
                      child: Text(s.setAsDefaultLauncher),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const DefaultLauncherScreen(),
                        ),
                      ),
                      child: Text(s.defaultLauncherHowTo),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
