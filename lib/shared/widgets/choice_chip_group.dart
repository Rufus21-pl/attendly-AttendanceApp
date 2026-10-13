import 'package:attendly/core/responsive/responsive.dart';
import 'package:flutter/material.dart';

/// One choice of a [ChoiceChipGroup].
typedef ChipChoice<T> = ({T value, String label, IconData? icon});

/// Single choice between a few options as tappable chips. Tapping the
/// selected chip again clears the choice (reports null), like the clear
/// button of the dropdowns these chips replace.
class ChoiceChipGroup<T> extends StatelessWidget {
  final List<ChipChoice<T>> choices;
  final T? selected;
  final ValueChanged<T?> onChanged;

  const ChoiceChipGroup({
    super.key,
    required this.choices,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fontSize = responsive.bodyFontSize - (responsive.isTablet ? 2 : 1);

    return Wrap(
      spacing: responsive.isTablet ? 12 : 8,
      runSpacing: responsive.isTablet ? 12 : 8,
      children: [
        for (final choice in choices)
          Builder(builder: (context) {
            final isSelected = choice.value == selected;
            return ChoiceChip(
              avatar: choice.icon == null
                  ? null
                  : Icon(
                      choice.icon,
                      size: responsive.iconSize(baseSize: 20),
                      color: isSelected ? scheme.primary : null,
                    ),
              label: Text(choice.label, style: TextStyle(fontSize: fontSize)),
              labelPadding: EdgeInsets.symmetric(horizontal: responsive.isTablet ? 8 : 4),
              padding: EdgeInsets.symmetric(
                horizontal: responsive.isTablet ? 12 : 8,
                vertical: responsive.isTablet ? 10 : 6,
              ),
              selected: isSelected,
              showCheckmark: false,
              selectedColor: scheme.primary.withValues(alpha: 0.18),
              side: BorderSide(
                color: isSelected ? scheme.primary : theme.dividerColor,
                width: isSelected ? 1.5 : 1,
              ),
              shape: const StadiumBorder(),
              onSelected: (value) => onChanged(value ? choice.value : null),
            );
          }),
      ],
    );
  }
}
