import 'package:attendly/core/responsive/responsive.dart';
import 'package:flutter/material.dart';

/// Centered placeholder for an empty list or report: a muted icon above the
/// message.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const EmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);

    return Center(
      child: Padding(
        padding: responsive.contentPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: responsive.iconSize(baseSize: 64), color: muted),
            SizedBox(height: responsive.isTablet ? 16 : 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: responsive.bodyFontSize, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
