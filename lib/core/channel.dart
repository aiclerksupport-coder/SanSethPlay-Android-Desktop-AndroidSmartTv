import 'package:flutter/foundation.dart';

@immutable
class StreamChannel {
  const StreamChannel({
    required this.name,
    required this.url,
    this.group = 'Uncategorized',
    this.logo,
    this.tvgId,
    this.isVod = false,
    this.catchupTemplate,
    this.catchupDays,
  });

  final String name;
  final Uri url;
  final String group;
  final Uri? logo;
  final String? tvgId;

  /// Explicit on-demand content; never resume an unseekable live channel.
  final bool isVod;

  /// Provider-declared archive URL template (not universally available).
  final String? catchupTemplate;
  final int? catchupDays;
}
