import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:legacy_wrapper_fe/main.dart';

void main() {
  testWidgets('Login screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const LegacyWrapperApp());
    expect(find.text('SWAAP Legacy Portal'), findsOneWidget);
    expect(find.text('Login Akademik'), findsOneWidget);
    expect(find.text('Login Dan Muat Jadwal'), findsOneWidget);
  });

  testWidgets('Debug candidates panel expands and supports copy callback', (
    WidgetTester tester,
  ) async {
    JadwalCandidateDebugModel? copied;
    const candidate = JadwalCandidateDebugModel(
      url: 'https://example.test/jadwal_ujian_siswa_view.php',
      finalUrl: 'https://example.test/jadwal_ujian_siswa_view.php',
      redirectChain: ['https://example.test/start', 'https://example.test/end'],
      statusCode: 200,
      viewhisCount: 3,
      courseHeaderCount: 1,
      methodInputCount: 1,
      hasJadwalKuliah: true,
      itemCount: 2,
      duplicateCount: 1,
      fetchError: '',
      bodyRaw:
          '<td colspan="4">METODOLOGI PENELITIAN | LUTVI RIYANDARI, S.Pd, M.Si</td>',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DebugCandidatesPanel(
            candidates: const [candidate],
            onCopy: (value) async {
              copied = value;
            },
          ),
        ),
      ),
    );

    expect(find.text('Debug Kandidat (Raw HTML)'), findsOneWidget);
    expect(find.textContaining('http=200'), findsOneWidget);

    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();

    expect(find.textContaining('redirect_chain:'), findsOneWidget);
    expect(find.textContaining('METODOLOGI PENELITIAN'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.copy_all_rounded));
    await tester.pumpAndSettle();

    expect(copied, isNotNull);
    expect(copied?.bodyRaw, contains('LUTVI RIYANDARI'));
  });
}
