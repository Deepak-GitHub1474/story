import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/features/vault/data/file_kind.dart';

Uint8List bytes(List<int> head, {int pad = 64}) =>
    Uint8List.fromList([...head, ...List<int>.filled(pad, 0)]);

void main() {
  test('a jpeg is an image', () {
    expect(detectKind(bytes([0xFF, 0xD8, 0xFF, 0xE0]), 'holiday.jpg'), 'image');
  });

  test('a png is an image', () {
    expect(
      detectKind(bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]), 'a.png'),
      'image',
    );
  });

  test('a pdf is a pdf', () {
    expect(detectKind(bytes([0x25, 0x50, 0x44, 0x46, 0x2D]), 'letter.pdf'), 'pdf');
  });

  test('an mp4 is a video', () {
    expect(
      detectKind(
        bytes([0, 0, 0, 0x20, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6F, 0x6D]),
        'clip.mp4',
      ),
      'video',
    );
  });

  test('a word document is refused', () {
    expect(detectKind(bytes([0x50, 0x4B, 0x03, 0x04]), 'report.docx'), isNull);
  });

  test('a spreadsheet is refused', () {
    expect(detectKind(bytes([0x50, 0x4B, 0x03, 0x04]), 'budget.xlsx'), isNull);
  });

  test('an mp3 is refused because audio is not stored', () {
    expect(detectKind(bytes([0x49, 0x44, 0x33, 0x04]), 'song.mp3'), isNull);
  });

  test('a renamed executable is refused even with an image extension', () {
    expect(detectKind(bytes([0x4D, 0x5A, 0x90, 0x00]), 'totally.png'), isNull);
  });

  test('a jpeg renamed to .pdf is refused because the bytes disagree', () {
    expect(detectKind(bytes([0xFF, 0xD8, 0xFF, 0xE0]), 'invoice.pdf'), isNull);
  });

  test('a file too short to identify is refused', () {
    expect(detectKind(Uint8List.fromList([0xFF, 0xD8]), 'tiny.jpg'), isNull);
  });
}
