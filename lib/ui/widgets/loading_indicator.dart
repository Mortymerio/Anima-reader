import 'package:flutter/material.dart';
import '../../constants/strings.dart';

/// E-ink friendly loading indicator.
///
/// Uses static text instead of animated CircularProgressIndicator to
/// avoid ghosting artifacts on E-ink displays. Optionally shows
/// download progress with MB count.
class LoadingIndicator extends StatelessWidget {
  final String? message;
  final int? bytesReceived;
  final int? totalBytes;

  const LoadingIndicator({
    super.key,
    this.message,
    this.bytesReceived,
    this.totalBytes,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Static icon instead of animated spinner
            Icon(
              Icons.auto_stories,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              message ?? S.loadingBook,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            if (bytesReceived != null && totalBytes != null && totalBytes! > 0) ...[
              const SizedBox(height: 12),
              // Static progress bar (no animation)
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  value: bytesReceived! / totalBytes!,
                  backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onSurface),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(bytesReceived! / (1024 * 1024)).toStringAsFixed(1)} / '
                '${(totalBytes! / (1024 * 1024)).toStringAsFixed(1)} ${S.downloadProgress}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
