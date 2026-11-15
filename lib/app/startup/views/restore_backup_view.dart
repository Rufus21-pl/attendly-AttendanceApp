import 'package:attendly/app/startup/app_startup_notifier.dart';
import 'package:attendly/app/startup/startup_state.dart';
import 'package:attendly/app/startup/views/startup_dialogs.dart';
import 'package:attendly/app/startup/views/status_scaffold.dart';
import 'package:attendly/core/logging/app_logger.dart';
import 'package:attendly/core/responsive/responsive.dart';
import 'package:attendly/data/backup/backup_info.dart';
import 'package:attendly/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// The main database is missing or damaged and a backup can replace it.
/// The user selects one of the backups and restores it.
class RestoreBackupView extends ConsumerStatefulWidget {
  final StartupRestoreAvailable restore;
  final bool isBusy;

  const RestoreBackupView({super.key, required this.restore, this.isBusy = false});

  /// How the time of a backup is shown, in the list and in the dialog.
  static String formatTime(DateTime time) => DateFormat('dd.MM.yyyy HH:mm').format(time);

  @override
  ConsumerState<RestoreBackupView> createState() => _RestoreBackupViewState();
}

class _RestoreBackupViewState extends ConsumerState<RestoreBackupView> {
  /// The newest backup is selected first.
  late BackupInfo _selected = widget.restore.backups.first;

  Future<void> _restore() async {
    final localizations = AppLocalizations.of(context);
    final backup = _selected;
    final confirmed = await StartupDialogs.confirmRestore(context, RestoreBackupView.formatTime(backup.modified));
    if (!(confirmed ?? false)) {
      AppLogger.i('Startup', 'User cancelled the restore');
      return;
    }
    try {
      await ref.read(appStartupProvider.notifier).restoreBackup(backup);
    } catch (_) {
      if (mounted) StartupDialogs.error(context, localizations.restoreFailed);
    }
  }

  Future<void> _createNew() async {
    final localizations = AppLocalizations.of(context);
    // On the first start no database exists that a new one could replace.
    if (widget.restore.reason != RestoreReason.noDatabase) {
      if (!(await StartupDialogs.confirmCreateNew(context) ?? false)) {
        AppLogger.i('Startup', 'User cancelled creating a new database');
        return;
      }
    }
    try {
      await ref.read(appStartupProvider.notifier).createDatabase();
    } catch (_) {
      if (mounted) StartupDialogs.error(context, localizations.failedToCreateNewDatabase);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isTablet = Responsive.of(context).isTablet;
    final reason = widget.restore.reason;
    final isBusy = widget.isBusy;
    final notifier = ref.read(appStartupProvider.notifier);

    final (title, message) = switch (reason) {
      RestoreReason.noDatabase => (localizations.restoreTitleNoDatabase, localizations.restoreMessageNoDatabase),
      RestoreReason.missing => (localizations.restoreTitleMissing, localizations.restoreMessageMissing),
      RestoreReason.unreadable => (localizations.restoreTitleUnreadable, localizations.restoreMessageUnreadable),
      RestoreReason.damaged => (localizations.restoreTitleDamaged, localizations.restoreMessageDamaged),
    };

    return StatusScaffold(
      icon: Icon(
        Icons.settings_backup_restore,
        size: isTablet ? 100 : 80,
        color: reason == RestoreReason.noDatabase ? Theme.of(context).primaryColor : Colors.orange,
      ),
      title: title,
      message: message,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          children: [
            for (final backup in widget.restore.backups)
              _BackupTile(
                backup: backup,
                selected: identical(backup, _selected),
                onTap: isBusy ? null : () => setState(() => _selected = backup),
              ),
          ],
        ),
      ),
      actions: [
        StartupActionButton(
          label: localizations.restoreBackup,
          icon: Icon(Icons.restore, color: Colors.white, size: isTablet ? 24 : 20),
          isBusy: isBusy,
          onPressed: _restore,
        ),
        // A file that cannot be read stays where the new database would be,
        // so "create new" is not offered for it.
        if (reason == RestoreReason.noDatabase || reason == RestoreReason.missing)
          TextButton.icon(
            onPressed: isBusy ? null : _createNew,
            icon: StartupActionButton.databaseIcon(context, color: Theme.of(context).colorScheme.primary),
            label: Text(
              reason == RestoreReason.noDatabase ? localizations.createDatabase : localizations.createNew,
              style: TextStyle(fontSize: isTablet ? 18 : 16),
            ),
          ),
        if (reason == RestoreReason.damaged)
          TextButton(
            onPressed: isBusy ? null : notifier.continueWithDamagedDatabase,
            child: Text(localizations.continueWithDatabase, style: TextStyle(fontSize: isTablet ? 18 : 16)),
          ),
        TextButton.icon(
          onPressed: () => StartupDialogs.logs(context, ref),
          icon: Icon(Icons.article_outlined, size: isTablet ? 24 : 20),
          label: Text(localizations.showLogs, style: TextStyle(fontSize: isTablet ? 18 : 16)),
        ),
      ],
    );
  }
}

/// One backup in the list: database file, kind, time and size.
class _BackupTile extends StatelessWidget {
  final BackupInfo backup;
  final bool selected;
  final VoidCallback? onTap;

  const _BackupTile({required this.backup, required this.selected, required this.onTap});

  static String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final responsive = Responsive.of(context);
    final scheme = Theme.of(context).colorScheme;
    final kind = switch (backup.kind) {
      BackupKind.latest => localizations.backupLatest,
      BackupKind.previousDay => localizations.backupPreviousDay,
    };

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      color: selected ? scheme.primary.withValues(alpha: 0.08) : null,
      shape: RoundedRectangleBorder(
        borderRadius: responsive.cardBorderRadius,
        side: BorderSide(
          color: selected ? scheme.primary : Theme.of(context).dividerColor,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: responsive.contentPadding,
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? scheme.primary : scheme.onSurface.withValues(alpha: 0.5),
                size: responsive.iconSize(),
              ),
              SizedBox(width: responsive.isTablet ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${backup.dbFileName} · $kind',
                      style: TextStyle(fontSize: responsive.bodyFontSize, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${RestoreBackupView.formatTime(backup.modified)} · ${_formatSize(backup.sizeBytes)}',
                      style: TextStyle(
                        fontSize: responsive.bodyFontSize - 3,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
