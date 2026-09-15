import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'app_strings.dart';
import 'builtin_entries.dart';
import 'code_widget_bridge.dart';
import 'code_widget_store.dart';
import 'data_sources_controller.dart';
import 'design_tokens.dart';
import 'device_stats_controller.dart';
import 'folder_sheet.dart';
import 'launcher_entries_controller.dart';
import 'location_controller.dart';
import 'panel_blocks_controller.dart';
import 'panel_visibility.dart';
import 'widget_action.dart';
import 'widget_input_store.dart';

/// Runs a code widget: the block's own `index.html` (plus `style.css` and
/// `script.js` when they hold anything) in a WebView, loaded out of the
/// block's folder so the page can reference its uploaded files by name.
///
/// No gesture recognizers are claimed on purpose. A platform view only gets
/// what Flutter's own recognizers don't take, which is exactly the split
/// that is wanted here: taps and drags inside the page reach its buttons,
/// while a vertical drag still scrolls the panel and a long press still
/// picks the card up. The cost is that the page itself cannot scroll - so
/// the base stylesheet hides the overflow and a card that needs more room
/// is set to grow instead.
class CodeBlockView extends StatefulWidget {
  const CodeBlockView({super.key, required this.block, required this.s});

  final PanelBlock block;
  final AppStrings s;

  @override
  State<CodeBlockView> createState() => _CodeBlockViewState();
}

class _CodeBlockViewState extends State<CodeBlockView> {
  WebViewController? _controller;
  CodeWidgetBridge? _bridge;

  /// What the running page was built from. The store notifies on every
  /// keystroke in the editor; reloading only when this actually changed is
  /// what keeps a card from restarting its game mid-move.
  String _loadedFrom = '';

  /// The page's own idea of how tall it is, on a card set to grow.
  double? _pageHeight;

  bool _empty = false;

  @override
  void initState() {
    super.initState();
    CodeWidgetStore.instance.addListener(_onStoreChanged);
    _dataSources().addListener(_pushSnapshot);
    if (PanelVisibility.instance.everOpened) {
      _reloadIfNeeded();
    } else {
      PanelVisibility.instance.addListener(_onPanelVisibility);
    }
  }

  void _onPanelVisibility() {
    if (!PanelVisibility.instance.value) return;
    PanelVisibility.instance.removeListener(_onPanelVisibility);
    if (mounted) _reloadIfNeeded();
  }

  @override
  void didUpdateWidget(covariant CodeBlockView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (PanelVisibility.instance.everOpened) _reloadIfNeeded();
  }

  @override
  void dispose() {
    CodeWidgetStore.instance.removeListener(_onStoreChanged);
    PanelVisibility.instance.removeListener(_onPanelVisibility);
    _dataSources().removeListener(_pushSnapshot);
    super.dispose();
  }

  /// Everything that can put a new value in front of the page.
  Listenable _dataSources() => Listenable.merge([
    DataSourcesController.instance,
    LocationController.instance,
    DeviceStatsController.instance,
    WidgetInputStore.instance,
  ]);

  void _onStoreChanged() {
    if (mounted && PanelVisibility.instance.everOpened) _reloadIfNeeded();
  }

  void _pushSnapshot() => _bridge?.pushSnapshot();

  /// The lengths go in front of the text: without them "ab" + "c" and "a" +
  /// "bc" would be the same signature, and an edit that moved a character
  /// from one file to the next would not reload.
  String _signatureOf(CodeWidgetSource source) =>
      '${widget.block.cardHeightFlexible}|'
      '${source.html.length}:${source.css.length}:${source.js.length}|'
      '${source.html}${source.css}${source.js}';

  Future<void> _reloadIfNeeded() async {
    final source = await CodeWidgetStore.instance.read(widget.block.id);
    if (!mounted) return;

    final signature = _signatureOf(source);
    if (signature == _loadedFrom && (_controller != null || _empty)) return;
    _loadedFrom = signature;

    if (source.isEmpty) {
      setState(() {
        _empty = true;
        _controller = null;
        _bridge = null;
      });
      return;
    }

    final flexible = widget.block.cardHeightFlexible;
    final path = await CodeWidgetStore.instance.prepareDocument(
      widget.block.id,
      flexible: flexible,
    );
    if (!mounted) return;

    // Reuse the controller when there is one: loading a new document into
    // it is a repaint, while building a fresh one is a new platform view
    // and a visible white flash on every saved keystroke.
    final existing = _controller;
    if (existing != null) {
      await existing.loadFile(path);
      if (mounted) setState(() => _empty = false);
      return;
    }

    // Always wired, even on a fixed card: the switch can be flipped while
    // the widget is running, and the controller is kept across that reload.
    // _onPageHeight reads the current setting instead.
    final bridge = CodeWidgetBridge(
      blockId: widget.block.id,
      onHeight: _onPageHeight,
      onToast: _toast,
      onOpenEntry: _openEntry,
    );
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..enableZoom(false)
      ..addJavaScriptChannel(
        launcherChannelName,
        onMessageReceived: (message) => bridge.handleMessage(message.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => bridge.pushSnapshot(),
          onNavigationRequest: _decideNavigation,
        ),
      );
    bridge.controller = controller;
    await controller.loadFile(path);
    if (!mounted) return;
    setState(() {
      _empty = false;
      _bridge = bridge;
      _controller = controller;
    });
  }

  /// A link inside the page must not replace the widget with a website -
  /// the card would then be showing something the editor knows nothing
  /// about, with no way back. Anything that isn't the widget's own document
  /// is handed to the phone instead, which is what tapping a link should do
  /// on a launcher card anyway.
  NavigationDecision _decideNavigation(NavigationRequest request) {
    if (request.url.startsWith('file://')) return NavigationDecision.navigate;
    openExternalUrl(request.url);
    return NavigationDecision.prevent;
  }

  void _onPageHeight(double height) {
    if (!mounted || !widget.block.cardHeightFlexible) return;
    if (_pageHeight != null && (_pageHeight! - height).abs() < 1) return;
    setState(() => _pageHeight = height);
  }

  void _toast(String text) {
    if (!mounted || text.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// The same keys the app rows and pinned apps use: a package name, a
  /// `web:<id>` or a `folder:<id>`.
  Future<bool> _openEntry(String key) async {
    final entries = LauncherEntriesController.instance.resolve([key]);
    if (entries.isEmpty || !mounted) return false;
    final entry = entries.first;
    if (entry.isFolder) {
      showFolderSheet(context, entry.folder!);
    } else if (entry.isBuiltIn) {
      await openBuiltIn(context, entry.builtIn!);
    } else {
      await entry.launch();
    }
    return true;
  }

  double get _height {
    final block = widget.block;
    if (!block.cardHeightFlexible) return block.cardHeight;
    final reported = _pageHeight;
    if (reported == null) return block.cardHeight;
    return reported.clamp(
      block.cardHeight,
      math.max(block.cardMaxHeight, block.cardHeight),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return SizedBox(
        height: _empty ? 72 : widget.block.cardHeight,
        child: _empty ? _emptyHint() : const SizedBox.shrink(),
      );
    }
    return SizedBox(
      height: _height,
      width: double.infinity,
      child: WebViewWidget(controller: controller),
    );
  }

  Widget _emptyHint() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.code, color: context.design.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.block.title.isEmpty
                  ? widget.s.emptyCodeWidget
                  : '${widget.block.title} - ${widget.s.emptyCodeWidget}',
              style: TextStyle(color: context.design.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
