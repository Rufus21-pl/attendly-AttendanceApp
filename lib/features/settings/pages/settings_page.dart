import 'package:attendly/shared/dialogs/app_dialogs.dart';
import 'package:attendly/features/settings/pages/help_page.dart';
import 'package:attendly/features/settings/providers/settings_notifier.dart';
import 'package:attendly/features/settings/widgets/changelog_dialog.dart';
import 'package:attendly/data/database/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:attendly/l10n/app_localizations.dart';
import 'package:attendly/features/settings/pages/debug_menu_page.dart';
import 'package:attendly/core/responsive/responsive.dart';

class SettingsPage extends ConsumerWidget  {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final responsive = Responsive.of(context);
    final iconSize = responsive.iconSize();
    final settings = ref.watch(settingsProvider);
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            localizations.settings,
            style: TextStyle(
              fontSize: responsive.titleFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, size: iconSize),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            responsive.contentPadding.left,
            responsive.listPadding.vertical,
            responsive.contentPadding.right,
            responsive.contentPadding.bottom + MediaQuery.of(context).padding.bottom,
          ),
          children: [
            _SectionTitle(localizations.appearanceSection, isFirst: true),
            _SettingsCard(
              children: [
                _SettingsTile(
                  title: localizations.darkMode,
                  subtitle: localizations.enableDisableDarkTheme,
                  icon: Icons.dark_mode_outlined,
                  trailing: Switch(
                    value: settings.themeMode == ThemeMode.dark,
                    onChanged: (bool value) {
                      ref.read(settingsProvider.notifier).updateTheme(value ? ThemeMode.dark : ThemeMode.light);
                      AppDialogs.showSnack(
                        context,
                        value ? localizations.darkModeOn : localizations.darkModeOff,
                        icon: value ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                      );
                    },
                  ),
                ),
                _SettingsTile(
                  title: localizations.language,
                  subtitle: localizations.selectApplicationLanguage,
                  icon: Icons.language_outlined,
                  below: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'en',
                          label: Text(localizations.english, style: TextStyle(fontSize: responsive.bodyFontSize - 2)),
                        ),
                        ButtonSegment(
                          value: 'de',
                          label: Text(localizations.german, style: TextStyle(fontSize: responsive.bodyFontSize - 2)),
                        ),
                      ],
                      selected: {settings.locale.languageCode == 'de' ? 'de' : 'en'},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) {
                        final languageCode = selection.first;
                        final newValue = languageCode == 'de' ? localizations.german : localizations.english;
                        ref.read(settingsProvider.notifier).updateLocale(Locale(languageCode));

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          final newLoc = AppLocalizations.of(context);
                          AppDialogs.showSnack(
                            context,
                            '${newLoc.languageSetTo} $newValue. ${newLoc.appRestartRequired}',
                            icon: Icons.translate,
                            duration: const Duration(seconds: 3),
                          );
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),

            _SectionTitle(localizations.dataSection),
            _SettingsCard(
              children: [
                _SettingsTile(
                  title: localizations.recalibrateData,
                  subtitle: localizations.recalibrateDataDesc,
                  icon: Icons.calculate_outlined,
                  trailing: Icon(Icons.chevron_right, size: iconSize),
                  onTap: () => _showRecalibrationDialog(context, ref),
                ),
                _SettingsTile(
                  title: localizations.help,
                  subtitle: localizations.openUserManual,
                  icon: Icons.help_outline,
                  trailing: Icon(Icons.chevron_right, size: iconSize),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        HelpPage(),
                  )),
                ),
              ],
            ),

            _SectionTitle(localizations.aboutSection),
            _SettingsCard(
              children: [
                Padding(
                  padding: responsive.contentPadding,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              localizations.debugInformation,
                              style: TextStyle(
                                fontSize: responsive.bodyFontSize,
                                fontWeight: FontWeight.bold,
                                color: muted,
                              ),
                            ),
                          ),
                          // Long press opens the hidden debug menu.
                          GestureDetector(
                            onLongPress: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const DebugMenuPage()),
                            ),
                            child: Icon(
                              Icons.info_outline,
                              color: muted,
                              size: iconSize,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: responsive.listPadding.vertical * 2),
                      FutureBuilder<PackageInfo>(
                        future: PackageInfo.fromPlatform(),
                        builder: (context, snapshot) {
                          final version =
                              snapshot.hasData ? snapshot.data!.version : '...';
                          return InkWell(
                            onTap: () => ChangelogDialog.showDirectly(context),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                              child: Text(
                                localizations.getAppsVerision(version),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: responsive.bodyFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: muted,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const _SchemaVersionText(),
                    ],
                  ),
                ),
              ],
            ),

            // _buildSettingsListTile(
            //   context: context,
            //   title: "Test 2025 Migration",
            //   subtitle: "Verify db_2025.db conversion logic",
            //   icon: Icons.auto_fix_high_outlined,
            //   trailing: Icon(Icons.play_arrow, color: Colors.green, size: Responsive.of(context).iconSize()),
            //   onTap: _runMigrationTest,
            // ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRecalibrationDialog(
      BuildContext context, WidgetRef ref) async {
    final localizations = AppLocalizations.of(context);
    final dbState = ref.read(databaseProvider);               // CHANGED
 
    if (!dbState.isReady) {
      AppDialogs.showError(context, localizations.databaseNotConnected);
      return;
    }
 
    final db = dbState.manager!.databaseConnection;
 
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(localizations.confirmAction,
            style: TextStyle(
                fontSize: Responsive.of(context).titleFontSize,
                fontWeight: FontWeight.bold)),
        content: Text(localizations.recalibrateConfirm,
            style: TextStyle(fontSize: Responsive.of(context).bodyFontSize)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(localizations.cancel,
                style: TextStyle(
                    fontSize: Responsive.of(context).bodyFontSize - 4)),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(localizations.proceed,
                style: TextStyle(
                    fontSize: Responsive.of(context).bodyFontSize - 4)),
          ),
        ],
      ),
    );
 
    if (confirmed == true) {
      AppDialogs.showLoading(context, localizations.recalibrating);
      try {
        await db.updateDao.recalibrateWeeklyData();
        AppDialogs.hideLoading(context);
        await AppDialogs.showSuccess(
            context, localizations.recalibrationSuccess);
      } catch (e, stackTrace) {
        AppDialogs.hideLoading(context);
        AppDialogs.showError(context, localizations.recalibrationFailed,
            stackTrace: stackTrace);
      }
    }
  }
}

