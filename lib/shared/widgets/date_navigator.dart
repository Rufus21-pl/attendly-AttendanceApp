import 'package:attendly/core/responsive/responsive.dart';
import 'package:flutter/material.dart';

/// Arrows around a tappable date label that opens a date picker. The label
/// sits in a tinted pill with a calendar icon so it reads as a button.
class DateNavigator extends StatelessWidget {
  final String label;

  /// Optional smaller line above [label], e.g. the weekday.
  final String? subtitle;
  final VoidCallback onPrevious;

  /// Null disables the forward arrow.
  final VoidCallback? onNext;
  final VoidCallback onPick;

  const DateNavigator({
    super.key,
    required this.label,
    this.subtitle,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final scheme = Theme.of(context).colorScheme;
    final arrowSize = responsive.iconSize(baseSize: 30);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.listPadding.horizontal,
        vertical: responsive.listPadding.vertical * 2,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.arrow_back_ios_sharp),
            iconSize: arrowSize,
          ),
          Expanded(
            child: Center(
              child: Material(
                color: scheme.primary.withValues(alpha: 0.1),
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onPick,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: responsive.isTablet ? 24 : 16,
                      vertical: responsive.isTablet ? 10 : 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_month_outlined,
                          color: scheme.primary,
                          size: responsive.iconSize(baseSize: 22),
                        ),
                        SizedBox(width: responsive.isTablet ? 12 : 8),
                        // Long week ranges shrink instead of wrapping on
                        // narrow phones.
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (subtitle != null)
                                  Text(
                                    subtitle!,
                                    style: TextStyle(
                                      fontSize: responsive.smallFontSize,
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: responsive.titleFontSize,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.arrow_forward_ios_sharp),
            iconSize: arrowSize,
          ),
        ],
      ),
    );
  }
}
