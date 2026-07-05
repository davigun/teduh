import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teduh/domain/entities/bible.dart';
import 'package:teduh/features/plan/presentation/start_picker.dart';

void main() {
  const books = [
    BibleBook(code: 'PSA', order: 19, nama: 'Mazmur', testament: Testament.ot, chapterCount: 5, isAvailable: true),
    BibleBook(code: 'OBA', order: 31, nama: 'Obaja', testament: Testament.ot, chapterCount: 1, isAvailable: true),
    BibleBook(code: 'HAB', order: 35, nama: 'Habakuk', testament: Testament.ot, chapterCount: 3, isAvailable: false),
  ];

  testWidgets('multi-chapter book → chapter grid → returns book+chapter', (tester) async {
    BibleRef? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async => result = await showStartPicker(context, books),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Unavailable book is filtered out of the list.
    expect(find.text('Habakuk'), findsNothing);
    expect(find.text('Mazmur'), findsOneWidget);

    await tester.tap(find.text('Mazmur'));
    await tester.pumpAndSettle();

    // Chapter grid: pick chapter 3.
    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();

    expect(result, const BibleRef('PSA', 3));
  });

  testWidgets('single-chapter book returns chapter 1 without a grid', (tester) async {
    BibleRef? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async => result = await showStartPicker(context, books),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Obaja'));
    await tester.pumpAndSettle();

    expect(result, const BibleRef('OBA', 1));
  });
}
