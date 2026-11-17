import 'channel.dart';

/// Accept only HTTP(S) media links. M3U8 streaming URLs can be opened directly
/// in the Player, while M3U playlists should be parsed via this class.
class M3uParser {
  static List<StreamChannel> parse(String source) {
    final results = <StreamChannel>[];
    String? name;
    String group = 'Uncategorized';
    Uri? logo;
    String? tvgId;
    String? catchupTemplate;
    int? catchupDays;
    for (final raw
        in source.replaceFirst('\uFEFF', '').split(RegExp(r'\r\n|\n|\r'))) {
      final line = raw.trim();
      if (line.startsWith('#EXTINF:')) {
        final comma = _commaOutsideQuotes(line);
        name = comma >= 0 ? line.substring(comma + 1).trim() : null;
        final metadata = comma >= 0 ? line.substring(0, comma) : line;
        name = name?.isNotEmpty == true ? name : _attr(metadata, 'tvg-name');
        group = _attr(metadata, 'group-title') ?? 'Uncategorized';
        tvgId = _attr(metadata, 'tvg-id');
        logo = _safeUri(_attr(metadata, 'tvg-logo'));
        final mode = _attr(metadata, 'catchup')?.toLowerCase();
        final candidate = _attr(metadata, 'catchup-source');
        catchupTemplate = mode != null &&
                mode != 'none' &&
                candidate != null &&
                (candidate.startsWith('https://') ||
                    candidate.startsWith('http://'))
            ? candidate
            : null;
        final days = int.tryParse(_attr(metadata, 'catchup-days') ?? '');
        catchupDays = days != null && days > 0 ? days.clamp(1, 30) : null;
      } else if (line.startsWith('#EXTGRP:')) {
        group = line.substring('#EXTGRP:'.length).trim();
      } else if (line.isNotEmpty && !line.startsWith('#')) {
        final url = _safeUri(line);
        if (url != null && results.length < 20000) {
          final fallback =
              url.pathSegments.isNotEmpty ? url.pathSegments.last : url.host;
          results.add(StreamChannel(
            name: (name != null && name.isNotEmpty) ? name : fallback,
            url: url,
            group: group.isEmpty ? 'Uncategorized' : group,
            logo: logo,
            tvgId: tvgId,
            catchupTemplate: catchupTemplate,
            catchupDays: catchupDays,
          ));
        }
        name = null;
        group = 'Uncategorized';
        logo = null;
        tvgId = null;
        catchupTemplate = null;
        catchupDays = null;
      }
    }
    return results;
  }

  static int _commaOutsideQuotes(String line) {
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      if (line[i] == '"') {
        quoted = !quoted;
      }
      if (!quoted && line[i] == ',') {
        return i;
      }
    }
    return -1;
  }

  static String? _attr(String metadata, String key) {
    final match =
        RegExp('(?:^|\\s)${RegExp.escape(key)}="([^"]*)"').firstMatch(metadata);
    return match?.group(1);
  }

  static Uri? _safeUri(String? value) {
    if (value == null) {
      return null;
    }
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
            (uri.scheme == 'https' || uri.scheme == 'http') &&
            uri.host.isNotEmpty
        ? uri
        : null;
  }
}
