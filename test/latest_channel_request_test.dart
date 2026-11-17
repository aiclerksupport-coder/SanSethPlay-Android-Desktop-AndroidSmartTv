import 'package:flutter_test/flutter_test.dart';
import 'package:sanseth_play/player/latest_channel_request.dart';

void main() {
  test('latest selection wins when channel changes arrive rapidly', () {
    final mailbox = LatestChannelRequest();
    mailbox.request('https://example.com/one.m3u8');
    mailbox.request('https://example.com/two.m3u8');
    expect(mailbox.take(), 'https://example.com/two.m3u8');
    expect(mailbox.take(), isNull);
  });

  test('selection made during in-flight open is preserved', () {
    final mailbox = LatestChannelRequest();
    mailbox.request('https://example.com/one.m3u8');
    expect(mailbox.take(), contains('one'));
    mailbox.request('https://example.com/three.m3u8');
    expect(mailbox.hasPending, isTrue);
    expect(mailbox.take(), contains('three'));
  });

  test('clear removes pending selection on disposal', () {
    final mailbox = LatestChannelRequest()..request('a');
    mailbox.clear();
    expect(mailbox.hasPending, isFalse);
  });
}
