import 'package:attendly/core/responsive/responsive.dart';
import 'package:flutter/material.dart';

/// `builder` for [showDatePicker]: on a tablet the picker is drawn larger,
/// like the rest of the app. Phones get the default picker.
Widget tabletDatePickerBuilder(BuildContext context, Widget? child) {
  if (!Responsive.of(context).isTablet || child == null) return child ?? const SizedBox.shrink();

  final mq = MediaQuery.of(context);
  final newScale = (mq.textScaler.scale(1.0) * 1.2).clamp(1.0, 1.6);
  return MediaQuery(
    data: mq.copyWith(textScaler: TextScaler.linear(newScale)),
    child: Transform.scale(scale: 1.1, child: child),
  );
}
