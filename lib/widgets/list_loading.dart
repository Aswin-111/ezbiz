import 'package:flutter/material.dart';

/// Lightweight inline spinner for list/results areas.
/// Deliberately small so it does not dominate the screen.
class ListLoading extends StatelessWidget {
  const ListLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(
          color: Color(0xFF6C63FF),
          strokeWidth: 2.5,
        ),
      ),
    );
  }
}

/// Compact bottom-of-list spinner used while fetching the next page.
class PageLoadingIndicator extends StatelessWidget {
  const PageLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            color: Color(0xFF6C63FF),
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
}
