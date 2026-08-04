import 'package:flutter/services.dart';

/// Hands a settings backup to Android's own share sheet, and reads one back
/// through the system document picker (see `MainActivity.kt`) - so sending
/// and receiving the backup file works through whatever app the user
/// already uses for that (Drive, email, Files, ...) without a plugin
/// dependency for it.
class BackupFileBridge {
  BackupFileBridge._();

  static const _channel = MethodChannel('hanneslauncher/backup');

  /// Writes [json] to a file and opens the share sheet for it. Returns false
  /// if no file could be written or shared.
  static Future<bool> export(String json) async {
    try {
      final ok = await _channel.invokeMethod<bool>('export', {'json': json});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system file picker and returns the picked file's text, or
  /// null if the user cancelled or it couldn't be read.
  static Future<String?> import() async {
    try {
      return await _channel.invokeMethod<String>('import');
    } catch (_) {
      return null;
    }
  }
}
