import 'package:flutter_test/flutter_test.dart';
import 'package:teduh/core/time/calendar_date.dart';
import 'package:teduh/data/devotion/santapan_harian_service.dart';

// Trimmed from the real alkitab.mobi/renungan/sh/2026/07/02/ markup: uppercase
// <P> body tags, entities, the "* * *" support appeal, and the #ayat full text.
const _fixture = '''
<div align="center"><span class="small">Kamis, 2 Juli 2026</span><hr/></div>
<div>
  <p>Bacaan: <a id="bibletexts-toggle" class="ui-state-default ui-corner-all" href="#ayat"><em>1 Samuel 11</em></a></p>
  <hr/>
  <p><strong>Raja yang Dikuasai Roh</strong></p>
  <P>Ketika ada ancaman bahaya terhadap teman kita atau orang-orang di
sekitar kita, kira-kira apa yang akan kita lakukan?</P>
<P>Saat Nahas, orang Amon mengepung Yabes-Gilead, mereka semua menangis (1-4).</P>
<P>Dengan taat dan patuh kepada Tuhanlah, Ia akan membangkitkan keberanian
kita. Dengan penuh kuasa Tuhan akan mengadakan penyelamatan. [NRG]</P>
<pre> * * *
Mari memberkati para hamba Tuhan dan narapidana di banyak daerah.</pre>
<p>Diskusi renungan ini di Facebook</p>
<div id="ayat"><p>11:1 Maka Nahas, orang Amon itu, bergerak maju dan berkemah
mengepung Yabesh-Gilead.</p></div>
</div>
''';

void main() {
  const date = CalendarDate(2026, 7, 2);

  test('parses title, passage, and body paragraphs', () {
    final d = parseSantapanHarian(_fixture, date);
    expect(d, isNotNull);
    expect(d!.title, 'Raja yang Dikuasai Roh');
    expect(d.passage, '1 Samuel 11');
    expect(d.body.split('\n\n'), hasLength(3));
    expect(d.body, startsWith('Ketika ada ancaman bahaya'));
    expect(d.body, endsWith('[NRG]'));
  });

  test('excludes the support appeal and the full Bible text', () {
    final d = parseSantapanHarian(_fixture, date)!;
    expect(d.body, isNot(contains('Mari memberkati')));
    expect(d.body, isNot(contains('11:1')));
    expect(d.body, isNot(contains('Diskusi renungan')));
  });

  test('decodes entities and collapses whitespace', () {
    final d = parseSantapanHarian(
      _fixture.replaceFirst('apa yang akan kita lakukan?',
          '&#8220;apa &amp; siapa&#8221;   yang akan kita lakukan?'),
      date,
    )!;
    expect(d.body, contains('"apa & siapa" yang akan kita lakukan?'));
  });

  test('returns null on a page that is not a devotion', () {
    expect(parseSantapanHarian('<html><body>404</body></html>', date), isNull);
    expect(parseSantapanHarian('', date), isNull);
  });
}
