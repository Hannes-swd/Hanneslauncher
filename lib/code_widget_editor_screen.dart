import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'app_strings.dart';
import 'code_widget_bridge.dart';
import 'code_widget_store.dart';
import 'code_widget_templates.dart';
import 'data_sources_controller.dart';
import 'design_tokens.dart';
import 'locale_controller.dart';
import 'panel_blocks_controller.dart';
import 'text_prompt_dialog.dart';

/// Asks which starting point a new code widget should have, creates the
/// block and writes the template into its folder. Shared by the panel's "+"
/// and the settings list, so both land in exactly the same place.
Future<PanelBlock?> createCodeWidget(BuildContext context, AppStrings s) async {
  final template = await showDialog<CodeWidgetTemplate>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(s.codeTemplate),
      children: [
        for (final option in CodeWidgetTemplate.values)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(option),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_templateIcon(option)),
              title: Text(option.label(s)),
              subtitle: Text(option.description(s)),
            ),
          ),
      ],
    ),
  );
  if (template == null || !context.mounted) return null;

  final block = await PanelBlocksController.instance.addCode(s.blockCode);
  final source = template.source;
  await CodeWidgetStore.instance.write(
    block.id,
    html: source.html,
    css: source.css,
    js: source.js,
  );
  return block;
}

IconData _templateIcon(CodeWidgetTemplate template) => switch (template) {
  CodeWidgetTemplate.empty => Icons.code,
  CodeWidgetTemplate.button => Icons.smart_button_outlined,
  CodeWidgetTemplate.data => Icons.cloud_outlined,
  CodeWidgetTemplate.gallery => Icons.image_outlined,
  CodeWidgetTemplate.game => Icons.sports_esports_outlined,
};

/// Writes a code widget: its three files, the pictures and data files next
/// to them, and the handful of settings the card around it has.
class CodeWidgetEditorScreen extends StatefulWidget {
  const CodeWidgetEditorScreen({super.key, required this.blockId});

  final String blockId;

  @override
  State<CodeWidgetEditorScreen> createState() => _CodeWidgetEditorScreenState();
}

