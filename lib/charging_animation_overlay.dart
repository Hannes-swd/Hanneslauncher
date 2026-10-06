import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'charging_animation_controller.dart';

/// Draws the charging animation over everything the app shows - the home
/// screen and any settings page alike, which is what lets the preview button
/// play it right where it is pressed.
///
/// Touches go straight through: an animation is something to look at, and a
/// tap meant for an app underneath must not be eaten by it.
class ChargingAnimationOverlay extends StatelessWidget {
  const ChargingAnimationOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ChargingAnimationPlay?>(
      valueListenable: ChargingAnimationController.instance.playing,
      builder: (context, play, child) {
        if (play == null) return const SizedBox.shrink();
        return IgnorePointer(
          child: _Player(key: ObjectKey(play), play: play),
        );
      },
    );
  }
}

class _Player extends StatefulWidget {
  const _Player({super.key, required this.play});

  final ChargingAnimationPlay play;

  @override
  State<_Player> createState() => _PlayerState();
}

class _PlayerState extends State<_Player> {
  static const _fadeOut = Duration(milliseconds: 250);

  late final WebViewController _controller;
  Timer? _fadeTimer;
  Timer? _endTimer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    final play = widget.play;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..enableZoom(false)
      ..setNavigationDelegate(
        NavigationDelegate(
          // Shown once the page is in, so a slow first frame is a short
          // delay rather than a white flash.
          onPageFinished: (_) {
            if (mounted) setState(() => _visible = true);
          },
          // An animation has no business navigating anywhere.
          onNavigationRequest: (request) => request.url.startsWith('data:') ||
                  request.url == 'about:blank'
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
        ),
      )
      ..loadHtmlString(_document(play));

    final total = Duration(milliseconds: play.durationMs);
    _fadeTimer = Timer(total, () {
      if (mounted) setState(() => _visible = false);
    });
    _endTimer = Timer(
      total + _fadeOut,
      () => ChargingAnimationController.instance.finished(play),
    );
  }

  /// The page's own code with `window.charge` and the CSS variables put in
  /// front of it - see charging_animation_presets.dart.
  static String _document(ChargingAnimationPlay play) {
    final charge = jsonEncode({
      'duration': play.durationMs,
      'level': play.level,
    });
    final level = play.level < 0 ? 1.0 : play.level / 100;
    return '<!DOCTYPE html><html><head>'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        '<script>window.charge = $charge;</script>'
        '<style>:root{--duration:${play.durationMs}ms;--level:$level;}'
        'html,body{background:transparent}</style>'
        '</head><body>${play.html}</body></html>';
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    _endTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: _fadeOut,
      child: WebViewWidget(controller: _controller),
    );
  }
}
