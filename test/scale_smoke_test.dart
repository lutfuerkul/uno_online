import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:uno_online/okey/screens/okey_bot_screen.dart';
import 'package:uno_online/pisti/screens/pisti_bot_screen.dart';
import 'package:uno_online/screens/game_select_screen.dart';
import 'package:uno_online/screens/uno_bot_screen.dart';
import 'package:uno_online/theme/ui_scale.dart';

/// Test edilen ekran boyutları: dar telefonlardan (Honor/SE sınıfı) tablete.
const _sizes = <String, Size>{
  'çok dar 320x640': Size(320, 640),
  'dar 360x780': Size(360, 780),
  'referans 390x844': Size(390, 844),
  'geniş 430x932': Size(430, 932),
  'tablet 800x1280': Size(800, 1280),
};

Future<void> _pumpAt(WidgetTester tester, Size size, Widget child) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ekranlar hiçbir boyutta taşmıyor', () {
    for (final entry in _sizes.entries) {
      final label = entry.key;
      final size = entry.value;

      testWidgets('oyun seçim — $label', (tester) async {
        await _pumpAt(tester, size, const GameSelectScreen());
        expect(tester.takeException(), isNull);
      });

      testWidgets('UNO kurulum — $label', (tester) async {
        await _pumpAt(
            tester, size, const UnoBotScreen(initialPlayerName: 'Ali'));
        expect(tester.takeException(), isNull);
      });

      testWidgets('Okey kurulum — $label', (tester) async {
        await _pumpAt(
            tester, size, const OkeyBotScreen(initialPlayerName: 'Ali'));
        expect(tester.takeException(), isNull);
      });

      testWidgets('Pişti kurulum — $label', (tester) async {
        await _pumpAt(
            tester, size, const PistiBotScreen(initialPlayerName: 'Ali'));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('computeUiScale', () {
    double scaleFor(Size s) =>
        computeUiScale(BoxConstraints.tight(s));

    test('referans ekranda katsayı tam 1.0', () {
      expect(scaleFor(const Size(390, 844)), 1.0);
    });

    test('dar ekranda 1in altına iner, geniş ekranda üstüne çıkar', () {
      expect(scaleFor(const Size(320, 640)), lessThan(1.0));
      expect(scaleFor(const Size(430, 932)), greaterThan(1.0));
    });

    test('uç boyutlarda 0.75-1.15 aralığına sıkışır', () {
      expect(scaleFor(const Size(200, 400)), 0.75);
      expect(scaleFor(const Size(1600, 2400)), 1.15);
    });
  });

  group('oyun seçim ekranı gerçekten orantılı ölçekleniyor', () {
    // Uygulama ikonu referansta 64px; ölçek katsayısıyla çarpılmalı.
    Future<double> iconWidthAt(WidgetTester tester, Size size) async {
      await _pumpAt(tester, size, const GameSelectScreen());
      return tester
          .getSize(find.byType(Image).first)
          .width;
    }

    for (final entry in _sizes.entries) {
      testWidgets('ikon boyutu ${entry.key}', (tester) async {
        final expected =
            64 * computeUiScale(BoxConstraints.tight(entry.value));
        expect(await iconWidthAt(tester, entry.value),
            moreOrLessEquals(expected, epsilon: 0.01));
      });
    }

    testWidgets('dar ekranda referanstan küçük, geniş ekranda büyük çizilir',
        (tester) async {
      final dar = await iconWidthAt(tester, const Size(320, 640));
      final ref = await iconWidthAt(tester, const Size(390, 844));
      final genis = await iconWidthAt(tester, const Size(430, 932));
      expect(dar, lessThan(ref));
      expect(genis, greaterThan(ref));
    });
  });
}
