// Unit tests for lib/helper/page_limit.dart.
//
// The recent responsive-limit bug was in this file's arithmetic (missing
// rotation recompute + potentially wrong clamping on tablets), so it's
// the highest-value spot to cover. Tests use `computePageLimitForHeight`,
// the pure-function variant, so we don't need a widget tree or MediaQuery.
//
// If you're wondering why there are no widget tests for the search-focus
// fix: the affected screens call `http.post` and `SharedPreferences.getInstance`
// directly with no injection seam, so a widget test would either need a
// heavy fake infrastructure or would exercise the real network. Both were
// judged out of scope for a smoke-test file. The search-focus fix is
// verified via docs/manual_test_search_focus.md instead.

import 'package:ezbiz/helper/page_limit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computePageLimitForHeight — customer/shop cards', () {
    // Matches userdetail.dart's tuning: 104 px per card, 286 px overhead.
    const double cardHeight = 104;
    const double overhead = 286;

    test('tiny viewport clamps up to min (default 8)', () {
      // (400 - 286) / 104 = 1.09 → floor 1 → clamped up to 8
      expect(
        computePageLimitForHeight(
          400,
          cardHeight: cardHeight,
          overhead: overhead,
        ),
        8,
      );
    });

    test('typical phone portrait fits under min → still 8', () {
      // (800 - 286) / 104 = 4.94 → 4 → clamped up to 8
      expect(
        computePageLimitForHeight(
          800,
          cardHeight: cardHeight,
          overhead: overhead,
        ),
        8,
      );
    });

    test('tall phone: raw count equals min bound', () {
      // (1200 - 286) / 104 = 8.79 → 8 (no clamp needed)
      expect(
        computePageLimitForHeight(
          1200,
          cardHeight: cardHeight,
          overhead: overhead,
        ),
        8,
      );
    });

    test('tablet portrait grows past the min', () {
      // (1366 - 286) / 104 = 10.38 → 10
      expect(
        computePageLimitForHeight(
          1366,
          cardHeight: cardHeight,
          overhead: overhead,
        ),
        10,
      );
    });

    test('tablet landscape (2000px tall viewport) grows further', () {
      // (2000 - 286) / 104 = 16.48 → 16
      expect(
        computePageLimitForHeight(
          2000,
          cardHeight: cardHeight,
          overhead: overhead,
        ),
        16,
      );
    });

    test('very tall viewport clamps down to max (default 25)', () {
      // (5000 - 286) / 104 = 45.32 → 45 → clamped down to 25
      expect(
        computePageLimitForHeight(
          5000,
          cardHeight: cardHeight,
          overhead: overhead,
        ),
        25,
      );
    });

    test(
      'rotation: portrait → landscape strictly increases the limit '
      '(this was the audit-flagged rotation-recompute case)',
      () {
        final portrait = computePageLimitForHeight(
          1200,
          cardHeight: cardHeight,
          overhead: overhead,
        );
        final landscape = computePageLimitForHeight(
          1900,
          cardHeight: cardHeight,
          overhead: overhead,
        );
        expect(landscape, greaterThan(portrait));
      },
    );
  });

  group('computePageLimitForHeight — order_history tuning', () {
    // order_history.dart uses different bounds: cardHeight 135, overhead 240,
    // min 5, max 20. Verifying those overrides work end-to-end.
    const double cardHeight = 135;
    const double overhead = 240;

    test('tiny viewport clamps to the override min (5)', () {
      // (400 - 240) / 135 = 1.18 → 1 → clamped up to 5
      expect(
        computePageLimitForHeight(
          400,
          cardHeight: cardHeight,
          overhead: overhead,
          min: 5,
          max: 20,
        ),
        5,
      );
    });

    test('huge viewport clamps to the override max (20)', () {
      // (5000 - 240) / 135 = 35.25 → 35 → clamped down to 20
      expect(
        computePageLimitForHeight(
          5000,
          cardHeight: cardHeight,
          overhead: overhead,
          min: 5,
          max: 20,
        ),
        20,
      );
    });

    test('mid-range tablet lands between the bounds', () {
      // (1366 - 240) / 135 = 8.34 → 8 (no clamp)
      expect(
        computePageLimitForHeight(
          1366,
          cardHeight: cardHeight,
          overhead: overhead,
          min: 5,
          max: 20,
        ),
        8,
      );
    });
  });

  group('computePageLimitForHeight — edge cases', () {
    test('overhead greater than viewport → clamped to min, not negative', () {
      // (200 - 400) / 100 = -2 → clamped up to 8
      expect(
        computePageLimitForHeight(
          200,
          cardHeight: 100,
          overhead: 400,
        ),
        8,
      );
    });

    test('non-integer division floors before clamp', () {
      // (900 - 100) / 100 = 8.0 → 8 exactly
      expect(
        computePageLimitForHeight(
          900,
          cardHeight: 100,
          overhead: 100,
        ),
        8,
      );
      // (899 - 100) / 100 = 7.99 → floor 7 → clamped up to 8 (default min)
      expect(
        computePageLimitForHeight(
          899,
          cardHeight: 100,
          overhead: 100,
        ),
        8,
      );
    });
  });
}
