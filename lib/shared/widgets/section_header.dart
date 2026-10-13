import 'package:attendly/core/responsive/responsive.dart';
import 'package:flutter/material.dart';

/// Header of a report card: the icon in a tinted circle, the title and an
/// optional trailing widget (e.g. a chart button).
class SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(responsive.isTablet ? 10 : 8),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: scheme.primary, size: responsive.iconSize(baseSize: 22)),
        ),
        SizedBox(width: responsive.isTablet ? 16 : 12),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: responsive.titleFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
