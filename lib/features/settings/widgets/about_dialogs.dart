import 'package:attendly/core/app_info/app_info.dart';
import 'package:attendly/core/logging/app_logger.dart';
import 'package:attendly/core/responsive/responsive.dart';
import 'package:attendly/l10n/app_localizations.dart';
import 'package:attendly/shared/dialogs/app_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Dialogs behind the author and license entries in Settings > About.
class AboutDialogs {
  AboutDialogs._();

  /// Shows the LICENSE file of the app.
  static Future<void> showLicense(BuildContext context) async {
    final localizations = AppLocalizations.of(context);

    String text;
    try {
      text = _reflow(await rootBundle.loadString(AppInfo.licenseAsset));
    } catch (e, stackTrace) {
      AppLogger.e('Settings', 'Could not load the license text', e, stackTrace);
      text = localizations.licenseLoadFailed;
    }
    if (!context.mounted) return;

    final responsive = Responsive.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          localizations.licenseTitle,
          style: TextStyle(fontSize: responsive.titleFontSize, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: SelectableText(
              text,
              style: TextStyle(fontSize: responsive.bodyFontSize - 3, height: 1.4),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(localizations.close),
          ),
        ],
      ),
    );
  }

  /// Shows the licenses of Flutter and of the packages the app uses.
  static Future<void> showOpenSourceLicenses(BuildContext context) async {
    String? version;
    try {
      version = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      // The page works without the version.
    }
    if (!context.mounted) return;

    showLicensePage(
      context: context,
      applicationName: AppInfo.appName,
      applicationVersion: version,
      applicationLegalese: AppInfo.copyrightNotice,
    );
  }

  /// Shows where to ask the author for permission or a purchase.
  static Future<void> showContact(BuildContext context) async {
    final localizations = AppLocalizations.of(context);
    final responsive = Responsive.of(context);

    final copied = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          localizations.contactAuthor,
          style: TextStyle(fontSize: responsive.titleFontSize, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.contactAuthorDesc,
              style: TextStyle(fontSize: responsive.bodyFontSize - 2),
            ),
            const SizedBox(height: 12),
            SelectableText(
              AppInfo.repositoryUrl,
              style: TextStyle(
                fontSize: responsive.bodyFontSize - 2,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations.close),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(const ClipboardData(text: AppInfo.repositoryUrl));
              if (context.mounted) Navigator.of(context).pop(true);
            },
            child: Text(localizations.copyToClipboard),
          ),
        ],
      ),
    );

    if (copied == true && context.mounted) {
      AppDialogs.showSnack(context, localizations.linkCopiedToClipboard, icon: Icons.link);
    }
  }

  /// The LICENSE file has fixed line breaks for an 80-column editor. This joins
  /// the lines of each paragraph so the text wraps to the dialog width. A list
  /// item such as "a) ..." stays on its own line.
  static String _reflow(String raw) {
    final listItem = RegExp(r'^[a-z]\) ');
    final paragraphs = raw.replaceAll('\r\n', '\n').trim().split(RegExp(r'\n\s*\n'));

    return paragraphs.map((paragraph) {
      final buffer = StringBuffer();
      for (final line in paragraph.split('\n').map((line) => line.trim())) {
        if (line.isEmpty) continue;
        if (buffer.isNotEmpty) buffer.write(listItem.hasMatch(line) ? '\n' : ' ');
        buffer.write(line);
      }
      return buffer.toString();
    }).join('\n\n');
  }
}
