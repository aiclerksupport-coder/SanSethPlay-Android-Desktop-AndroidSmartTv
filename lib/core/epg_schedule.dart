import 'epg_repository.dart';

/// Pure timeline math: clipping keeps events within the visible window.
/// The UI can render long schedules without loading all programme widgets.
class GuideWindow {
  const GuideWindow(this.start, {this.duration = const Duration(hours: 6)});
  final DateTime start;
  final Duration duration;
  DateTime get end => start.add(duration);

  double? leftFraction(EpgProgram event) {
    if (!event.stop.isAfter(start) || !event.start.isBefore(end)) {
      return null;
    }
    final clipped = event.start.isBefore(start) ? start : event.start;
    return clipped.difference(start).inMilliseconds / duration.inMilliseconds;
  }

  double widthFraction(EpgProgram event) {
    final from = event.start.isBefore(start) ? start : event.start;
    final to = event.stop.isAfter(end) ? end : event.stop;
    if (!to.isAfter(from)) {
      return 0;
    }
    return to.difference(from).inMilliseconds / duration.inMilliseconds;
  }
}

DateTime halfHourFloor(DateTime time) => DateTime.utc(
    time.year, time.month, time.day, time.hour, time.minute < 30 ? 0 : 30);
