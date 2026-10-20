import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'design_tokens.dart';
import 'intro_tutorial_controller.dart';
import 'locale_controller.dart';

/// The card that says what to do next, drawn over the real screen.
///
/// Only the card takes touches. Everything around it passes straight through,
/// so the gesture is made on the real home screen, the real list, the real
/// panel - the card just says which one.
class IntroTutorialOverlay extends StatelessWidget {
  const IntroTutorialOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: IntroTutorialController.instance.step,
      builder: (context, step, child) {
        if (step == null) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            top: false,
            // Right of the card stays clear: the letters of the alphabet bar
            // run down that edge, and they are one of the things to try.
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 56, 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: _Card(step: step),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final controller = IntroTutorialController.instance;
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return ListenableBuilder(
          listenable: Listenable.merge([
            controller.achieved,
            controller.homeEditOpen,
          ]),
          builder: (context, child) {
            return Container(
              decoration: design.cardDecoration(
                SurfaceLevel.compact,
                color: design.surface,
              ),
              padding: EdgeInsets.fromLTRB(
                design.spaceMd,
                design.spaceSm,
                design.spaceXs,
                design.spaceSm,
              ),
              child: Material(
                type: MaterialType.transparency,
                child: step == 0
                    ? _languageCard(s, design, controller)
                    : _taskCard(s, design, controller, step),
              ),
            );
          },
        );
      },
    );
  }

  Widget _languageCard(
    AppStrings s,
    DesignTokens design,
    IntroTutorialController controller,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                s.introLanguageTitle,
                style: design.textStyle(TypeRole.label),
              ),
            ),
            _CloseButton(s: s),
          ],
        ),
        SizedBox(height: design.spaceXs),
        ListenableBuilder(
          listenable: LocaleController.instance,
          builder: (context, child) {
            final locale = LocaleController.instance;
            return Wrap(
              spacing: design.spaceXs,
              runSpacing: design.spaceXs,
              children: [
                ChoiceChip(
                  label: const Text('Deutsch'),
                  selected:
                      !locale.followsSystem && locale.value == AppLanguage.de,
                  onSelected: (_) => locale.update(AppLanguage.de),
                ),
                ChoiceChip(
                  label: const Text('English'),
                  selected:
                      !locale.followsSystem && locale.value == AppLanguage.en,
                  onSelected: (_) => locale.update(AppLanguage.en),
                ),
                ChoiceChip(
                  label: Text(s.languageSystem),
                  selected: locale.followsSystem,
                  onSelected: (_) => locale.useSystem(),
                ),
              ],
            );
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: controller.next,
            child: Text(s.introNext),
          ),
        ),
      ],
    );
  }

  Widget _taskCard(
    AppStrings s,
    DesignTokens design,
    IntroTutorialController controller,
    int step,
  ) {
    final achieved = controller.achieved.value;
    final last = step == IntroTutorialController.taskCount;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _instruction(s, step, controller.homeEditOpen.value),
                style: design.textStyle(TypeRole.label),
              ),
            ),
            _CloseButton(s: s),
          ],
        ),
        Row(
          children: [
            Text(
              '$step/${IntroTutorialController.taskCount}',
              style: design.textStyle(
                TypeRole.caption,
                color: design.textSecondary,
              ),
            ),
            const Spacer(),
            if (achieved) ...[
              Icon(Icons.check_circle, size: 18, color: design.accent),
              SizedBox(width: design.space2xs),
              Text(
                s.introDoneMark,
                style: design.textStyle(TypeRole.label, color: design.accent),
              ),
              SizedBox(width: design.spaceXs),
              FilledButton(
                onPressed: controller.next,
                child: Text(last ? s.introDone : s.introNext),
              ),
            ] else
              TextButton(
                onPressed: controller.next,
                child: Text(s.introNext),
              ),
          ],
        ),
      ],
    );
  }

  /// One line per task, named the way the real screen names it.
  String _instruction(AppStrings s, int step, bool menuOpen) => switch (step) {
    1 => menuOpen ? s.introTapAddApp(s.addApp) : s.introHoldHome,
    2 => s.introSwipeLetters,
    3 => s.introPullPanel,
    4 => s.introTapPlus(s.blockWidget),
    _ => s.introTapCog,
  };
}

/// Ends the walk-through from anywhere on the card.
///
/// No tooltip here: this card sits above the navigator, where there is no
/// Overlay for a tooltip to float in. The label goes on as semantics instead.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.s});

  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: s.introSkip,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: IntroTutorialController.instance.finish,
        icon: const Icon(Icons.close),
      ),
    );
  }
}
