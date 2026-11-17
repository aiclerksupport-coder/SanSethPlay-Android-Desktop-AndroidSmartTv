import 'channel.dart';

/// Categories are virtual views within one saved source, not duplicate URL
/// records. Preserves original M3U group-title spelling for presentation.
class ChannelCategories {
  static const all = 'All groups';

  static Map<String, int> counts(Iterable<StreamChannel> channels) {
    final result = <String, int>{};
    for (final channel in channels) {
      final category =
          channel.group.trim().isEmpty ? 'Uncategorized' : channel.group.trim();
      result.update(category, (n) => n + 1, ifAbsent: () => 1);
    }
    return Map.unmodifiable(result);
  }

  static List<String> labels(Iterable<StreamChannel> channels) {
    final labels = counts(channels).keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [all, ...labels];
  }
}
