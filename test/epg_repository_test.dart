import 'package:flutter_test/flutter_test.dart';
import 'package:sanseth_play/core/epg_repository.dart';

void main() {
  test('XMLTV parses program and timezone correctly', () {
    const xml =
        '''<tv><programme channel="news.id" start="20261117180000 +0530" stop="20261117190000 +0530"><title>Evening News</title><desc>Live update</desc></programme></tv>''';
    final result = parseXmlTv(xml);
    expect(result['news.id']!.single.title, 'Evening News');
    expect(result['news.id']!.single.start.toIso8601String(),
        '2026-11-17T12:30:00.000Z');
  });
  test('XMLTV rejects invalid root and ignores invalid program', () {
    expect(() => parseXmlTv('<bad/>'), throwsFormatException);
    expect(parseXmlTv('<tv><programme channel="a"/></tv>'), isEmpty);
  });
}