/// Small coloured heading above a group of settings.
class _SectionTitle extends StatelessWidget {
  final String text;

  /// The first heading sits close to the app bar.
  final bool isFirst;

  const _SectionTitle(this.text, {this.isFirst = false});

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(8, isFirst ? 0 : responsive.listPadding.vertical * 4, 8, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: responsive.smallFontSize + 1,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// Rounded card around a group of settings, with dividers between them.
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: responsive.cardBorderRadius,
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A setting: icon in a tinted square, title and description, and either a
/// [trailing] control or a full-width control [below] the text.
class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;
  final Widget? below;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
    this.below,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: responsive.contentPadding,
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(responsive.isTablet ? 10 : 8),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: responsive.iconSize(baseSize: 22), color: scheme.primary),
                ),
                SizedBox(width: responsive.isTablet ? 16 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(fontSize: responsive.bodyFontSize, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: responsive.bodyFontSize - 3,
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ],
              ],
            ),
            if (below != null) ...[
              SizedBox(height: responsive.listPadding.vertical * 3),
              below!,
            ],
          ],
        ),
      ),
    );
  }
}


/// The schema version of the open database, below the app version.
class _SchemaVersionText extends ConsumerWidget {
  const _SchemaVersionText();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(databaseSchemaVersionProvider).valueOrNull;
    if (version == null) return const SizedBox.shrink();

    return Text(
      AppLocalizations.of(context).databaseSchemaVersion(version),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: Responsive.of(context).bodyFontSize - 4,
        color: Colors.grey,
      ),
    );
  }
}
