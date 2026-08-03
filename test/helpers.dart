/// Helper per i test: AssetBundle che legge i file seed dal filesystem
/// (i test girano dalla root del package, dove `assets/gtfs/` esiste).
library;

import 'dart:io';

import 'package:flutter/services.dart';

class FileAssetBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = await File(key).readAsBytes();
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) =>
      File(key).readAsString();
}
