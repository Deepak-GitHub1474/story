import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/features/chat/providers/chat_providers.dart';

void main() {
  test('the key on this phone is what gets re-wrapped', () {
    expect(
      rewrapSource(hasDeviceKey: true, hasBackup: true),
      RewrapSource.device,
    );
  });

  test('a locked chat falls back to the backup instead of giving up', () {
    expect(
      rewrapSource(hasDeviceKey: false, hasBackup: true),
      RewrapSource.backup,
      reason: 'giving up here leaves the backup under the old password',
    );
  });

  test('someone who never opened chat has nothing to carry over', () {
    expect(
      rewrapSource(hasDeviceKey: false, hasBackup: false),
      RewrapSource.none,
    );
  });

  test('the device key is preferred so no password is needed', () {
    expect(
      rewrapSource(hasDeviceKey: true, hasBackup: false),
      RewrapSource.device,
    );
  });
}
