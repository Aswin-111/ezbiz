import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:ezbiz/helper/page_limit.dart';

/// Adds automatic recomputation of a paginated screen's per-request
/// `limit` when the viewport metrics change (orientation change,
/// split-screen, foldable unfold, window resize on desktop/web).
///
/// The screen keeps its own `_limit` field and `_fetchPage` method. This
/// mixin only wires up the observer and the debounced recompute — it
/// calls back into the screen via [onPageLimitChanged] when the new
/// limit differs from the previous one, so the screen decides how to
/// re-fetch.
///
/// Usage — every state class using this mixin must:
///
/// 1. Add `with WidgetsBindingObserver, ResponsivePageSizeMixin<MyPage>`
///    (WidgetsBindingObserver must appear before this mixin so it can
///    override `didChangeMetrics`).
/// 2. Override [pageCardHeight] and [pageOverhead]. Optionally override
///    [pageLimitMin] / [pageLimitMax] if the defaults don't fit.
/// 3. Call [attachResponsivePageSize] in a post-frame callback in
///    [initState] (after storing the initial limit via
///    [computeInitialLimit]).
/// 4. Call [detachResponsivePageSize] in [dispose].
/// 5. Implement [onPageLimitChanged] to update `_limit` and re-fetch
///    page 1.
///
/// Example:
///
/// ```dart
/// class _StockPageState extends State<StockPage>
///     with WidgetsBindingObserver, ResponsivePageSizeMixin<StockPage> {
///   int _limit = 12;
///
///   @override double get pageCardHeight => 104;
///   @override double get pageOverhead => 216;
///
///   @override
///   void initState() {
///     super.initState();
///     WidgetsBinding.instance.addPostFrameCallback((_) {
///       if (!mounted) return;
///       _limit = computeInitialLimit();
///       attachResponsivePageSize();
///       _fetchPage(page: 1);
///     });
///   }
///
///   @override
///   void dispose() {
///     detachResponsivePageSize();
///     super.dispose();
///   }
///
///   @override
///   void onPageLimitChanged(int newLimit) {
///     if (!mounted) return;
///     setState(() => _limit = newLimit);
///     _fetchPage(page: 1);
///   }
/// }
/// ```
mixin ResponsivePageSizeMixin<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver {
  // Rotation and other metrics changes can fire `didChangeMetrics`
  // multiple times in quick succession (during the animated transition).
  // We debounce so the recompute runs once, after the layout settles.
  static const Duration _debounce = Duration(milliseconds: 350);

  Timer? _resizeDebounce;
  int? _lastComputedLimit;

  /// Estimated per-card height (logical px), including its bottom margin.
  double get pageCardHeight;

  /// Non-list chrome above/around the list (logical px): AppBar, headers,
  /// search bars, filter chips, totals bar, SafeArea insets.
  double get pageOverhead;

  int get pageLimitMin => 8;
  int get pageLimitMax => 25;

  /// Called after a debounced metrics change resolves to a limit
  /// different from the previous one. Implementations should update
  /// their `_limit` field and re-fetch page 1 so the list reflows.
  void onPageLimitChanged(int newLimit);

  /// Register the metrics observer. Call after [computeInitialLimit]
  /// so the very first [didChangeMetrics] tick doesn't fire a spurious
  /// re-fetch against a null baseline.
  void attachResponsivePageSize() {
    WidgetsBinding.instance.addObserver(this);
  }

  void detachResponsivePageSize() {
    WidgetsBinding.instance.removeObserver(this);
    _resizeDebounce?.cancel();
  }

  /// Read the initial limit for the current viewport. Call this once
  /// from a post-frame callback in [initState] (MediaQuery isn't safe
  /// during [initState] itself).
  int computeInitialLimit() {
    final v = computePageLimit(
      context,
      cardHeight: pageCardHeight,
      overhead: pageOverhead,
      min: pageLimitMin,
      max: pageLimitMax,
    );
    _lastComputedLimit = v;
    return v;
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _resizeDebounce?.cancel();
    _resizeDebounce = Timer(_debounce, _recompute);
  }

  void _recompute() {
    if (!mounted) return;
    // Skip until initial computation has run — otherwise we'd fire
    // spurious re-fetches during app cold-start metrics.
    if (_lastComputedLimit == null) return;

    final v = computePageLimit(
      context,
      cardHeight: pageCardHeight,
      overhead: pageOverhead,
      min: pageLimitMin,
      max: pageLimitMax,
    );
    if (v != _lastComputedLimit) {
      _lastComputedLimit = v;
      onPageLimitChanged(v);
    }
  }
}
