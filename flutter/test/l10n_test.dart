import 'package:flutter_test/flutter_test.dart';
import 'package:mini_booking/l10n.dart';

void main() {
  group('formatDateRange', () {
    test('same month and year', () {
      expect(
        formatDateRange('2026-02-06', '2026-02-11', 'ru'),
        '06 - 11 февраля 2026',
      );
      expect(
        formatDateRange('2026-02-06', '2026-02-11', 'en'),
        '06 - 11 February 2026',
      );
    });

    test('same year, different months', () {
      expect(
        formatDateRange('2026-02-06', '2026-03-13', 'ru'),
        '06 февраля - 13 марта 2026',
      );
      expect(
        formatDateRange('2026-02-06', '2026-03-13', 'en'),
        '06 February - 13 March 2026',
      );
    });

    test('different years', () {
      expect(
        formatDateRange('2025-12-12', '2026-01-08', 'ru'),
        '12 декабря 2025 - 08 января 2026',
      );
      expect(
        formatDateRange('2025-12-12', '2026-01-08', 'en'),
        '12 December 2025 - 08 January 2026',
      );
    });

    test('single day range', () {
      expect(
        formatDateRange('2026-06-15', '2026-06-16', 'en'),
        '15 - 16 June 2026',
      );
    });

    test('pads single-digit days', () {
      expect(
        formatDateRange('2026-01-03', '2026-01-09', 'en'),
        '03 - 09 January 2026',
      );
    });
  });
}
