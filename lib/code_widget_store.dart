import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'code_widget_bridge.dart';

/// The three files a code widget is written in. Held together rather than
/// read one at a time: every place that wants one of them (the card, the
/// preview, the backup) wants all three.
class CodeWidgetSource {
  const CodeWidgetSource({this.html = '', this.css = '', this.js = ''});

  final String html;
  final String css;
  final String js;

  bool get isEmpty => html.trim().isEmpty && js.trim().isEmpty;

  CodeWidgetSource copyWith({String? html, String? css, String? js}) =>
      CodeWidgetSource(
        html: html ?? this.html,
        css: css ?? this.css,
        js: js ?? this.js,
      );
}

/// One file the user put into a widget's folder - a picture, a bit of JSON,
/// whatever the code reads. [name] is what the code references it by, so it
/// is also the file's real name on disk.
class CodeWidgetAsset {
  const CodeWidgetAsset({
    required this.name,
    required this.path,
    required this.size,
  });

  final String name;
  final String path;
  final int size;

  bool get isImage => const {
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.webp',
    '.bmp',
    '.svg',
  }.contains(p.extension(name).toLowerCase());

  /// Whether a settings backup carries this file with it. Big ones are left
  /// behind on purpose - see [CodeWidgetStore.maxBackedUpFileBytes].
  bool get fitsInBackup => size <= CodeWidgetStore.maxBackedUpFileBytes;
}

/// Every code widget's own folder, one per block, inside the app's private
/// documents directory:
///
///     code_widgets/<block id>/index.html
///                             style.css
///                             script.js
///                             <whatever was uploaded>
///
/// Files rather than SharedPreferences for two reasons: an uploaded picture
/// has no business in a preferences file at all, and keeping everything in
/// one folder is what lets the page reference its own files by plain
/// relative name (`<img src="bild.png">`) - the browser resolves those
/// against the folder the page was loaded from, so nothing has to rewrite
/// paths and nothing outside that folder is reachable.
class CodeWidgetStore extends ChangeNotifier {
  CodeWidgetStore._();

  static final CodeWidgetStore instance = CodeWidgetStore._();

  static const String folderName = 'code_widgets';
  static const String htmlFile = 'index.html';
  static const String cssFile = 'style.css';
  static const String jsFile = 'script.js';

  /// The composed document the WebView actually loads. Regenerated on every
  /// run, and named with a leading underscore so it can never collide with
  /// an uploaded file - the upload path folds that character away.
  static const String runFile = '_run.html';

  /// A file this big or smaller travels inside a settings backup. Above it
  /// the file stays on the phone only: a backup is a JSON document that
  /// gets base64 in it, so a couple of photos would turn the one file the
  /// whole setup depends on into something too big to hand around.
  static const int maxBackedUpFileBytes = 512 * 1024;

  static const Set<String> _reservedNames = {
    htmlFile,
    cssFile,
    jsFile,
    runFile,
  };

  /// Read files, by block id. The card rebuilds from this rather than from
  /// disk, so a keystroke in the editor shows up without a file read per
  /// frame.
  final Map<String, CodeWidgetSource> _cache = {};

  /// What [read] has already been asked for, so a card whose widget really
  /// is empty doesn't start a fresh read on every rebuild.
  final Set<String> _loaded = {};

  CodeWidgetSource? cached(String blockId) => _cache[blockId];

