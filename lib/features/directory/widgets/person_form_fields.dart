import 'package:attendly/core/responsive/responsive.dart';
import 'package:attendly/data/tables/enums/gender.dart';
import 'package:attendly/l10n/app_localizations.dart';
import 'package:attendly/shared/options/gender_option.dart';
import 'package:attendly/shared/options/migration_option.dart';
import 'package:attendly/shared/widgets/choice_chip_group.dart';
import 'package:flutter/material.dart';

/// Name, birthday, gender, migration and home country fields of the person
/// form. The page owns the controllers and the selected values.
class PersonFormFields extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController birthdayController;
  final TextEditingController homeCountryController;
  final Gender? gender;
  final bool? migration;
  final ValueChanged<Gender?> onGenderChanged;
  final ValueChanged<bool?> onMigrationChanged;
  final VoidCallback onPickBirthday;

  /// Focus of the name field, so the page can jump to a name problem.
  final FocusNode? nameFocusNode;

  /// Warning under the name field, e.g. when the name already exists.
  final String? nameError;

  const PersonFormFields({
    super.key,
    required this.nameController,
    required this.birthdayController,
    required this.homeCountryController,
    required this.gender,
    required this.migration,
    required this.onGenderChanged,
    required this.onMigrationChanged,
    required this.onPickBirthday,
    this.nameFocusNode,
    this.nameError,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final responsive = Responsive.of(context);
    final iconSize = responsive.iconSize();
    final bodySize = responsive.bodyFontSize;
    final primary = Theme.of(context).colorScheme.primary;
    final gap = SizedBox(height: responsive.contentPadding.vertical + 4);
    final labelGap = const SizedBox(height: 8);

    final labelStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: bodySize);
    final border = OutlineInputBorder(borderRadius: responsive.cardBorderRadius);

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(text, style: labelStyle),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label(localizations.childsName),
        labelGap,
        SizedBox(
          width: double.infinity,
          child: TextField(
            controller: nameController,
            focusNode: nameFocusNode,
            style: TextStyle(fontSize: bodySize),
            decoration: InputDecoration(
              hintText: localizations.enterChildsName,
              hintStyle: TextStyle(fontSize: bodySize),
              contentPadding: responsive.contentPadding,
              prefixIcon: Icon(Icons.person_outline, size: iconSize, color: primary),
              suffixIcon: IconButton(
                icon: Icon(Icons.clear, size: iconSize),
                onPressed: () => nameController.clear(),
              ),
              border: border,
              error: nameError == null ? null : _NameWarning(nameError!, fontSize: bodySize - 2),
            ),
          ),
        ),
        gap,

        label(localizations.childsBirthday),
        labelGap,
        SizedBox(
          width: double.infinity,
          child: TextField(
            controller: birthdayController,
            readOnly: true,
            onTap: onPickBirthday,
            style: TextStyle(fontSize: bodySize),
            decoration: InputDecoration(
              hintText: localizations.selectBirthday,
              hintStyle: TextStyle(fontSize: bodySize),
              contentPadding: responsive.contentPadding,
              prefixIcon: Icon(Icons.cake_outlined, size: iconSize, color: primary),
              suffixIcon: Icon(Icons.edit_calendar_outlined, size: iconSize),
              border: border,
            ),
          ),
        ),
        gap,

        label(localizations.selectGender),
        labelGap,
        ChoiceChipGroup<Gender>(
          choices: [
            for (final option in getGenderOptions(context))
              (value: option.value, label: option.label, icon: option.icon),
          ],
          selected: gender,
          onChanged: onGenderChanged,
        ),
        gap,

        label(localizations.selectMigration),
        labelGap,
        ChoiceChipGroup<bool>(
          choices: [
            for (final option in getMigrationOptions(context))
              (value: option.value, label: option.label, icon: option.icon),
          ],
          selected: migration,
          onChanged: (value) {
            if (value == false) homeCountryController.clear();
            onMigrationChanged(value);
          },
        ),

        // The home country only matters with a migration background.
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: migration != true
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    gap,
                    label(localizations.homeCountry),
                    labelGap,
                    SizedBox(
                      width: double.infinity,
                      child: TextField(
                        controller: homeCountryController,
                        style: TextStyle(fontSize: bodySize),
                        decoration: InputDecoration(
                          hintText: localizations.enterChildsHomeCountry,
                          hintStyle: TextStyle(fontSize: bodySize),
                          contentPadding: responsive.contentPadding,
                          prefixIcon: Icon(Icons.public, size: iconSize, color: primary),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.clear, size: iconSize),
                            onPressed: () => homeCountryController.clear(),
                          ),
                          border: border,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// A duplicate name is a normal mistake, so it is shown as a warning under
/// the field instead of an error dialog.
class _NameWarning extends StatelessWidget {
  final String message;
  final double fontSize;

  const _NameWarning(this.message, {required this.fontSize});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber_rounded, size: fontSize + 2, color: color),
        const SizedBox(width: 6),
        Expanded(child: Text(message, style: TextStyle(fontSize: fontSize, color: color))),
      ],
    );
  }
}
