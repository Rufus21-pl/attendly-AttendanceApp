import 'package:attendly/core/responsive/responsive.dart';
import 'package:attendly/data/tables/enums/category.dart';
import 'package:attendly/l10n/app_localizations.dart';
import 'package:attendly/shared/options/category_option.dart';
import 'package:attendly/shared/widgets/choice_chip_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bold label above a form field.
class FieldLabel extends StatelessWidget {
  final String text;

  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: Responsive.of(context).bodyFontSize,
        ),
      ),
    );
  }
}

/// Card that shows the selected people and opens the person picker.
class PersonSelectionCard extends StatelessWidget {
  final List<String> names;

  /// Null when the people were preselected and cannot be changed.
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  const PersonSelectionCard({
    super.key,
    required this.names,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final responsive = Responsive.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isEmpty = names.isEmpty;
    final muted = scheme.onSurface.withValues(alpha: 0.6);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: isEmpty ? null : scheme.primary.withValues(alpha: 0.06),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: responsive.cardBorderRadius,
        side: BorderSide(
          color: isEmpty ? theme.dividerColor : scheme.primary.withValues(alpha: 0.5),
          width: isEmpty ? 1 : 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: responsive.contentPadding,
          child: Row(
            children: [
              CircleAvatar(
                radius: responsive.isTablet ? 28 : 22,
                backgroundColor: scheme.primary.withValues(alpha: isEmpty ? 0.08 : 0.15),
                child: Icon(
                  isEmpty ? Icons.person_add_alt_1_outlined : Icons.group,
                  size: responsive.iconSize(baseSize: 24),
                  color: scheme.primary,
                ),
              ),
              SizedBox(width: responsive.contentPadding.horizontal / 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEmpty
                        ? localizations.tapToSelectPersons
                        : localizations.personsSelected(names.length),
                      style: TextStyle(
                        fontSize: responsive.bodyFontSize,
                        fontWeight: FontWeight.bold,
                        color: isEmpty ? muted : null,
                      ),
                    ),
                    if (!isEmpty) ...[
                      SizedBox(height: responsive.listPadding.vertical / 2),
                      Text(
                        names.join(', '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: responsive.bodyFontSize - 2, color: muted),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isEmpty && onClear != null)
                IconButton(
                  onPressed: onClear,
                  icon: Icon(Icons.close, color: scheme.error, size: responsive.iconSize()),
                )
              else if (onTap != null)
                Icon(Icons.chevron_right, color: muted, size: responsive.iconSize()),
            ],
          ),
        ),
      ),
    );
  }
}

/// The categories as chips; tapping the selected one again clears it.
class CategoryChips extends StatelessWidget {
  final Category? selected;
  final ValueChanged<Category?> onChanged;

  const CategoryChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChipGroup<Category>(
      choices: [
        for (final option in getCategoryOptions(context))
          (value: option.category, label: option.label, icon: option.icon),
      ],
      selected: selected,
      onChanged: onChanged,
    );
  }
}

/// "Number of entries" stepper for the categories that can be counted
/// several times at once.
class MultiplierInput extends StatelessWidget {
  final TextEditingController controller;
  final int value;
  final ValueChanged<int> onChanged;

  const MultiplierInput({
    super.key,
    required this.controller,
    required this.value,
    required this.onChanged,
  });

  /// The buttons also update the text; typing only reports the number, so
  /// the cursor stays where it is.
  void _step(int delta) {
    controller.text = (value + delta).toString();
    onChanged(value + delta);
  }

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final scheme = Theme.of(context).colorScheme;
    final iconSize = responsive.iconSize();

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.06),
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Row(
            children: [
              IconButton.filledTonal(
                icon: Icon(Icons.remove, size: iconSize),
                onPressed: value > 1 ? () => _step(-1) : null,
              ),
              SizedBox(
                width: responsive.isTablet ? 80 : 60,
                child: TextField(
                  controller: controller,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                    fontSize: responsive.bodyFontSize + 2,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (text) {
                    final newValue = int.tryParse(text);
                    if (newValue != null) onChanged(newValue);
                  },
                ),
              ),
              IconButton.filledTonal(
                icon: Icon(Icons.add, size: iconSize),
                onPressed: () => _step(1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