class _CodeWidgetEditorScreenState extends State<CodeWidgetEditorScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this);

  final TextEditingController _html = TextEditingController();
  final TextEditingController _css = TextEditingController();
  final TextEditingController _js = TextEditingController();

  bool _ready = false;

  /// Writing three files on every keystroke would mean a file write per
  /// letter and a reload of the card behind this screen with it. Half a
  /// second after the last one is soon enough, and [dispose] catches
  /// whatever the timer hasn't flushed yet.
  Timer? _save;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final source = await CodeWidgetStore.instance.read(widget.blockId);
    if (!mounted) return;
    _html.text = source.html;
    _css.text = source.css;
    _js.text = source.js;
    setState(() => _ready = true);
  }

  @override
  void dispose() {
    _save?.cancel();
    if (_ready) _flush();
    _tabs.dispose();
    _html.dispose();
    _css.dispose();
    _js.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    _save?.cancel();
    _save = Timer(const Duration(milliseconds: 500), _flush);
  }

  void _flush() {
    _save?.cancel();
    CodeWidgetStore.instance.write(
      widget.blockId,
      html: _html.text,
      css: _css.text,
      js: _js.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return ValueListenableBuilder<List<PanelBlock>>(
          valueListenable: PanelBlocksController.instance,
          builder: (context, blocks, child) {
            final block = PanelBlocksController.instance.byId(widget.blockId);
            // Deleted from this very screen.
            if (block == null) return const Scaffold();

            return Scaffold(
              appBar: AppBar(
                title: Text(block.title.isEmpty ? s.blockCode : block.title),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.play_arrow_outlined),
                    tooltip: s.preview,
                    onPressed: _ready ? () => _openPreview(s) : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.help_outline),
                    tooltip: s.codeHelp,
                    onPressed: () => _showHelp(s),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: s.deleteBlock,
                    onPressed: () async {
                      _save?.cancel();
                      await PanelBlocksController.instance.remove(
                        widget.blockId,
                      );
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ],
                bottom: TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabs: [
                    const Tab(text: 'HTML'),
                    const Tab(text: 'CSS'),
                    const Tab(text: 'JS'),
                    Tab(text: s.codeFiles),
                    Tab(text: s.codeCard),
                  ],
                ),
              ),
              body: !_ready
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        _CodeField(
                          controller: _html,
                          s: s,
                          onChanged: _scheduleSave,
                          onInsertValue: (reference) => _insert(
                            _html,
                            '<span data-value="$reference"></span>',
                          ),
                        ),
                        _CodeField(
                          controller: _css,
                          s: s,
                          onChanged: _scheduleSave,
                          onInsertValue: (reference) =>
                              _insert(_css, '/* $reference */'),
                        ),
                        _CodeField(
                          controller: _js,
                          s: s,
                          onChanged: _scheduleSave,
                          onInsertValue: (reference) =>
                              _insert(_js, "launcher.get('$reference')"),
                        ),
                        _FilesTab(
                          blockId: widget.blockId,
                          s: s,
                          onInsert: _insertFile,
                        ),
                        _CardTab(block: block, s: s),
                      ],
                    ),
            );
          },
        );
      },
    );
  }

  /// Puts [text] where the cursor is, replacing whatever is selected - the
  /// same thing typing it would do.
  void _insert(TextEditingController controller, String text) {
    final selection = controller.selection;
    final current = controller.text;
    final start = selection.isValid ? selection.start : current.length;
    final end = selection.isValid ? selection.end : current.length;
    controller.value = TextEditingValue(
      text: current.replaceRange(start, end, text),
      selection: TextSelection.collapsed(offset: start + text.length),
    );
    _scheduleSave();
  }

  void _insertFile(String name, AppStrings s) {
    final lower = name.toLowerCase();
    final isImage = const {
      '.png',
      '.jpg',
      '.jpeg',
      '.gif',
      '.webp',
      '.bmp',
      '.svg',
    }.any(lower.endsWith);
    _insert(_html, isImage ? '<img src="$name" alt="">' : name);
    _tabs.animateTo(0);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(s.codeFileInserted)));
  }

  Future<void> _openPreview(AppStrings s) async {
    _flush();
    // The preview loads the files from disk, so it has to wait for the write
    // rather than race it.
    await CodeWidgetStore.instance.write(
      widget.blockId,
      html: _html.text,
      css: _css.text,
      js: _js.text,
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CodeWidgetPreviewScreen(blockId: widget.blockId),
      ),
    );
  }

  void _showHelp(AppStrings s) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.codeHelp),
        content: SingleChildScrollView(
          child: SelectableText(
            s.codeHelpBody,
            style: TextStyle(fontSize: context.design.typeLabel, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// One of the three code panes: a monospace field that fills the screen,
/// with the value picker above it.
class _CodeField extends StatelessWidget {
  const _CodeField({
    required this.controller,
    required this.s,
    required this.onChanged,
    required this.onInsertValue,
  });

  final TextEditingController controller;
  final AppStrings s;
  final VoidCallback onChanged;
  final ValueChanged<String> onInsertValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.data_object, size: 18),
              label: Text(s.availableValues),
              onPressed: () async {
                final picked = await showValuePicker(context, s);
                if (picked != null) onInsertValue(picked);
              },
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              // Code is not prose: a keyboard that capitalises sentences and
              // corrects words turns `const` into `Const` and quietly breaks
              // the widget.
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              keyboardType: TextInputType.multiline,
              smartDashesType: SmartDashesType.disabled,
              smartQuotesType: SmartQuotesType.disabled,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: context.design.typeLabel,
                height: 1.35,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.all(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Every value the code can read right now, each with what it currently
/// holds, filterable by typing. Returns the reference (`wetter.temp`)
/// rather than the `{{...}}` spelling - the caller wraps it in whatever the
/// pane it belongs to needs.
Future<String?> showValuePicker(BuildContext context, AppStrings s) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ValuePickerSheet(s: s),
  );
}

class _ValuePickerSheet extends StatefulWidget {
  const _ValuePickerSheet({required this.s});

  final AppStrings s;

  @override
  State<_ValuePickerSheet> createState() => _ValuePickerSheetState();
}

class _ValuePickerSheetState extends State<_ValuePickerSheet> {
  final TextEditingController _filter = TextEditingController();

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _filter.text.trim().toLowerCase();
    final options = [
      for (final option in DataSourcesController.instance.options())
        if (query.isEmpty ||
            option.placeholder.toLowerCase().contains(query) ||
            option.label.toLowerCase().contains(query) ||
            (option.sourceName ?? '').toLowerCase().contains(query))
          option,
    ];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _filter,
                autofocus: false,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  hintText: widget.s.availableValues,
                ),
              ),
            ),
            Expanded(
              child: options.isEmpty
                  ? Center(child: Text(widget.s.noSettingsFound))
                  : ListView.builder(
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final reference = option.placeholder
                            .replaceAll('{{', '')
                            .replaceAll('}}', '');
                        return ListTile(
                          dense: true,
                          title: Text(
                            reference,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: context.design.typeLabel,
                            ),
                          ),
                          subtitle: Text(
                            option.sourceName == null
                                ? option.preview
                                : '${option.sourceName}  ·  ${option.preview}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.of(context).pop(reference),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The widget's own folder: what is in it, and the two ways to put
/// something there.
class _FilesTab extends StatefulWidget {
  const _FilesTab({
    required this.blockId,
    required this.s,
    required this.onInsert,
  });

  final String blockId;
  final AppStrings s;
  final void Function(String name, AppStrings s) onInsert;

  @override
  State<_FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<_FilesTab> {
  late Future<List<CodeWidgetAsset>> _assets = CodeWidgetStore.instance.assets(
    widget.blockId,
  );

  void _reload() {
    setState(() {
      _assets = CodeWidgetStore.instance.assets(widget.blockId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(s.codeUploadImage),
                  onPressed: () async {
                    await CodeWidgetStore.instance.addImage(widget.blockId);
                    _reload();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.note_add_outlined),
                  label: Text(s.codeNewTextFile),
                  onPressed: () => _newTextFile(s),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<CodeWidgetAsset>>(
            future: _assets,
            builder: (context, snapshot) {
              final assets = snapshot.data;
              if (assets == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (assets.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    s.codeNoFiles,
                    style: TextStyle(color: context.design.textSecondary),
                  ),
                );
              }
              return ListView.builder(
                itemCount: assets.length,
                itemBuilder: (context, index) {
                  final asset = assets[index];
                  return ListTile(
                    leading: Icon(
                      asset.isImage
                          ? Icons.image_outlined
                          : Icons.description_outlined,
                    ),
                    title: Text(
                      asset.name,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: context.design.typeLabel,
                      ),
                    ),
                    subtitle: Text(
                      '${_size(asset.size)}  ·  '
                      '${asset.fitsInBackup ? s.codeFileInBackup : s.codeFileTooBigForBackup}',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (choice) => _onMenu(choice, asset, s),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'insert',
                          child: Text(s.codeInsertFile),
                        ),
                        if (!asset.isImage)
                          PopupMenuItem(
                            value: 'edit',
                            child: Text(s.codeEditFile),
                          ),
                        PopupMenuItem(
                          value: 'rename',
                          child: Text(s.codeRenameFile),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(s.deleteBlock),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  static String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _onMenu(
    String choice,
    CodeWidgetAsset asset,
    AppStrings s,
  ) async {
    switch (choice) {
      case 'insert':
        widget.onInsert(asset.name, s);
      case 'edit':
        await _editTextFile(asset.name, s);
      case 'rename':
        final name = await showDialog<String>(
          context: context,
          builder: (context) => TextPromptDialog(
            title: s.codeRenameFile,
            label: s.codeFileName,
            initialValue: asset.name,
            s: s,
          ),
        );
        if (name == null || name.trim().isEmpty) return;
        await CodeWidgetStore.instance.renameAsset(
          widget.blockId,
          asset.name,
          name,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(s.codeFileRenamed)));
        _reload();
      case 'delete':
        await CodeWidgetStore.instance.deleteAsset(widget.blockId, asset.name);
        _reload();
    }
  }

  Future<void> _newTextFile(AppStrings s) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => TextPromptDialog(
        title: s.codeNewTextFile,
        label: s.codeFileName,
        initialValue: 'daten.json',
        s: s,
      ),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    final created = await CodeWidgetStore.instance.addTextFile(
      widget.blockId,
      name,
      '',
    );
    _reload();
    if (!mounted) return;
    await _editTextFile(created, s);
  }

  Future<void> _editTextFile(String name, AppStrings s) async {
    final contents = await CodeWidgetStore.instance.readAsset(
      widget.blockId,
      name,
    );
    if (!mounted) return;
    final edited = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) =>
            _TextFileScreen(name: name, initial: contents, s: s),
      ),
    );
    if (edited == null) return;
    await CodeWidgetStore.instance.writeAsset(widget.blockId, name, edited);
    _reload();
  }
}

/// A plain editor for one of the uploaded text files - a bit of JSON, a word
/// list, a second stylesheet.
class _TextFileScreen extends StatefulWidget {
  const _TextFileScreen({
    required this.name,
    required this.initial,
    required this.s,
  });

  final String name;
  final String initial;
  final AppStrings s;

  @override
  State<_TextFileScreen> createState() => _TextFileScreenState();
}

class _TextFileScreenState extends State<_TextFileScreen> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: widget.s.save,
            onPressed: () => Navigator.of(context).pop(_text.text),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: TextField(
          controller: _text,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          keyboardType: TextInputType.multiline,
          smartDashesType: SmartDashesType.disabled,
          smartQuotesType: SmartQuotesType.disabled,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: context.design.typeLabel,
            height: 1.35,
          ),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.all(10),
          ),
        ),
      ),
    );
  }
}

/// What the card around the page looks like: its name, its height, and
/// whether there is a card at all.
class _CardTab extends StatelessWidget {
  const _CardTab({required this.block, required this.s});

  final PanelBlock block;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final controller = PanelBlocksController.instance;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.edit_outlined),
          title: Text(s.codeWidgetName),
          subtitle: Text(block.title.isEmpty ? s.blockCode : block.title),
          onTap: () async {
            final name = await showDialog<String>(
              context: context,
              builder: (context) => TextPromptDialog(
                title: s.codeWidgetName,
                label: s.codeWidgetName,
                initialValue: block.title,
                s: s,
              ),
            );
            if (name == null) return;
            await controller.update(block.copyWith(title: name.trim()));
          },
        ),
        const Divider(height: 24),
        Text(
          s.cardHeightLabel,
          style: TextStyle(
            fontSize: context.design.typeLabel,
            fontWeight: FontWeight.bold,
            color: context.design.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text(s.cardHeightFixed),
              selected: !block.cardHeightFlexible,
              onSelected: (_) =>
                  controller.update(block.copyWith(cardHeightFlexible: false)),
            ),
            ChoiceChip(
              label: Text(s.cardHeightFlexible),
              selected: block.cardHeightFlexible,
              onSelected: (_) =>
                  controller.update(block.copyWith(cardHeightFlexible: true)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          block.cardHeightFlexible
              ? s.cardHeightFlexibleHint
              : s.cardHeightFixedHint,
          style: TextStyle(
            fontSize: context.design.typeCaption,
            color: context.design.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${block.cardHeightFlexible ? s.cardMinHeightLabel : s.cardHeightLabel}'
          ' (${block.cardHeight.round()})',
          style: TextStyle(
            fontSize: context.design.typeLabel,
            fontWeight: FontWeight.bold,
            color: context.design.textSecondary,
          ),
        ),
        Slider(
          value: block.cardHeight,
          min: 40,
          max: 400,
          divisions: 36,
          onChanged: (value) =>
              controller.update(block.copyWith(cardHeight: value)),
        ),
        if (block.cardHeightFlexible) ...[
          Text(
            '${s.cardMaxHeightLabel} '
            '(${math.max(block.cardMaxHeight, block.cardHeight).round()})',
            style: TextStyle(
              fontSize: context.design.typeLabel,
              fontWeight: FontWeight.bold,
              color: context.design.textSecondary,
            ),
          ),
          Slider(
            value: math
                .max(block.cardMaxHeight, block.cardHeight)
                .clamp(block.cardHeight, 600.0),
            min: block.cardHeight,
            max: 600,
            onChanged: (value) =>
                controller.update(block.copyWith(cardMaxHeight: value)),
          ),
        ],
        const Divider(height: 24),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(s.codeTransparent),
          subtitle: Text(s.codeTransparentHint),
          value: block.transparentBackground,
          onChanged: (value) =>
              controller.update(block.copyWith(transparentBackground: value)),
        ),
        const Divider(height: 24),
        Text(
          s.codeScrollHint,
          style: TextStyle(
            fontSize: context.design.typeCaption,
            color: context.design.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          s.codeLinkHint,
          style: TextStyle(
            fontSize: context.design.typeCaption,
            color: context.design.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// The widget on its own, full screen, with whatever it printed or threw
/// underneath it. Without this the only way to find a typo in a widget would
/// be to close the settings, pull the panel down and look at a blank card.
class CodeWidgetPreviewScreen extends StatefulWidget {
  const CodeWidgetPreviewScreen({super.key, required this.blockId});

  final String blockId;

  @override
  State<CodeWidgetPreviewScreen> createState() =>
      _CodeWidgetPreviewScreenState();
}

class _CodeWidgetPreviewScreenState extends State<CodeWidgetPreviewScreen> {
  WebViewController? _controller;
  CodeWidgetBridge? _bridge;
  final List<String> _log = [];

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final path = await CodeWidgetStore.instance.prepareDocument(
      widget.blockId,
      flexible: false,
    );
    if (!mounted) return;
    final bridge = CodeWidgetBridge(
      blockId: widget.blockId,
      onLog: _append,
      onToast: _append,
    );
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(false)
      ..addJavaScriptChannel(
        launcherChannelName,
        onMessageReceived: (message) => bridge.handleMessage(message.message),
      )
      ..setOnConsoleMessage((message) => _append(message.message))
      ..setNavigationDelegate(
        NavigationDelegate(onPageFinished: (_) => bridge.pushSnapshot()),
      );
    bridge.controller = controller;
    await controller.loadFile(path);
    if (!mounted) return;
    setState(() {
      _bridge = bridge;
      _controller = controller;
    });
  }

  void _append(String message) {
    if (!mounted || message.isEmpty) return;
    setState(() {
      _log.add(message);
      // A runaway loop logging every frame would otherwise grow this list
      // until the screen runs out of memory.
      if (_log.length > 200) _log.removeRange(0, _log.length - 200);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        final controller = _controller;
        return Scaffold(
          appBar: AppBar(
            title: Text(s.preview),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  _log.clear();
                  _controller?.reload();
                  _bridge?.pushSnapshot();
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                flex: 3,
                child: controller == null
                    ? const Center(child: CircularProgressIndicator())
                    : WebViewWidget(controller: controller),
              ),
              const Divider(height: 1),
              Expanded(
                flex: 1,
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFF1E1E1E),
                  padding: const EdgeInsets.all(8),
                  child: _log.isEmpty
                      ? Text(
                          s.codeConsoleEmpty,
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: context.design.typeCaption,
                          ),
                        )
                      : ListView.builder(
                          reverse: true,
                          itemCount: _log.length,
                          itemBuilder: (context, index) => Text(
                            _log[_log.length - 1 - index],
                            style: TextStyle(
                              color: Color(0xFFE0E0E0),
                              fontFamily: 'monospace',
                              fontSize: context.design.typeCaption,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
