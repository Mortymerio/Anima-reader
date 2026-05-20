import 'package:flutter/material.dart';
import '../../constants/strings.dart';

/// Displayed when the user's library has no books.
class EmptyLibrary extends StatelessWidget {
  final VoidCallback onRefresh;

  const EmptyLibrary({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              S.emptyLibraryTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontFamily: 'Serif',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              S.emptyLibrarySubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text(S.emptyLibraryButton),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.colorScheme.onSurface, width: 1.5),
                foregroundColor: theme.colorScheme.onSurface,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
