import 'package:flutter/widgets.dart';

/// Computes how many list items to request per page so the initial
/// load fills the visible list area on any screen size.
///
/// [cardHeight]  estimated height of one card + its bottom margin (logical px).
/// [overhead]    height consumed by non-list chrome: AppBar, headers, search
///               bars, filter chips, footers, SafeArea insets, etc. (logical px).
/// [min] / [max] bounds to avoid absurdly small or large requests.
///
/// Assumptions are documented at each call site so they're easy to tune.
int computePageLimit(
  BuildContext context, {
  required double cardHeight,
  required double overhead,
  int min = 8,
  int max = 25,
}) {
  return computePageLimitForHeight(
    MediaQuery.of(context).size.height,
    cardHeight: cardHeight,
    overhead: overhead,
    min: min,
    max: max,
  );
}

/// Pure-function variant used by [computePageLimit] and by unit tests.
/// Kept separate so the arithmetic can be exercised without needing a
/// `BuildContext` / widget tree.
int computePageLimitForHeight(
  double viewportHeight, {
  required double cardHeight,
  required double overhead,
  int min = 8,
  int max = 25,
}) {
  final count = ((viewportHeight - overhead) / cardHeight).floor();
  return count.clamp(min, max);
}
