import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'app_widgets.dart';
import 'design_tokens.dart';
import 'panel_blocks_controller.dart';

/// Lets the user pick a widget, has Android bind and set it up, and puts it
/// on the panel. Null when anything along the way was cancelled - nothing is
/// added then, and nothing stays registered with Android either.
Future<PanelBlock?> addAppWidgetBlock(BuildContext context, AppStrings s) async {
  final picked = await Navigator.of(context).push<AppWidgetProvider>(
    MaterialPageRoute(builder: (context) => AppWidgetPickerScreen(s: s)),
  );
  if (picked == null) return null;
  final id = await AppWidgets.create(picked.provider);
  if (id == null) return null;
  return PanelBlocksController.instance.addAppWidget(
    appWidgetId: id,
    provider: picked.provider,
    title: picked.label,
    height: picked.height,
  );
}

/// Every widget the installed apps offer, grouped under their app.
class AppWidgetPickerScreen extends StatefulWidget {
  const AppWidgetPickerScreen({super.key, required this.s});

  final AppStrings s;

  @override
  State<AppWidgetPickerScreen> createState() => _AppWidgetPickerScreenState();
}

class _AppWidgetPickerScreenState extends State<AppWidgetPickerScreen> {
  List<AppWidgetProvider>? _providers;
  String _query = '';

  @override
  void initState() {
    super.initState();
    AppWidgets.providers().then((providers) {
      providers.sort((a, b) {
        final byApp = a.appLabel.toLowerCase().compareTo(
          b.appLabel.toLowerCase(),
        );
        return byApp != 0
            ? byApp
            : a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });
      if (mounted) setState(() => _providers = providers);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final providers = _providers;
    final query = _query.trim().toLowerCase();
    final shown = [
      for (final provider in providers ?? const <AppWidgetProvider>[])
        if (query.isEmpty ||
            provider.label.toLowerCase().contains(query) ||
            provider.appLabel.toLowerCase().contains(query))
          provider,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(s.appWidgetPickerTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: s.appWidgetSearch,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: providers == null
                ? const Center(child: CircularProgressIndicator())
                : shown.isEmpty
                ? Center(
                    child: Text(
                      s.noAppWidgets,
                      style: TextStyle(color: context.design.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: shown.length,
                    itemBuilder: (context, index) {
                      final provider = shown[index];
                      final startsApp =
                          index == 0 ||
                          shown[index - 1].packageName != provider.packageName;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (startsApp)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                              child: Text(
                                provider.appLabel,
                                style: TextStyle(
                                  fontSize: context.design.typeLabel,
                                  fontWeight: FontWeight.bold,
                                  color: context.design.textSecondary,
                                ),
                              ),
                            ),
                          _ProviderTile(
                            key: ValueKey(provider.provider),
                            provider: provider,
                            onTap: () => Navigator.of(context).pop(provider),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProviderTile extends StatefulWidget {
  const _ProviderTile({super.key, required this.provider, required this.onTap});

  final AppWidgetProvider provider;
  final VoidCallback onTap;

  @override
  State<_ProviderTile> createState() => _ProviderTileState();
}

class _ProviderTileState extends State<_ProviderTile> {
  // Asked for once per tile as it scrolls into view, not for the whole list
  // up front: decoding every preview a phone's apps ship is seconds of work.
  late final Future<Uint8List?> _preview = AppWidgets.preview(
    widget.provider.provider,
  );

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: widget.onTap,
      title: Text(widget.provider.label),
      leading: SizedBox(
        width: 128,
        height: 80,
        child: FutureBuilder<Uint8List?>(
          future: _preview,
          builder: (context, snapshot) {
            final bytes = snapshot.data;
            if (bytes == null) {
              return Icon(
                Icons.widgets_outlined,
                color: context.design.textSecondary,
              );
            }
            return Image.memory(bytes, fit: BoxFit.contain);
          },
        ),
      ),
    );
  }
}
