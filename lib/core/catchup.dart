import 'channel.dart';

/// Builds replay links only for explicitly advertised M3U catchup-source URLs.
/// This supports Unix timestamp placeholders used by some IPTV providers.
/// It does not invent DVR support for plain HLS streams.
class CatchupUrl {
  static Uri? forProgramme(StreamChannel channel, DateTime start, DateTime stop,
      {DateTime? now}) {
    final source = channel.catchupTemplate;
    if (source == null || source.length > 4096) {
      return null;
    }
    final utcStart = start.toUtc();
    final utcStop = stop.toUtc();
    final current = (now ?? DateTime.now()).toUtc();
    if (!utcStop.isAfter(utcStart) || utcStop.isAfter(current)) {
      return null;
    }
    final days = channel.catchupDays ?? 7;
    if (utcStart.isBefore(current.subtract(Duration(days: days)))) {
      return null;
    }
    final seconds = utcStop.difference(utcStart).inSeconds;
    if (seconds <= 0 || seconds > 12 * 3600) {
      return null;
    }
    final begin = utcStart.millisecondsSinceEpoch ~/ 1000;
    final end = utcStop.millisecondsSinceEpoch ~/ 1000;
    if (!RegExp(r'\{(?:utc|utcend|start|timestamp|duration|end|Y|m|d|H|M|S)\}')
        .hasMatch(source)) {
      return null;
    }
    String two(int v) => v.toString().padLeft(2, '0');
    final url = source
        .replaceAll('{utcend}', '$end')
        .replaceAll('{Y}', '${utcStart.year}')
        .replaceAll('{m}', two(utcStart.month))
        .replaceAll('{d}', two(utcStart.day))
        .replaceAll('{H}', two(utcStart.hour))
        .replaceAll('{M}', two(utcStart.minute))
        .replaceAll('{S}', two(utcStart.second))
        .replaceAll('{utc}', '$begin')
        .replaceAll('{start}', '$begin')
        .replaceAll('{timestamp}', '$begin')
        .replaceAll('{end}', '$end')
        .replaceAll('{duration}', '$seconds');
    // Unsupported placeholders must not accidentally reach a media decoder.
    if (RegExp(r'\{[^}]+\}').hasMatch(url)) {
      return null;
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.userInfo.isNotEmpty ||
        uri.host.isEmpty ||
        !(uri.scheme == 'https' || uri.scheme == 'http')) {
      return null;
    }
    return uri;
  }

  static StreamChannel? archivedProgramme(
      StreamChannel channel, String title, DateTime start, DateTime stop,
      {DateTime? now}) {
    final uri = forProgramme(channel, start, stop, now: now);
    if (uri == null) {
      return null;
    }
    return StreamChannel(
      name: '$title • ${channel.name}',
      url: uri,
      group: 'Catch-up',
      logo: channel.logo,
      tvgId: channel.tvgId,
      isVod: true,
    );
  }
}
