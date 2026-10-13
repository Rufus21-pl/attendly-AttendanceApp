import 'package:attendly/core/responsive/responsive.dart';
import 'package:flutter/material.dart';
import 'package:attendly/l10n/app_localizations.dart';

/// Reset and submit buttons at the end of a form. Side by side when there is
/// room; stacked at full width on narrow phones, where a long label such as
/// "Zurücksetzen" would otherwise wrap. Without [onReset] the submit button
/// takes the full width.
class FormActions extends StatelessWidget {
  /// Below this width the buttons are stacked.
  static const double _sideBySideMinWidth = 480;

  final VoidCallback? onReset;
  final VoidCallback onSubmit;
  final String submitLabel;
  final IconData submitIcon;

  const FormActions({
    super.key,
    required this.onReset,
    required this.onSubmit,
    required this.submitLabel,
    this.submitIcon = Icons.check,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textStyle = TextStyle(fontSize: responsive.bodyFontSize, fontWeight: FontWeight.w600);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(32));
    final minimumSize = Size(0, responsive.buttonHeight + 4);

    // One line only: if a label is still too long it shrinks a little
    // instead of breaking into several lines.
    Widget label(String text) => FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(text, style: textStyle, maxLines: 1, softWrap: false),
        );

    final submit = ElevatedButton.icon(
      onPressed: onSubmit,
      icon: Icon(submitIcon, size: responsive.iconSize(), color: Colors.white),
      label: label(submitLabel),
      style: ElevatedButton.styleFrom(shape: shape, minimumSize: minimumSize),
    );

    if (onReset == null) return submit;

    final reset = OutlinedButton.icon(
      onPressed: onReset,
      icon: Icon(Icons.refresh, size: responsive.iconSize()),
      label: label(AppLocalizations.of(context).reset),
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.primary),
        shape: shape,
        minimumSize: minimumSize,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _sideBySideMinWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              reset,
              SizedBox(height: responsive.isTablet ? 16 : 12),
              submit,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: reset),
            SizedBox(width: responsive.isTablet ? 16 : 12),
            Expanded(child: submit),
          ],
        );
      },
    );
  }
}
