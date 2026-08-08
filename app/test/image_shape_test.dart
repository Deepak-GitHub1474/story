import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/features/stories/data/image_shape.dart';

void main() {
  test('a square picture stays square', () {
    expect(postRatioFor(1000, 1000), closeTo(1.0, 0.001));
  });

  test('a tall picture is allowed down to four by five', () {
    expect(postRatioFor(800, 1000), closeTo(0.8, 0.001));
  });

  test('a very tall picture stops at four by five', () {
    expect(postRatioFor(500, 2000), closeTo(0.8, 0.001));
  });

  test('a wide picture is allowed out to the landscape bound', () {
    expect(postRatioFor(1910, 1000), closeTo(1.91, 0.001));
  });

  test('an absurdly wide picture stops at the landscape bound', () {
    expect(postRatioFor(4000, 500), closeTo(1.91, 0.001));
  });

  test('a picture with no size falls back to four by five', () {
    expect(postRatioFor(0, 0), closeTo(0.8, 0.001));
  });

  test('the whole picture fits inside the post when nothing is cropped', () {
    expect(isCropped(500, 2000), isTrue);
    expect(isCropped(1000, 1000), isFalse);
    expect(isCropped(800, 1000), isFalse);
  });
}
