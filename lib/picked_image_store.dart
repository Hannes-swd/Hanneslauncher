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

/// Removes a picture previously stored by [pickImageInto]. Safe to call with
/// a null path or one whose file is already gone.
Future<void> deleteStoredImage(String? path) async {
  if (path == null) return;
  final file = File(path);
  if (file.existsSync()) {
    await file.delete();
  }
}
