import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

class EpgProgram {
  const EpgProgram(
      {required this.channelId,
      required this.title,
      required this.start,
      required this.stop,
      this.description = ''});
  final String channelId;
  final String title;
  final DateTime start;
  final DateTime stop;
  final String description;
}

/// XMLTV subset, with strict byte, item and date-range bounds.
class EpgRepository {
  EpgRepository({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  static const maxBytes = 8 * 1024 * 1024;
  static const maxExpandedBytes = 32 * 1024 * 1024;
  Future<Map<String, List<EpgProgram>>> fetch(Uri uri) async {
    if (!uri.hasAuthority ||
        !(uri.isScheme('https') || uri.isScheme('http')) ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('Only HTTP(S) EPG links allowed.');
    }
    final request = http.Request('GET', uri)..followRedirects = false;
    final response =
        await _client.send(request).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      await response.stream.drain<void>();
      throw const FormatException(
          'EPG download failed (redirects are not followed).');
    }
    final bytes = <int>[];
    await for (final chunk
        in response.stream.timeout(const Duration(seconds: 15))) {
      if (bytes.length + chunk.length > maxBytes) {
        throw const FormatException('EPG download exceeds 8 MB.');
      }
      bytes.addAll(chunk);
    }
    return compute(decodeAndParseXmlTv, bytes);
  }

  void dispose() => _client.close();
}

DateTime? parseXmlTvTime(String input) {
  final match = RegExp(
          r'^(\d{4})(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)?(?:\s*([+-])(\d\d)(\d\d))?')
      .firstMatch(input);
  if (match == null) {
    return null;
  }
  try {
    final instant = DateTime.utc(
        int.parse(match[1]!),
        int.parse(match[2]!),
        int.parse(match[3]!),
        int.parse(match[4]!),
        int.parse(match[5]!),
        int.parse(match[6] ?? '0'));
    if (match[7] == null) {
      return instant;
    }
    final offset =
        Duration(hours: int.parse(match[8]!), minutes: int.parse(match[9]!));
    return match[7] == '+' ? instant.subtract(offset) : instant.add(offset);
  } catch (_) {
    return null;
  }
}

Map<String, List<EpgProgram>> parseXmlTv(String contents) {
  final result = <String, List<EpgProgram>>{};
  final document = XmlDocument.parse(contents);
  final root = document.rootElement;
  if (root.name.local != 'tv') {
    throw const FormatException('XMLTV root must be tv.');
  }
  var count = 0;
  for (final element in root.findElements('programme')) {
    if (++count > 12000) {
      break;
    }
    final id = element.getAttribute('channel');
    final start = parseXmlTvTime(element.getAttribute('start') ?? '');
    final stop = parseXmlTvTime(element.getAttribute('stop') ?? '');
    final title = element.findElements('title').firstOrNull?.innerText.trim();
    if (id == null ||
        id.isEmpty ||
        start == null ||
        stop == null ||
        !stop.isAfter(start) ||
        title == null ||
        title.isEmpty) {
      continue;
    }
    final description =
        element.findElements('desc').firstOrNull?.innerText.trim() ?? '';
    (result[id] ??= []).add(EpgProgram(
        channelId: id,
        title: title,
        start: start,
        stop: stop,
        description: description));
  }
  for (final programs in result.values) {
    programs.sort((a, b) => a.start.compareTo(b.start));
  }
  return result;
}

/// Supports standard .xml and .xml.gz feeds without expanding unbounded data
/// on the Flutter UI isolate. Invalid compressed data fails safely.
Map<String, List<EpgProgram>> decodeAndParseXmlTv(List<int> bytes) {
  final compressed = bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
  final expanded = compressed ? gzip.decode(bytes) : bytes;
  if (expanded.length > EpgRepository.maxExpandedBytes) {
    throw const FormatException('Expanded XMLTV exceeds 32 MB.');
  }
  return parseXmlTv(utf8.decode(expanded, allowMalformed: true));
}
