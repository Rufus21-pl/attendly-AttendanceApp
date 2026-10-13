import 'dart:io';
import 'package:attendly/data/storage/storage_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:attendly/app/startup/app_startup_notifier.dart';
import 'package:flutter/material.dart';
import 'package:attendly/l10n/app_localizations.dart';
import 'package:attendly/core/responsive/responsive.dart';
import 'package:attendly/shared/widgets/empty_state.dart';

class DatabasePickerPage extends ConsumerStatefulWidget {
  // Add a field to hold the path of the currently active database.
  final String? currentDbPath;

  const DatabasePickerPage({
    super.key, 
    this.currentDbPath,
  });

  @override
  ConsumerState<DatabasePickerPage> createState() => _DatabasePickerPageState();
}

class _DatabasePickerPageState extends ConsumerState<DatabasePickerPage> {
  late final Future<List<File>> _dbFilesFuture;

  @override
  void initState() {
    super.initState();
    _dbFilesFuture = StorageManager.listDbFiles();
  }

  /// Handles the selection of a database file.
  /// The startup gate closes this page and shows progress or errors.
  void _onFileSelected(File selectedDb) {
    ref.read(appStartupProvider.notifier).openDatabaseFile(selectedDb);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isTablet = Responsive.of(context).isTablet;
    final iconSize = Responsive.of(context).iconSize();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.selectDatabase,
          style: TextStyle(
            fontSize: Responsive.of(context).titleFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: iconSize),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<File>>(
        future: _dbFilesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.error_outline,
              message: localizations.errorLoadingFiles(snapshot.error.toString()),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return EmptyState(
              icon: Icons.folder_off_outlined,
              message: localizations.noDbFilesFound,
            );
          }

          final files = snapshot.data!;
          final responsive = Responsive.of(context);
          final scheme = Theme.of(context).colorScheme;
          final muted = scheme.onSurface.withValues(alpha: 0.6);

          return ListView.builder(
            padding: EdgeInsets.symmetric(
              vertical: responsive.listPadding.vertical * 2,
              horizontal: responsive.listPadding.horizontal + 4,
            ),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              final fileName = p.basename(file.path);
              final bool isCurrentDb = file.path == widget.currentDbPath;

              return Card(
                elevation: isCurrentDb ? 0 : responsive.cardElevation,
                margin: EdgeInsets.symmetric(vertical: responsive.listPadding.vertical * 1.5),
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: responsive.cardBorderRadius,
                  side: isCurrentDb
                      ? BorderSide(color: Colors.green.shade600, width: isTablet ? 2 : 1.5)
                      : BorderSide.none,
                ),
                color: isCurrentDb ? Colors.green.withValues(alpha: 0.08) : null,
                child: InkWell(
                  onTap: isCurrentDb ? null : () => _onFileSelected(file),
                  child: Padding(
                    padding: responsive.contentPadding,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: isTablet ? 28 : 22,
                          backgroundColor: isCurrentDb
                              ? Colors.green.withValues(alpha: 0.15)
                              : scheme.primary.withValues(alpha: 0.12),
                          child: Icon(
                            isCurrentDb ? Icons.check_circle : Icons.storage_rounded,
                            color: isCurrentDb ? Colors.green.shade600 : scheme.primary,
                            size: iconSize,
                          ),
                        ),
                        SizedBox(width: isTablet ? 16 : 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fileName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: responsive.bodyFontSize,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (isCurrentDb)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(32),
                                  ),
                                  child: Text(
                                    localizations.currentlyLoaded,
                                    style: TextStyle(
                                      fontSize: responsive.smallFontSize,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  file.parent.path,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: responsive.bodyFontSize - 5,
                                    color: muted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (!isCurrentDb)
                          Icon(Icons.chevron_right, color: muted, size: iconSize),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
