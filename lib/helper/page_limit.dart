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
  final h = MediaQuery.of(context).size.height;
  final count = ((h - overhead) / cardHeight).floor();
  return count.clamp(min, max);
}
