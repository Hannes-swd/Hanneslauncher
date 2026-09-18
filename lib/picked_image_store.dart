import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Lets the user pick an image from the gallery and copies it into [folder]
/// inside the app's own documents directory, so it keeps working even if the
/// original gallery file is moved or deleted. Returns null if the picker was
/// dismissed without a selection.
///
/// [baseName] identifies what the picture belongs to (an app's package name,
/// a web app's id); a timestamp is appended because `Image.file` caches by
/// path, so reusing one would keep showing the previous picture.
Future<File?> pickImageInto(String folder, String baseName) async {
  final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (picked == null) return null;

  final appDir = await getApplicationDocumentsDirectory();
  final targetDir = Directory(p.join(appDir.path, folder));
  if (!targetDir.existsSync()) {
    await targetDir.create(recursive: true);
  }

  final safeName = baseName.replaceAll(RegExp(r'[^\w.]'), '_');
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final savedPath = p.join(
    targetDir.path,
    '$safeName.$stamp${p.extension(picked.path)}',
  );
  return File(picked.path).copy(savedPath);
}

/// Copies a picture the app already has into [folder] the same way
/// [pickImageInto] stores a picked one, without a picker in between.
///
/// What an app shortcut's icon needs: Android renders it into the cache
/// directory, which it empties whenever it is short of space - and it can do
/// so between two frames, so a saved shortcut pointing at the cache file
/// would lose its picture at no predictable moment.
///
/// Null when the source is gone or unreadable; the caller then keeps
/// whatever it had, which is better than replacing a picture with nothing.
Future<File?> copyImageInto(
  String folder,
  String baseName,
  File source,
) async {
  if (!source.existsSync()) return null;

  final appDir = await getApplicationDocumentsDirectory();
  final targetDir = Directory(p.join(appDir.path, folder));
  if (!targetDir.existsSync()) {
    await targetDir.create(recursive: true);
  }

  final safeName = baseName.replaceAll(RegExp(r'[^\w.]'), '_');
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final savedPath = p.join(
    targetDir.path,
    '$safeName.$stamp${p.extension(source.path)}',
  );
  try {
    return await source.copy(savedPath);
  } catch (_) {
    return null;
  }
}

/// Removes a picture previously stored by [pickImageInto]. Safe to call with
/// a null path or one whose file is already gone.
Future<void> deleteStoredImage(String? path) async {
  if (path == null) return;
  final file = File(path);
  if (file.existsSync()) {
    await file.delete();
  }
}
