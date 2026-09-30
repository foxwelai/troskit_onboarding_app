import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// One AI-generated product image kept in the app's private documents folder.
class AiVaultImage {
  final String id;
  final String featureKey;
  final String featureLabel;
  final String fileName;
  final DateTime createdAt;

  const AiVaultImage({
    required this.id,
    required this.featureKey,
    required this.featureLabel,
    required this.fileName,
    required this.createdAt,
  });

  File fileFor(Directory dir) => File('${dir.path}/$fileName');

  Map<String, dynamic> toJson() => {
        'id': id,
        'feature_key': featureKey,
        'feature_label': featureLabel,
        'file_name': fileName,
        'created_at': createdAt.toIso8601String(),
      };

  factory AiVaultImage.fromJson(Map<String, dynamic> json) {
    return AiVaultImage(
      id: (json['id'] ?? '').toString(),
      featureKey: (json['feature_key'] ?? '').toString(),
      featureLabel: (json['feature_label'] ?? 'AI Image').toString(),
      fileName: (json['file_name'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

/// Private local vault for AI-enhanced product photos.
/// Images stay even when the user picks **Use Original image** for upload.
class AiImageVault {
  AiImageVault._();

  static const _indexFile = 'index.json';
  static const _folder = 'ai_enhanced_images';

  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_folder');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<File> _index() async {
    final dir = await _dir();
    return File('${dir.path}/$_indexFile');
  }

  static Future<List<AiVaultImage>> list() async {
    final index = await _index();
    if (!await index.exists()) return [];
    try {
      final raw = jsonDecode(await index.readAsString());
      if (raw is! List) return [];
      final dir = await _dir();
      final out = <AiVaultImage>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final entry = AiVaultImage.fromJson(Map<String, dynamic>.from(item));
        if (entry.id.isEmpty || entry.fileName.isEmpty) continue;
        if (await entry.fileFor(dir).exists()) out.add(entry);
      }
      out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return out;
    } catch (_) {
      return [];
    }
  }

  static Future<void> _writeIndex(List<AiVaultImage> items) async {
    final index = await _index();
    await index.writeAsString(
      jsonEncode(items.map((e) => e.toJson()).toList()),
      flush: true,
    );
  }

  /// Persist AI bytes. Returns the vault entry (file is always kept locally).
  static Future<AiVaultImage> saveBytes({
    required List<int> bytes,
    required String featureKey,
    required String featureLabel,
  }) async {
    final dir = await _dir();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final fileName = 'ai_$id.png';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    final entry = AiVaultImage(
      id: id,
      featureKey: featureKey,
      featureLabel: featureLabel,
      fileName: fileName,
      createdAt: DateTime.now(),
    );
    final items = await list();
    items.insert(0, entry);
    await _writeIndex(items);
    return entry;
  }

  static Future<File?> fileFor(AiVaultImage entry) async {
    final dir = await _dir();
    final f = entry.fileFor(dir);
    return await f.exists() ? f : null;
  }

  static Future<bool> remove(String id) async {
    final dir = await _dir();
    final items = await list();
    final idx = items.indexWhere((e) => e.id == id);
    if (idx < 0) return false;
    final entry = items[idx];
    final file = entry.fileFor(dir);
    if (await file.exists()) {
      await file.delete();
    }
    items.removeAt(idx);
    await _writeIndex(items);
    return true;
  }
}
