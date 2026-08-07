import 'package:flutter/services.dart';

class PickedFile {
  const PickedFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

class FilePicking {
  const FilePicking._();

  static const MethodChannel _channel = MethodChannel('story/files');

  static const List<String> vaultMimeTypes = [
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'image/heic',
    'image/heif',
    'video/mp4',
    'video/quicktime',
    'application/pdf',
  ];

  static Future<PickedFile?> pick({
    List<String> mimeTypes = vaultMimeTypes,
  }) async {
    final picked = await _channel.invokeMapMethod<String, dynamic>('pick', {
      'mimeTypes': mimeTypes,
    });

    if (picked == null) return null;

    final bytes = picked['bytes'];
    if (bytes is! Uint8List) return null;

    return PickedFile(name: picked['name'] as String? ?? 'file', bytes: bytes);
  }
}
