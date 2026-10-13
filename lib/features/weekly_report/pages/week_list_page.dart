import 'package:attendly/data/database/app_database.dart';
import 'package:attendly/data/database/exceptions.dart' as custom_db_exceptions;
import 'package:attendly/l10n/app_localizations.dart';
import 'package:attendly/shared/dialogs/app_dialogs.dart';
import 'package:attendly/shared/widgets/empty_state.dart';
import 'package:attendly/core/responsive/responsive.dart';
import 'package:attendly/data/database/database_provider.dart';
import 'package:attendly/features/weekly_report/providers/weekly_report_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class WeekListPage extends ConsumerStatefulWidget {
  final DateTime currentWeekDate;

  const WeekListPage({
    super.key,
    required this.currentWeekDate,
  });

  @override
  ConsumerState<WeekListPage> createState() => _WeekListPageState();
}

class _WeekListPageState extends ConsumerState<WeekListPage> {

  Future<void> _toggleCountableWeek(WeeklyEntryData week) async {
    final repo = ref.read(weeklyRepositoryProvider);
    final newValue = !week.countable;

    try {
      await repo.updateCountableStatus(week.weekDate, newValue);
    } on custom_db_exceptions.DatabaseNotReadyException {
      return;
    } catch (e, stackTrace) {
      if (mounted) {
        AppDialogs.showError(context, 'Failed to update status: ${e.toString()}', stackTrace: stackTrace);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = Responsive.of(context).isTablet;
    final iconSize = Responsive.of(context).iconSize();
    
    final asyncWeeksList = ref.watch(allWeeksProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).weeksWithData,
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
      body: asyncWeeksList.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) {
            if (error is custom_db_exceptions.DatabaseNotReadyException) {
              return const Center(child: CircularProgressIndicator());
            }
            
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) ref.read(databaseProvider.notifier).reportDatabaseError(error);
            });
            return const Center(child: CircularProgressIndicator());
          },
          data: (weeksData) {
            if (weeksData.isEmpty) {
            return EmptyState(
              icon: Icons.date_range_outlined,
              message: AppLocalizations.of(context).noWeeklyEntriesFound,
            );
          }

          return ListView.builder(
            padding: EdgeInsets.symmetric(
              vertical: Responsive.of(context).listPadding.vertical,
              horizontal: Responsive.of(context).listPadding.horizontal,
            ),
            itemCount: weeksData.length,
            itemBuilder: (context, index) {
              final weekData = weeksData[index];
              final DateTime startDate = weekData.weekDate;
              final DateTime endDate = startDate.add(const Duration(days: 4));
              final displayStr = "${DateFormat('dd.MM.yyyy').format(startDate)} - ${DateFormat('dd.MM.yyyy').format(endDate)}";
              
              final bool isCountable = weekData.countable;
              final isCurrentWeek = weekData.weekDate == widget.currentWeekDate;
              final responsive = Responsive.of(context);
              final scheme = Theme.of(context).colorScheme;
              final localizations = AppLocalizations.of(context);
              final statusColor = isCountable ? Colors.green.shade600 : Colors.red.shade400;

              return Card(
                elevation: responsive.cardElevation,
                clipBehavior: Clip.antiAlias,
                margin: EdgeInsets.symmetric(
                  horizontal: responsive.listPadding.horizontal / 2,
                  vertical: responsive.listPadding.vertical * 1.3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: responsive.cardBorderRadius,
                  side: isCurrentWeek
                      ? BorderSide(color: scheme.primary, width: isTablet ? 2.0 : 1.5)
                      : BorderSide.none,
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pop({
                      'date': weekData.weekDate.toIso8601String(),
                      'isCountable': isCountable
                    });
                  },
                  // The coloured strip on the left shows the counted status
                  // at a glance while scrolling.
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(left: BorderSide(color: statusColor, width: isTablet ? 8 : 6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: responsive.contentPadding,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.date_range, color: scheme.primary, size: responsive.iconSize(baseSize: 22)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      displayStr,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: responsive.bodyFontSize + 2,
                                      ),
                                    ),
                                  ),
                                  if (isCurrentWeek)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: scheme.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(32),
                                      ),
                                      child: Text(
                                        localizations.selectedWeek,
                                        style: TextStyle(
                                          fontSize: responsive.smallFontSize,
                                          fontWeight: FontWeight.w600,
                                          color: scheme.primary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: responsive.listPadding.vertical * 3),
                              _buildWeekDataDetails(weekData),
                            ],
                          ),
                        ),
                        // Counted toggle; tapping the row or the switch flips it.
                        Material(
                          color: statusColor.withValues(alpha: 0.1),
                          child: InkWell(
                            onTap: () => _toggleCountableWeek(weekData),
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                responsive.contentPadding.left,
                                4,
                                responsive.contentPadding.right - 4,
                                4,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isCountable ? Icons.check_circle : Icons.cancel_outlined,
                                    color: statusColor,
                                    size: responsive.iconSize(baseSize: 22),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isCountable
                                          ? localizations.countedInYearReport
                                          : localizations.notCountedInYearReport,
                                      style: TextStyle(
                                        fontSize: responsive.bodyFontSize - 2,
                                        fontWeight: FontWeight.w600,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                  Tooltip(
                                    message: isCountable
                                        ? localizations.excludeFromYearReport
                                        : localizations.includeInYearReport,
                                    child: Switch(
                                      value: isCountable,
                                      activeThumbColor: Colors.white,
                                      activeTrackColor: Colors.green.shade600,
                                      onChanged: (_) => _toggleCountableWeek(weekData),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
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

  Widget _buildWeekDataDetails(WeeklyEntryData weekData) {
    final Map<String, int> keyStats = {};
    final localizations = AppLocalizations.of(context);

    // Calculate total visitors from open categories
    final totalVisitors = weekData.openMale + weekData.openFemale + weekData.openDiverse;

    // Select a few key statistics to display as chips
    final int maleCount = weekData.openMale;
    final int femaleCount = weekData.openFemale;

    if (maleCount > 0) keyStats[localizations.male] = maleCount;
    if (femaleCount > 0) keyStats[localizations.female] = femaleCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.groups, 
              size: Responsive.of(context).iconSize(baseSize: 18), 
              color: Colors.blueGrey,
            ),
            SizedBox(width: Responsive.of(context).listPadding.horizontal / 2),
            Text(
              '${localizations.totalVisitors}: $totalVisitors',
              style: TextStyle(
                fontSize: Responsive.of(context).bodyFontSize, 
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        if (keyStats.isNotEmpty) ...[
          SizedBox(height: Responsive.of(context).listPadding.vertical * 2),
          Wrap(
            spacing: Responsive.of(context).listPadding.horizontal / 2,
            runSpacing: Responsive.of(context).listPadding.vertical / 2,
            children: keyStats.entries.map((entry) {
              return Chip(
                avatar: CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.8),
                  child: Text(
                    entry.value.toString(),
                    style: TextStyle(
                      fontSize: Responsive.of(context).bodyFontSize - 6,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                label: Text(
                  entry.key,
                  style: TextStyle(fontSize: Responsive.of(context).bodyFontSize - 4),
                ),
                backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                side: BorderSide.none,
                padding: EdgeInsets.all(Responsive.of(context).contentPadding.vertical / 2),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
