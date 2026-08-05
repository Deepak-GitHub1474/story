import 'dart:typed_data';

const _minimumBytes = 12;

const _imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif'};
const _videoExtensions = {'mp4', 'mov', 'm4v'};
const _pdfExtensions = {'pdf'};

bool _startsWith(Uint8List bytes, List<int> prefix, {int offset = 0}) {
  if (bytes.length < offset + prefix.length) return false;
  for (var index = 0; index < prefix.length; index++) {
    if (bytes[offset + index] != prefix[index]) return false;
  }
  return true;
}

String? _sniff(Uint8List bytes) {
  if (_startsWith(bytes, [0xFF, 0xD8, 0xFF])) return 'image';
  if (_startsWith(bytes, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) return 'image';
  if (_startsWith(bytes, [0x47, 0x49, 0x46, 0x38])) return 'image';
  if (_startsWith(bytes, [0x52, 0x49, 0x46, 0x46]) &&
      _startsWith(bytes, [0x57, 0x45, 0x42, 0x50], offset: 8)) {
    return 'image';
  }
  if (_startsWith(bytes, [0x66, 0x74, 0x79, 0x70], offset: 4)) {
    return _startsWith(bytes, [0x68, 0x65, 0x69], offset: 8) ? 'image' : 'video';
  }
  if (_startsWith(bytes, [0x25, 0x50, 0x44, 0x46, 0x2D])) return 'pdf';
  return null;
}

String? _fromExtension(String filename) {
  final dot = filename.lastIndexOf('.');
  if (dot < 0) return null;
  final extension = filename.substring(dot + 1).toLowerCase();
  if (_imageExtensions.contains(extension)) return 'image';
  if (_videoExtensions.contains(extension)) return 'video';
  if (_pdfExtensions.contains(extension)) return 'pdf';
  return null;
}

String? detectKind(Uint8List bytes, String filename) {
  if (bytes.length < _minimumBytes) return null;
  final sniffed = _sniff(bytes);
  if (sniffed == null) return null;
  return sniffed == _fromExtension(filename) ? sniffed : null;
}
