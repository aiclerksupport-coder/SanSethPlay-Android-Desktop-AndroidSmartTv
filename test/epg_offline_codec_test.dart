import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sanseth_play/core/epg_cache.dart';
import 'package:sanseth_play/core/epg_repository.dart';

void main() {
  const xml = '<tv><programme channel="a" start="20261117180000 +0530" '
      'stop="20261117190000 +0530"><title>Evening News</title></programme></tv>';

  test('plain and gzip XMLTV parse to identical UTC schedule', () {
    final plain = decodeAndParseXmlTv(utf8.encode(xml));
    final gzipFeed = decodeAndParseXmlTv(gzip.encode(utf8.encode(xml)));
    expect(plain['a']!.single.title, gzipFeed['a']!.single.title);
    expect(gzipFeed['a']!.single.start, DateTime.utc(2026, 11, 17, 12, 30));
  });

  test('invalid gzip raises a predictable failure', () {
    expect(
        () => decodeAndParseXmlTv([0x1f, 0x8b, 0, 0]), throwsFormatException);
  });

  test('last-known-good guide snapshot codec roundtrips', () {
    final original = parseXmlTv(xml);
    final snapshot = encodeEpgSnapshot(original);
    final restored = decodeEpgSnapshot(snapshot);
    expect(restored['a']!.single.title, 'Evening News');
    expect(restored['a']!.single.start, original['a']!.single.start);
  });

  test('damaged and oversized snapshot fails closed', () {
    expect(decodeEpgSnapshot([1, 2, 3]), isEmpty);
    expect(decodeEpgSnapshot(List.filled(EpgCache.maxPayloadBytes + 1, 0)),
        isEmpty);
  });
}
