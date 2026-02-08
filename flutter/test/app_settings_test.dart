import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_booking/app_settings.dart';

void main() {
  group('AppSettings', () {
    testWidgets('provides locale and themeMode to descendants', (tester) async {
      String? capturedLocale;
      ThemeMode? capturedThemeMode;

      await tester.pumpWidget(
        AppSettings(
          locale: 'ru',
          themeMode: ThemeMode.dark,
          toggleLocale: () {},
          toggleTheme: () {},
          child: Builder(
            builder: (context) {
              final settings = AppSettings.of(context);
              capturedLocale = settings.locale;
              capturedThemeMode = settings.themeMode;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(capturedLocale, 'ru');
      expect(capturedThemeMode, ThemeMode.dark);
    });

    testWidgets('toggleLocale callback is accessible', (tester) async {
      var toggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: AppSettings(
            locale: 'en',
            themeMode: ThemeMode.light,
            toggleLocale: () => toggled = true,
            toggleTheme: () {},
            child: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: AppSettings.of(context).toggleLocale,
                  child: const Text('Toggle'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Toggle'));
      expect(toggled, isTrue);
    });

    test('updateShouldNotify returns true when locale changes', () {
      const old = AppSettings(
        locale: 'en',
        themeMode: ThemeMode.light,
        toggleLocale: _noop,
        toggleTheme: _noop,
        child: SizedBox(),
      );
      const newer = AppSettings(
        locale: 'ru',
        themeMode: ThemeMode.light,
        toggleLocale: _noop,
        toggleTheme: _noop,
        child: SizedBox(),
      );

      expect(newer.updateShouldNotify(old), isTrue);
    });

    test('updateShouldNotify returns true when themeMode changes', () {
      const old = AppSettings(
        locale: 'en',
        themeMode: ThemeMode.light,
        toggleLocale: _noop,
        toggleTheme: _noop,
        child: SizedBox(),
      );
      const newer = AppSettings(
        locale: 'en',
        themeMode: ThemeMode.dark,
        toggleLocale: _noop,
        toggleTheme: _noop,
        child: SizedBox(),
      );

      expect(newer.updateShouldNotify(old), isTrue);
    });

    test('updateShouldNotify returns false when nothing changes', () {
      const old = AppSettings(
        locale: 'en',
        themeMode: ThemeMode.light,
        toggleLocale: _noop,
        toggleTheme: _noop,
        child: SizedBox(),
      );
      const newer = AppSettings(
        locale: 'en',
        themeMode: ThemeMode.light,
        toggleLocale: _noop,
        toggleTheme: _noop,
        child: SizedBox(),
      );

      expect(newer.updateShouldNotify(old), isFalse);
    });
  });
}

void _noop() {}
