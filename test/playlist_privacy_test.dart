import 'package:flutter_test/flutter_test.dart';
import 'package:sanseth_play/core/playlist_privacy.dart';

void main() {
  test('rejects universal, repetitive and sequential PINs', () {
    expect(PlaylistPrivacyStore.isAcceptablePin('0000000000'), false);
    expect(PlaylistPrivacyStore.isAcceptablePin('111111'), false);
    expect(PlaylistPrivacyStore.isAcceptablePin('123456'), false);
    expect(PlaylistPrivacyStore.isAcceptablePin('654321'), false);
    expect(PlaylistPrivacyStore.isAcceptablePin('281940'), true);
  });

  test('hidden and locked are independent states', () {
    const normal = PlaylistPrivacy();
    const hidden = PlaylistPrivacy(hidden: true);
    const locked = PlaylistPrivacy(locked: true);
    const both = PlaylistPrivacy(hidden: true, locked: true);
    expect(normal.protected, false);
    expect(hidden.hidden, true);
    expect(hidden.locked, false);
    expect(locked.hidden, false);
    expect(locked.locked, true);
    expect(both.protected, true);
    expect(PlaylistPrivacy.fromJson(hidden.toJson()).hidden, true);
    expect(PlaylistPrivacy.fromJson(locked.toJson()).locked, true);
    expect(PlaylistPrivacy.fromJson(both.toJson()).locked, true);
    expect(PlaylistPrivacy.fromJson(null).protected, false);
  });
}
