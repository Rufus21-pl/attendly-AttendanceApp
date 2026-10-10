import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:attendly/l10n/app_de.dart';
import 'package:attendly/l10n/app_en.dart';
import 'package:attendly/l10n/app_localizations.dart';

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'de'].contains(locale.languageCode);

  /// Synchronous on purpose: with a real Future, Flutter keeps the old
  /// language for one more frame after the locale changes, and a dialog
  /// opened in that frame (the year-change question) stays in English.
  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(getLocalization(locale));
  }

  static AppLocalizations getLocalization(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return AppLocalizationsEn();
      case 'de':
        return AppLocalizationsDe();
      default:
        return AppLocalizationsEn();
    }
  }

  @override
  bool shouldReload(LocalizationsDelegate<AppLocalizations> old) => false;
}
