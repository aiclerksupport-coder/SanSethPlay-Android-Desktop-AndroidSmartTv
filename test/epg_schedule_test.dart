import 'package:flutter_test/flutter_test.dart';
import 'package:sanseth_play/core/epg_repository.dart';
import 'package:sanseth_play/core/epg_schedule.dart';

void main() {
  final start = DateTime.utc(2026, 11, 17, 12);
  test('half-hour floor always stays in UTC', () {
    expect(halfHourFloor(DateTime.utc(2026, 11, 17, 12, 49)),
        DateTime.utc(2026, 11, 17, 12, 30));
  });
  test('timeline clips crossing window boundaries', () {
    final window = GuideWindow(start);
    final item = EpgProgram(
        channelId: 'id',
        title: 'News',
        start: start.subtract(const Duration(minutes: 30)),
        stop: start.add(const Duration(minutes: 30)));
    expect(window.leftFraction(item), 0);
    expect(window.widthFraction(item), closeTo(1 / 12, .00001));
  });
  test('off-screen events are ignored', () {
    final window = GuideWindow(start);
    final item = EpgProgram(
        channelId: 'id',
        title: 'Old',
        start: start.subtract(const Duration(hours: 2)),
        stop: start.subtract(const Duration(hours: 1)));
    expect(window.leftFraction(item), isNull);
    expect(window.widthFraction(item), 0);
  });
}