  Future<Directory> folderFor(String blockId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, folderName, blockId));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  /// The three files, from the cache when they have been read before.
  Future<CodeWidgetSource> read(String blockId) async {
    final cached = _cache[blockId];
    if (cached != null) return cached;
    final dir = await folderFor(blockId);
    final source = CodeWidgetSource(
      html: await _readFile(dir, htmlFile),
      css: await _readFile(dir, cssFile),
      js: await _readFile(dir, jsFile),
    );
    _cache[blockId] = source;
    _loaded.add(blockId);
    return source;
  }

  Future<void> write(
    String blockId, {
    String? html,
    String? css,
    String? js,
  }) async {
    final current = await read(blockId);
    final updated = current.copyWith(html: html, css: css, js: js);
    _cache[blockId] = updated;
    final dir = await folderFor(blockId);
    if (html != null) await _writeFile(dir, htmlFile, html);
    if (css != null) await _writeFile(dir, cssFile, css);
    if (js != null) await _writeFile(dir, jsFile, js);
    notifyListeners();
  }

  /// Everything in the folder that isn't one of the three code files or the
  /// generated document - i.e. what the user put there.
  Future<List<CodeWidgetAsset>> assets(String blockId) async {
    final dir = await folderFor(blockId);
    final found = <CodeWidgetAsset>[];
    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (_reservedNames.contains(name)) continue;
      found.add(
        CodeWidgetAsset(
          name: name,
          path: entity.path,
          size: entity.lengthSync(),
        ),
      );
    }
    found.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return found;
  }

  /// Copies a picture from the gallery into the widget's folder. Returns the
  /// name the code references it by, or null if the picker was dismissed.
  Future<String?> addImage(String blockId) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return null;
    final dir = await folderFor(blockId);
    final name = await _freeName(dir, p.basename(picked.path));
    await File(picked.path).copy(p.join(dir.path, name));
    notifyListeners();
    return name;
  }

  /// Creates a text file (a bit of JSON, a second stylesheet, a word list)
  /// with the given contents. Same path as an upload, minus the picker.
  Future<String> addTextFile(
    String blockId,
    String rawName,
    String contents,
  ) async {
    final dir = await folderFor(blockId);
    final name = await _freeName(dir, rawName);
    await _writeFile(dir, name, contents);
    notifyListeners();
    return name;
  }

  Future<String> readAsset(String blockId, String name) async {
    final dir = await folderFor(blockId);
    return _readFile(dir, name);
  }

  Future<void> writeAsset(String blockId, String name, String contents) async {
    final dir = await folderFor(blockId);
    await _writeFile(dir, name, contents);
    notifyListeners();
  }

  Future<void> deleteAsset(String blockId, String name) async {
    if (_reservedNames.contains(name)) return;
    final dir = await folderFor(blockId);
    final file = File(p.join(dir.path, name));
    if (file.existsSync()) await file.delete();
    notifyListeners();
  }

  /// Renaming is a real rename on disk, which means every `<img src="...">`
  /// pointing at the old name stops finding it. The editor says so before it
  /// happens rather than silently leaving a broken picture behind.
  Future<String?> renameAsset(
    String blockId,
    String name,
    String rawNewName,
  ) async {
    if (_reservedNames.contains(name)) return null;
    final dir = await folderFor(blockId);
    final file = File(p.join(dir.path, name));
    if (!file.existsSync()) return null;
    final newName = await _freeName(dir, rawNewName);
    await file.rename(p.join(dir.path, newName));
    notifyListeners();
    return newName;
  }

  /// Drops a widget's whole folder - called when its block is deleted, so a
  /// removed widget doesn't leave its pictures on the phone forever.
  Future<void> deleteFolder(String blockId) async {
    _cache.remove(blockId);
    _loaded.remove(blockId);
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, folderName, blockId));
    if (dir.existsSync()) await dir.delete(recursive: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_stateKey(blockId));
    notifyListeners();
  }

  /// Writes the composed document next to the widget's own files and hands
  /// back its path. It has to live in that folder rather than anywhere
  /// tidier: that is what makes `style.css`, `script.js` and every uploaded
  /// picture resolve as plain relative names.
  Future<String> prepareDocument(
    String blockId, {
    bool flexible = false,
  }) async {
    final source = await read(blockId);
    final dir = await folderFor(blockId);
    final file = File(p.join(dir.path, runFile));
    await file.writeAsString(
      buildCodeDocument(source, flexible: flexible),
      flush: true,
    );
    return file.path;
  }

  // --- the little key/value store the page keeps across restarts ---

  static String _stateKey(String blockId) => 'code_widget_state_$blockId';

  Future<Map<String, dynamic>> readState(String blockId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stateKey(blockId));
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Unreadable state is the same as none - the page starts over rather
      // than the widget refusing to run.
    }
    return {};
  }

  Future<void> writeState(String blockId, Map<String, dynamic> state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey(blockId), jsonEncode(state));
  }

  // --- settings backup ---

  /// Everything about one widget a settings backup should carry: the three
  /// code files, what the page stored, and the uploaded files small enough
  /// to travel (see [maxBackedUpFileBytes]).
  Future<Map<String, dynamic>> exportBlock(String blockId) async {
    final source = await read(blockId);
    final files = <String, String>{};
    for (final asset in await assets(blockId)) {
      if (!asset.fitsInBackup) continue;
      files[asset.name] = base64Encode(await File(asset.path).readAsBytes());
    }
    return {
      'html': source.html,
      'css': source.css,
      'js': source.js,
      'state': await readState(blockId),
      if (files.isNotEmpty) 'files': files,
    };
  }

  Future<void> importBlock(String blockId, Map<String, dynamic> json) async {
    await write(
      blockId,
      html: json['html'] as String? ?? '',
      css: json['css'] as String? ?? '',
      js: json['js'] as String? ?? '',
    );
    final state = json['state'];
    if (state is Map<String, dynamic>) await writeState(blockId, state);
    final files = json['files'];
    if (files is Map<String, dynamic>) {
      final dir = await folderFor(blockId);
      for (final entry in files.entries) {
        final name = sanitizeFileName(entry.key);
        if (_reservedNames.contains(name)) continue;
        try {
          await File(
            p.join(dir.path, name),
          ).writeAsBytes(base64Decode(entry.value as String));
        } catch (_) {
          // One unreadable file shouldn't cost the rest of the restore.
        }
      }
    }
    notifyListeners();
  }

  // --- helpers ---

  /// Folds away everything that would make a name awkward to reference from
  /// HTML - spaces, umlauts, slashes - rather than refusing the file. The
  /// name is what the code types, so it has to be typeable.
  static String sanitizeFileName(String raw) {
    final base = p.basename(raw.trim().toLowerCase());
    final cleaned = base.replaceAll(RegExp(r'[^a-z0-9._-]+'), '_');
    final trimmed = cleaned.replaceAll(RegExp(r'^[._]+'), '');
    return trimmed.isEmpty ? 'datei' : trimmed;
  }

  Future<String> _freeName(Directory dir, String rawName) async {
    var name = sanitizeFileName(rawName);
    if (_reservedNames.contains(name)) name = 'datei_$name';
    if (!File(p.join(dir.path, name)).existsSync()) return name;
    final stem = p.basenameWithoutExtension(name);
    final extension = p.extension(name);
    for (var i = 2; ; i++) {
      final candidate = '$stem$i$extension';
      if (!File(p.join(dir.path, candidate)).existsSync()) return candidate;
    }
  }

  static Future<String> _readFile(Directory dir, String name) async {
    final file = File(p.join(dir.path, name));
    if (!file.existsSync()) return '';
    try {
      return await file.readAsString();
    } catch (_) {
      // A file that isn't text (someone put a picture where the CSS goes)
      // reads as empty rather than taking the whole widget down.
      return '';
    }
  }

  static Future<void> _writeFile(
    Directory dir,
    String name,
    String contents,
  ) async {
    await File(p.join(dir.path, name)).writeAsString(contents, flush: true);
  }
}
