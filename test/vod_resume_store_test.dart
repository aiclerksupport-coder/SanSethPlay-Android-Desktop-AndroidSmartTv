import 'package:flutter_test/flutter_test.dart';
import 'package:sanseth_play/core/vod_resume_store.dart';

void main() {
  test('resume ignores live/short/finished positions', () {
    const full = Duration(minutes: 90);
    expect(VodResumeStore.validResume(0, full), isNull);
    expect(
        VodResumeStore.validResume(50000, const Duration(minutes: 2)), isNull);
    expect(
        VodResumeStore.validResume(
            const Duration(minutes: 88).inMilliseconds, full),
        isNull);
    expect(
        VodResumeStore.validResume(
            const Duration(minutes: 12).inMilliseconds, full),
        const Duration(minutes: 12));
  });
  test('resume key never exposes stream credentials', () {
    final key = VodResumeStore.keyFor(
        Uri.parse('https://example.org/movie/secret:password/123.mp4'));
    expect(key, isNot(contains('password')));
    expect(key, startsWith(VodResumeStore.prefix));
  });
}
