import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'data_sources_controller.dart';
import 'locale_controller.dart';

/// Open-Meteo needs no API key and reports a weather code that the icon
/// rules can match on, which makes it the one template worth shipping.
const _weatherFields = '&current=temperature_2m,weather_code,wind_speed_10m';

/// Berlin, as something that works before anyone has typed coordinates.
const _weatherUrl =
    'https://api.open-meteo.com/v1/forecast'
    '?latitude=52.52&longitude=13.41$_weatherFields';

/// The same, but following the phone: the placeholders are filled in right
/// before each fetch, so the forecast is always for where you are.
const _weatherHereUrl =
    'https://api.open-meteo.com/v1/forecast'
    '?latitude={{lat}}&longitude={{lon}}&timezone=auto$_weatherFields';

/// Offers the templates, creates the chosen source and opens it for editing
/// - a template only prefills the form, every field stays editable. Shared
/// so a source can be added from wherever one turns out to be missing,
/// instead of only from the settings.
Future<void> addDataSource(BuildContext context, AppStrings s) async {
  final preset = await showDialog<String>(
    context: context,
    builder: (context) {
      return SimpleDialog(
        title: Text(s.presets),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('weatherHere'),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.my_location),
              title: Text(s.presetWeatherHere),
              subtitle: Text(s.presetWeatherHereHint),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('weather'),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.wb_sunny_outlined),
              title: Text(s.presetWeather),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('custom'),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link),
              title: Text(s.presetCustom),
            ),
          ),
        ],
      );
    },
  );
  if (preset == null || !context.mounted) return;

  final source = switch (preset) {
    'weatherHere' => await DataSourcesController.instance.add(
      key: 'wetter',
      name: s.presetWeatherHere,
      url: _weatherHereUrl,
      refreshMinutes: 30,
    ),
    'weather' => await DataSourcesController.instance.add(
      key: 'wetter',
      name: s.presetWeather,
      url: _weatherUrl,
      refreshMinutes: 30,
    ),
    _ => await DataSourcesController.instance.add(
      key: 'quelle',
      name: s.presetCustom,
      url: '',
    ),
  };
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => DataSourceEditScreen(sourceId: source.id),
    ),
  );
}

/// The APIs the widgets read from.
class DataSourcesSettingsScreen extends StatelessWidget {
  const DataSourcesSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return ValueListenableBuilder<List<DataSource>>(
          valueListenable: DataSourcesController.instance,
          builder: (context, sources, child) {
            return Scaffold(
              appBar: AppBar(title: Text(s.dataSources)),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => addDataSource(context, s),
                icon: const Icon(Icons.add),
                label: Text(s.addDataSource),
              ),
              body: sources.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        s.dataSourcesSubtitle(0),
                        style: const TextStyle(color: Colors.black54),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 88),
                      children: [
                        for (final source in sources)
                          ListTile(
                            leading: const Icon(Icons.cloud_outlined),
                            title: Text(source.name),
                            subtitle: Text(
                              '{{${source.key}}} · ${source.url}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      DataSourceEditScreen(
                                        sourceId: source.id,
                                      ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
            );
          },
        );
      },
    );
  }

}

/// One source's settings, with a test button that shows what actually comes
/// back before it is used anywhere.
class DataSourceEditScreen extends StatefulWidget {
  const DataSourceEditScreen({super.key, required this.sourceId});

  final String sourceId;

  @override
  State<DataSourceEditScreen> createState() => _DataSourceEditScreenState();
}

class _DataSourceEditScreenState extends State<DataSourceEditScreen> {
  late final DataSource? _source = DataSourcesController.instance.byId(
    widget.sourceId,
  );

  late final TextEditingController _key = TextEditingController(
    text: _source?.key ?? '',
  );
  late final TextEditingController _name = TextEditingController(
    text: _source?.name ?? '',
  );
  late final TextEditingController _url = TextEditingController(
    text: _source?.url ?? '',
  );
  late final TextEditingController _headers = TextEditingController(
    text: _headersToText(_source?.headers ?? const {}),
  );
  late int _refreshMinutes = _source?.refreshMinutes ?? 30;

  bool _testing = false;
  String? _testResult;

  @override
  void dispose() {
    _key.dispose();
    _name.dispose();
    _url.dispose();
    _headers.dispose();
    super.dispose();
  }

  static String _headersToText(Map<String, String> headers) =>
      [for (final entry in headers.entries) '${entry.key}: ${entry.value}']
          .join('\n');

  static Map<String, String> _headersFromText(String text) {
    final headers = <String, String>{};
    for (final line in text.split('\n')) {
      final separator = line.indexOf(':');
      if (separator <= 0) continue;
      headers[line.substring(0, separator).trim()] = line
          .substring(separator + 1)
          .trim();
    }
    return headers;
  }

  Future<void> _save(AppStrings s) async {
    final source = _source;
    if (source == null) return;
    final key = _key.text.trim();
    final url = _url.text.trim();
    if (key.isEmpty || url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.keyAndUrlRequired)));
      return;
    }
    await DataSourcesController.instance.update(
      source.copyWith(
        key: key,
        name: _name.text.trim().isEmpty ? key : _name.text.trim(),
        url: url,
        headers: _headersFromText(_headers.text),
        refreshMinutes: _refreshMinutes,
      ),
    );
    // Fetch it once right away: testing deliberately stores nothing, so
    // without this the source would hold no values and would be missing from
    // the editor's list until the panel happened to refresh it.
    final saved = DataSourcesController.instance.byId(widget.sourceId);
    if (saved != null) await DataSourcesController.instance.refresh(saved);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _test(AppStrings s) async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final result = await DataSourcesController.instance.preview(
      _url.text.trim(),
      _headersFromText(_headers.text),
    );
    if (!mounted) return;
    setState(() {
      _testing = false;
      // Just the first stretch: enough to tell whether the right thing came
      // back, without turning the screen into a JSON dump.
      final data = '${result.data}';
      _testResult =
          result.error ??
          (data.length > 400 ? '${data.substring(0, 400)}…' : data);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        if (_source == null) return const Scaffold();

        return Scaffold(
          appBar: AppBar(
            title: Text(s.dataSources),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: s.deleteBlock,
                onPressed: () async {
                  await DataSourcesController.instance.remove(
                    widget.sourceId,
                  );
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              IconButton(
                icon: const Icon(Icons.check),
                tooltip: s.save,
                onPressed: () => _save(s),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _name,
                decoration: InputDecoration(labelText: s.sourceName),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _key,
                decoration: InputDecoration(
                  labelText: s.sourceKey,
                  helperText: s.sourceKeyHint,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _url,
                keyboardType: TextInputType.url,
                maxLines: null,
                decoration: InputDecoration(
                  labelText: s.sourceUrl,
                  helperText: s.onlyHttps,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _headers,
                maxLines: null,
                decoration: InputDecoration(labelText: s.sourceHeaders),
              ),
              const SizedBox(height: 24),
              Text(
                s.refreshEvery(_refreshMinutes),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              Slider(
                value: _refreshMinutes.toDouble(),
                min: 5,
                max: 240,
                divisions: 47,
                onChanged: (value) =>
                    setState(() => _refreshMinutes = value.round()),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: _testing ? null : () => _test(s),
                  icon: const Icon(Icons.play_arrow),
                  label: Text(s.testSource),
                ),
              ),
              if (_testing)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_testResult != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _testResult!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
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
