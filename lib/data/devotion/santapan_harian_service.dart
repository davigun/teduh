import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/time/calendar_date.dart';

/// One day's Santapan Harian devotion (© Scripture Union Indonesia /
/// Yayasan Pancar Pijar Alkitab, served by SABDA at alkitab.mobi).
/// Shown as the closing card after today's last reading chapter.
class Devotion {
  const Devotion({
    required this.date,
    required this.title,
    required this.passage,
    required this.body,
  });

  final CalendarDate date;
  final String title;
  final String passage; // e.g. "1 Samuel 11" — SH follows its own calendar
  final String body; // paragraphs joined by \n\n
}

const _prefsKey = 'sh_devotion';

/// Parse a devotion out of an alkitab.mobi/renungan/sh page. Returns null when
/// the page doesn't look like a devotion (layout change, error page) — the UI
/// then simply shows no card; reading never depends on this.
Devotion? parseSantapanHarian(String html, CalendarDate date) {
  final passage =
      RegExp(r'Bacaan:.*?<em>(.*?)</em>', dotAll: true).firstMatch(html);
  final title = RegExp(r'<p>\s*<strong>(.*?)</strong>\s*</p>', dotAll: true)
      .firstMatch(html);
  if (passage == null || title == null) return null;

  // Body = paragraphs between the title and the support-appeal / full-text
  // sections that follow the devotion proper.
  var region = html.substring(title.end);
  for (final stop in ['* * *', 'id="ayat"']) {
    final i = region.indexOf(stop);
    if (i >= 0) region = region.substring(0, i);
  }
  final paragraphs =
      RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true)
          .allMatches(region)
          .map((m) => _plainText(m.group(1)!))
          .where((t) => t.isNotEmpty)
          .toList();
  if (paragraphs.isEmpty) return null;

  return Devotion(
    date: date,
    title: _plainText(title.group(1)!),
    passage: _plainText(passage.group(1)!),
    body: paragraphs.join('\n\n'),
  );
}

String _plainText(String html) {
  var t = html.replaceAll(RegExp(r'<[^>]+>'), '');
  const entities = {
    '&nbsp;': ' ',
    '&#160;': ' ',
    '&quot;': '"',
    '&#8220;': '"',
    '&#8221;': '"',
    '&#8216;': "'",
    '&#8217;': "'",
    '&#8211;': '–',
    '&#8212;': '—',
    '&amp;': '&', // last, so freed entities aren't re-decoded
  };
  entities.forEach((k, v) => t = t.replaceAll(k, v));
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Fetches one day's devotion. Offline / non-200 / parse failure ⇒ null.
class SantapanHarianService {
  Future<Devotion?> fetch(CalendarDate date) async {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    final url =
        Uri.parse('https://alkitab.mobi/renungan/sh/${date.year}/$mm/$dd/');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(url);
      final response = await request.close().timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final html = await response.transform(utf8.decoder).join();
      return parseSantapanHarian(html, date);
    } catch (_) {
      return null; // offline / transient — retried on the next reader open
    } finally {
      client.close();
    }
  }
}

/// Today's devotion: prefs cache (one key, today only) → network → null.
final devotionProvider = FutureProvider<Devotion?>((ref) async {
  final today = CalendarDate.fromLocal(ref.watch(clockProvider).nowLocal());
  final prefs = ref.watch(sharedPreferencesProvider);

  final cached = prefs.getString(_prefsKey);
  if (cached != null) {
    try {
      final m = jsonDecode(cached) as Map<String, dynamic>;
      if (m['date'] == today.toIso()) {
        return Devotion(
          date: today,
          title: m['title'] as String,
          passage: m['passage'] as String,
          body: m['body'] as String,
        );
      }
    } catch (_) {/* corrupt cache: fall through to refetch */}
  }

  final fresh = await SantapanHarianService().fetch(today);
  if (fresh != null) {
    await prefs.setString(
      _prefsKey,
      jsonEncode({
        'date': today.toIso(),
        'title': fresh.title,
        'passage': fresh.passage,
        'body': fresh.body,
      }),
    );
  }
  return fresh;
});
