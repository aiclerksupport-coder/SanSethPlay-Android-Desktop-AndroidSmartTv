import 'package:flutter_test/flutter_test.dart';
import 'package:sanseth_play/player/android_cast.dart';

void main() {
  test('only public direct HTTPS playback URLs are eligible', () {
    expect(
        AndroidCast.isPublicCastUri(
            Uri.parse('https://cdn.example.org/live.m3u8')),
        isTrue);
    expect(
        AndroidCast.isPublicCastUri(
            Uri.parse('http://cdn.example.org/live.m3u8')),
        isFalse);
    expect(
        AndroidCast.isPublicCastUri(
            Uri.parse('https://cdn.example.org/live.m3u8?token=secret')),
        isFalse);
    expect(
        AndroidCast.isPublicCastUri(Uri.parse('https://192.168.1.2/live.m3u8')),
        isFalse);
    expect(
        AndroidCast.isPublicCastUri(Uri.parse('https://172.28.1.2/live.m3u8')),
        isFalse);
    expect(
        AndroidCast.isPublicCastUri(Uri.parse('https://169.254.1.2/live.m3u8')),
        isFalse);
    expect(AndroidCast.isPublicCastUri(Uri.parse('https://[::1]/live.m3u8')),
        isFalse);
    expect(
        AndroidCast.isPublicCastUri(
            Uri.parse('https://cdn.example.org/account.mp4')),
        isTrue);
  });
}
