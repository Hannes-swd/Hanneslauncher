import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_strings.dart';
import 'design_tokens.dart';
import 'feedback_mail.dart';
import 'locale_controller.dart';
import 'update_controller.dart';

/// Two buttons that hand a finished mail to the mail app: one for something
/// that is broken, one for something that is missing.
///
/// Deliberately not a form inside the app. A form here would need a server
/// to post to, a queue for when the phone is offline, and a way to answer -
/// the mail app already is all three, and the mail leaves from an address
/// its sender can be replied to at.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  static const _channel = MethodChannel('hanneslauncher/app_info');

  FeedbackEnvironment _environment = const FeedbackEnvironment();

  @override
  void initState() {
    super.initState();
    _loadEnvironment();
  }

  /// Reads the phone and the version once, when the screen opens. Nothing
  /// here can change while it is open, and doing it now rather than on the
  /// tap keeps the button from waiting on a channel call.
  Future<void> _loadEnvironment() async {
    Map<String, dynamic>? device;
    try {
      device = await _channel.invokeMapMethod<String, dynamic>('device');
    } catch (_) {
      // Not Android, or the channel isn't there: the mail simply goes
      // without those lines, see [FeedbackEnvironment.lines].
    }
    if (!mounted) return;
    setState(() {
      _environment = FeedbackEnvironment(
        appVersion: UpdateController.instance.value.installedVersion,
        device: describeDevice(
          device?['manufacturer'] as String? ?? '',
          device?['model'] as String? ?? '',
        ),
        androidVersion: describeAndroid(
          device?['androidRelease'] as String? ?? '',
          device?['sdkInt'] as int? ?? 0,
        ),
        // Spelled out in English, like the rest of the mail.
        language: LocaleController.instance.value == AppLanguage.en
            ? 'English'
            : 'German',
      );
    });
  }

  Future<void> _send(FeedbackKind kind, AppStrings s) async {
    var opened = false;
    try {
      opened = await launchUrl(
        feedbackMailto(kind, _environment),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // No app answers `mailto:` at all - on Android that throws rather
      // than coming back false.
      opened = false;
    }
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.feedbackNoMailApp),
        action: SnackBarAction(
          label: s.feedbackCopyAddress,
          onPressed: () => _copyAddress(s),
        ),
      ),
    );
  }

  Future<void> _copyAddress(AppStrings s) async {
    await Clipboard.setData(const ClipboardData(text: kFeedbackAddress));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(s.feedbackAddressCopied)));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return Scaffold(
          appBar: AppBar(title: Text(s.feedback)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                s.feedbackIntro,
                style: TextStyle(color: context.design.textSecondary),
              ),
              const SizedBox(height: 24),
              _action(
                context: context,
                icon: Icons.bug_report_outlined,
                label: s.feedbackReportBug,
                hint: s.feedbackReportBugHint,
                primary: true,
                onPressed: () => _send(FeedbackKind.bug, s),
              ),
              const SizedBox(height: 24),
              _action(
                context: context,
                icon: Icons.lightbulb_outline,
                label: s.feedbackSuggestIdea,
                hint: s.feedbackSuggestIdeaHint,
                primary: false,
                onPressed: () => _send(FeedbackKind.idea, s),
              ),
              const SizedBox(height: 32),
              Text(
                s.feedbackEnglishNote,
                style: TextStyle(
                  color: context.design.textSecondary,
                  fontSize: context.design.typeLabel,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                s.feedbackWhatIsSent,
                style: TextStyle(
                  color: context.design.textSecondary,
                  fontSize: context.design.typeLabel,
                ),
              ),
              const SizedBox(height: 24),
              // The address in plain sight, so the page is still useful on a
              // phone with no mail app set up at all.
              Text(
                s.feedbackAddress,
                style: TextStyle(
                  color: context.design.textSecondary,
                  fontSize: context.design.typeLabel,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      kFeedbackAddress,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _copyAddress(s),
                    icon: const Icon(Icons.copy_outlined),
                    tooltip: s.feedbackCopyAddress,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// One of the two buttons with its one-line explanation underneath, so
  /// which mail a tap opens is readable before tapping it.
  Widget _action({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String hint,
    required bool primary,
    required VoidCallback onPressed,
  }) {
    final button = primary
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(alignment: Alignment.centerLeft, child: button),
        const SizedBox(height: 8),
        Text(
          hint,
          style: TextStyle(
            color: context.design.textSecondary,
            fontSize: context.design.typeLabel,
          ),
        ),
      ],
    );
  }
}
