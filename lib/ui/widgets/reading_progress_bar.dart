import 'package:flutter/material.dart';

/// Reading progress bar shown at the bottom of the reader screen.
/// Thin and unobtrusive, similar to Kindle's progress indicator.
class ReadingProgressBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;

  const ReadingProgressBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
  });

  double get _progress => totalPages > 0 ? currentPage / totalPages : 0.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 3,
      width: double.infinity,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: _progress.clamp(0.0, 1.0),
        child: Container(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
