import 'package:attendly/core/responsive/responsive.dart';
import 'package:attendly/core/utils/date_utils.dart';
import 'package:attendly/data/database/database_provider.dart';
import 'package:attendly/data/database/exceptions.dart' as custom_db_exceptions;
import 'package:attendly/features/daily_log/models/category_record.dart';
import 'package:attendly/features/daily_log/models/person_with_categories.dart';
import 'package:attendly/features/daily_log/pages/daily_entry_form_page.dart';
import 'package:attendly/features/daily_log/providers/daily_log_providers.dart';
import 'package:attendly/l10n/app_localizations.dart';
import 'package:attendly/shared/dialogs/app_dialogs.dart';
import 'package:attendly/shared/widgets/tablet_date_picker_builder.dart';
import 'package:attendly/shared/navigation/app_routes.dart';
import 'package:attendly/shared/options/category_label.dart';
import 'package:attendly/shared/options/category_option.dart';
import 'package:attendly/shared/shell/shell_tab.dart';
import 'package:attendly/shared/widgets/choice_chip_group.dart';
import 'package:attendly/shared/widgets/date_navigator.dart';
import 'package:attendly/shared/widgets/empty_state.dart';
import 'package:attendly/shared/widgets/tab_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Daily attendance: entries of one day, grouped by person, with an edit
/// mode for bulk actions.
class DailyLogTab extends ShellTab {
  const DailyLogTab();

  static void _toggleEditMode(WidgetRef ref) {
    final isEditing = ref.read(dailyEditModeProvider);
    ref.read(dailyEditModeProvider.notifier).state = !isEditing;
    if (isEditing) {
      ref.read(dailySelectedPeopleProvider.notifier).state = {};
    }
  }

  static void _selectAll(WidgetRef ref, List<PersonWithCategories> visiblePeople) {
    final currentSet = ref.read(dailySelectedPeopleProvider);
    if (currentSet.length == visiblePeople.length) {
      ref.read(dailySelectedPeopleProvider.notifier).state = {};
    } else {
      ref.read(dailySelectedPeopleProvider.notifier).state = Set.from(visiblePeople);
    }
  }

  @override
  PreferredSizeWidget buildAppBar(BuildContext context, WidgetRef ref) {
    final asyncFilteredData = ref.watch(dailyFilteredLogsProvider);
    final isEditMode = ref.watch(dailyEditModeProvider);
    final responsive = Responsive.of(context);
    final selectedDate = ref.watch(dailyDateProvider);
    final dbYear = ref.watch(databaseProvider.select((s) => s.dbYear));
    final isOnToday = DateUtils.isSameDay(selectedDate, getScopedDate(dbYear: dbYear));

    // Grab the list if available to check lengths
    final visiblePeople = asyncFilteredData.valueOrNull ?? [];

    return TabAppBar(
      title: AppLocalizations.of(context).dailyLogs,
      leading:
          isEditMode
              ? IconButton(
                icon: Icon(Icons.close, size: responsive.iconSize()),
                onPressed: () => _toggleEditMode(ref),
              )
              : DrawerMenuButton.forShell(context),
      actions: [
        // Rebuilding the date provider returns to today (or to the first day
        // of an older database's year).
        if (!isEditMode && !isOnToday)
          IconButton(
            icon: Icon(Icons.today, size: responsive.iconSize(baseSize: 28)),
            tooltip: AppLocalizations.of(context).jumpToToday,
            onPressed: () => ref.invalidate(dailyDateProvider),
          ),
        if (!isEditMode)
          IconButton(
            icon: Icon(Icons.edit, size: responsive.iconSize(baseSize: 30)),
            onPressed: visiblePeople.isEmpty ? null : () => _toggleEditMode(ref),
          ),
        if (isEditMode)
          IconButton(
            icon: Icon(
              Icons.select_all,
              size: responsive.iconSize(baseSize: 28),
            ),
            onPressed: visiblePeople.isEmpty ? null : () => _selectAll(ref, visiblePeople),
          ),
      ],
    );
  }

  @override
  Widget buildBody(BuildContext context, WidgetRef ref) => const _DailyLogBody();

  @override
  Widget? buildFab(BuildContext context, WidgetRef ref) {
    if (ref.watch(dailyEditModeProvider)) return null;
    final responsive = Responsive.of(context);

    // mainAxisSize.min: the Scaffold scales the FAB in from its centre, and a
    // full-height column made both buttons fly in from the middle of the screen.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: responsive.buttonHeight + 10,
          height: responsive.buttonHeight + 10,
          child: FloatingActionButton(
            heroTag: 'search_fab',
            onPressed: () => _openSearch(context, ref),
            child: Icon(
              Icons.search,
              size: responsive.iconSize(baseSize: 30),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: responsive.buttonHeight + 25,
          height: responsive.buttonHeight + 25,
          child: FloatingActionButton(
            heroTag: 'add_fab',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => DailyEntryFormPage(
                  mode: DailyEntryFormMode.add,
                  initialDate: ref.read(dailyDateProvider),
                ),
              ),
            ),
            child: Icon(
              Icons.add,
              size: responsive.iconSize(baseSize: 35),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget? buildBottomBar(BuildContext context, WidgetRef ref) {
    return ref.watch(dailyEditModeProvider) ? const _EditModeActions() : null;
  }

  Future<void> _openSearch(BuildContext context, WidgetRef ref) async {
    final selectedDate = await Navigator.of(context).pushNamed<DateTime>(AppRoutes.dailyLogSearch);
    if (selectedDate != null && context.mounted) {
      ref.read(dailyDateProvider.notifier).state = selectedDate;
    }
  }
}

class _DailyLogBody extends ConsumerStatefulWidget {
  const _DailyLogBody();

  @override
  ConsumerState<_DailyLogBody> createState() => _DailyLogBodyState();
}

class _DailyLogBodyState extends ConsumerState<_DailyLogBody> {

  void _toggleSelection(PersonWithCategories person) {
    final currentSet = ref.read(dailySelectedPeopleProvider);
    final newSet = Set<PersonWithCategories>.from(currentSet);
    if (newSet.contains(person)) {
      newSet.remove(person);
    } else {
      newSet.add(person);
    }
    ref.read(dailySelectedPeopleProvider.notifier).state = newSet;
  }

  Future<void> _selectDate() async {
    final currentDate = ref.read(dailyDateProvider);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      keyboardType: const TextInputType.numberWithOptions(),
      builder: tabletDatePickerBuilder,
    );

    if (picked != null && picked != currentDate && mounted) {
      ref.read(dailyDateProvider.notifier).state = picked;
      if (ref.read(dailyEditModeProvider)) DailyLogTab._toggleEditMode(ref);
    }
  }

  Future<void> _deleteCategory(CategoryRecord record) async {
    final localizations = AppLocalizations.of(context);
    final repo = ref.read(dailyRepositoryProvider);

    final confirm = await AppDialogs.confirm(
      context,
      title: localizations.deleteRecord,
      message: localizations.confirmDeleteCategory(
        localizedCategoryLabel(context, record.category),
        record.personName ?? localizations.unknown,
        record.date,
      ),
    );

    if (confirm && mounted) {
      try {
        AppDialogs.showLoading(context, localizations.delete);
        await repo.deleteDailyEntry(record.recordId, record.personId, DateTime.parse(record.date));
        if (mounted) {
          AppDialogs.hideLoading(context);
          await AppDialogs.showSuccess(context, localizations.recordDeleted);
        }
      } catch (e) {
        if (!mounted) return;
        AppDialogs.hideLoading(context);
        AppDialogs.showError(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch state
    final asyncFilteredData = ref.watch(dailyFilteredLogsProvider);
    final selectedDate = ref.watch(dailyDateProvider);
    final isEditMode = ref.watch(dailyEditModeProvider);
    final selectedPeople = ref.watch(dailySelectedPeopleProvider);

    ref.listen<AsyncValue<List<PersonWithCategories>?>>(dailyRawLogsProvider, (prev, next) {
      if (next is AsyncError) {
        final error = next.error;
        if (error != null && error is! custom_db_exceptions.DatabaseNotReadyException) {
          ref.read(databaseProvider.notifier).reportDatabaseError(error);
        }
      }
    });

    final now = DateTime.now();
    final todayDateOnly = DateTime(now.year, now.month, now.day);
    final selectedDateOnly = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final isTodayOrFuture = !selectedDateOnly.isBefore(todayDateOnly);
    final weekday = DateFormat.EEEE(Localizations.localeOf(context).toString()).format(selectedDate);

    return Center(
      child: Column(
        children: [
          DateNavigator(
            label: "${selectedDate.day}.${selectedDate.month}.${selectedDate.year}",
            subtitle: weekday,
            onPick: _selectDate,
            onPrevious:
                () =>
                    ref.read(dailyDateProvider.notifier).state = selectedDate.subtract(
                      const Duration(days: 1),
                    ),
            onNext:
                isTodayOrFuture
                    ? null
                    : () =>
                        ref.read(dailyDateProvider.notifier).state = selectedDate.add(
                          const Duration(days: 1),
                        ),
          ),
          const _FilterSection(),
          Expanded(
            child: asyncFilteredData.when(
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              // Errors are reported to the startup gate by the listener above.
              error: (error, stacktrace) => const Center(child: CircularProgressIndicator()),
              data:
                  (people) => _PersonList(
                    people: people,
                    isEditMode: isEditMode,
                    selectedPeople: selectedPeople,
                    onToggleSelection: _toggleSelection,
                    onAddCategory: (person) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (ctx) => DailyEntryFormPage(
                                mode: DailyEntryFormMode.add,
                                initialDate: selectedDate,
                                preselectedPersons: [(id: person.personId, name: person.name)],
                              ),
                        ),
                      );
                    },
                    onEditCategory: (record) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => DailyEntryFormPage(mode: DailyEntryFormMode.edit, record: record),
                        ),
                      );
                    },
                    onDeleteCategory: _deleteCategory,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom bar in edit mode: add a category to, or delete the entries of, the
/// selected people.
class _EditModeActions extends ConsumerStatefulWidget {
  const _EditModeActions();

  @override
  ConsumerState<_EditModeActions> createState() => _EditModeActionsState();
}

class _EditModeActionsState extends ConsumerState<_EditModeActions> {

  Future<void> _onBulkAddCategory() async {
    final selectedSet = ref.read(dailySelectedPeopleProvider);
    final date = ref.read(dailyDateProvider);
    final selectedList = [for (final p in selectedSet) (id: p.personId, name: p.name)];

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder:
            (context) => DailyEntryFormPage(
              mode: DailyEntryFormMode.add,
              initialDate: date,
              preselectedPersons: selectedList,
            ),
      ),
    );

    if (result == true && mounted) {
      DailyLogTab._toggleEditMode(ref);
    }
  }

  Future<void> _onBulkDelete() async {
    final localizations = AppLocalizations.of(context);
    final selectedSet = ref.read(dailySelectedPeopleProvider);
    final count = selectedSet.length;
    final date = ref.read(dailyDateProvider);
    final repo = ref.read(dailyRepositoryProvider);

    final confirm = await AppDialogs.confirm(
      context,
      title: localizations.delete,
      message: localizations.confirmBulkDelete(count),
    );
    if (!confirm || !mounted) return;

    try {
      AppDialogs.showLoading(context, localizations.delete);
      final personIds = selectedSet.map((p) => p.personId).toList();
      await repo.bulkDeleteEntries(personIds, date);
      if (!mounted) return;
      AppDialogs.hideLoading(context);
      await AppDialogs.showSuccess(context, localizations.peopleEntriesDeleted(count));
      if (mounted) DailyLogTab._toggleEditMode(ref);
    } catch (e, stackTrace) {
      if (!mounted) return;
      AppDialogs.hideLoading(context);
      AppDialogs.showError(context, 'Failed to delete entries: $e', stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final responsive = Responsive.of(context);
    final selectedCount = ref.watch(dailySelectedPeopleProvider).length;
    final hasSelection = selectedCount > 0;

    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          TextButton.icon(
            icon: Icon(Icons.add_task, size: responsive.iconSize()),
            label: Text(
              localizations.addCategory,
              style: TextStyle(fontSize: responsive.smallFontSize),
            ),
            onPressed: hasSelection ? _onBulkAddCategory : null,
          ),
          TextButton.icon(
            icon: Icon(Icons.delete_sweep, size: responsive.iconSize()),
            label: Text(
              '${localizations.delete} ($selectedCount)',
              style: TextStyle(fontSize: responsive.smallFontSize),
            ),
            onPressed: hasSelection ? _onBulkDelete : null,
            style: TextButton.styleFrom(foregroundColor: hasSelection ? Colors.red : Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _FilterSection extends ConsumerStatefulWidget {
  const _FilterSection();
  @override
  ConsumerState<_FilterSection> createState() => _FilterSectionState();
}

/// Collapsible name search and category chips. When collapsed, a badge and a
/// summary line show which filters are active.
class _FilterSectionState extends ConsumerState<_FilterSection> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      ref.read(dailySearchProvider.notifier).state = _searchController.text;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    _searchController.clear();
    ref.read(dailyCategoryFilterProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final responsive = Responsive.of(context);
    final scheme = Theme.of(context).colorScheme;
    final body = responsive.bodyFontSize;
    final search = ref.watch(dailySearchProvider);
    final selectedCat = ref.watch(dailyCategoryFilterProvider);
    final categoryOptions = getCategoryOptions(context);
    final activeCount = (search.isNotEmpty ? 1 : 0) + (selectedCat != null ? 1 : 0);
    final shape = RoundedRectangleBorder(borderRadius: responsive.cardBorderRadius);

    // Sync the search field when the provider is externally reset (e.g. on date change).
    // ref.listen callbacks fire after build — safe to mutate controller state here.
    ref.listen<String>(dailySearchProvider, (_, next) {
      if (next.isEmpty && _searchController.text.isNotEmpty) _searchController.clear();
    });

    final summary = [
      if (search.isNotEmpty) '"$search"',
      if (selectedCat != null) localizedCategoryLabel(context, selectedCat),
    ].join(' · ');

    return Padding(
      padding: responsive.listPadding.copyWith(
        left: responsive.listPadding.horizontal + 4,
        right: responsive.listPadding.horizontal + 4,
      ),
      child: ExpansionTile(
        shape: shape,
        collapsedShape: shape,
        clipBehavior: Clip.antiAlias,
        backgroundColor: scheme.primary.withValues(alpha: 0.06),
        collapsedBackgroundColor: scheme.primary.withValues(alpha: 0.06),
        leading: Badge(
          isLabelVisible: activeCount > 0,
          label: Text('$activeCount'),
          child: Icon(Icons.filter_list, color: scheme.primary, size: responsive.iconSize()),
        ),
        title: Text(
          localizations.filterOptions,
          style: TextStyle(
            fontSize: responsive.titleFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle:
            summary.isEmpty
                ? null
                : Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: responsive.smallFontSize + 2, color: scheme.primary),
                ),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
        childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, responsive.isTablet ? 16 : 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            style: TextStyle(fontSize: body + 2),
            decoration: InputDecoration(
              hintText: localizations.searchByName,
              hintStyle: TextStyle(fontSize: body + 2),
              isDense: true,
              filled: true,
              fillColor: Theme.of(context).cardTheme.color,
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(32),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(32),
                borderSide: BorderSide(color: scheme.primary, width: 2),
              ),
              suffixIcon:
                  search.isNotEmpty
                      ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                      : null,
            ),
          ),
          SizedBox(height: responsive.isTablet ? 16 : 12),
          Text(
            localizations.filterByCategory,
            style: TextStyle(fontSize: body - 2, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          // Tapping the selected chip again clears the category filter.
          ChoiceChipGroup<String>(
            choices: [
              for (final option in categoryOptions)
                (value: option.category.name, label: option.label, icon: option.icon),
            ],
            selected: selectedCat,
            onChanged: (category) => ref.read(dailyCategoryFilterProvider.notifier).state = category,
          ),
          if (activeCount > 0)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: Icon(Icons.filter_alt_off_outlined, size: responsive.iconSize(baseSize: 20)),
                label: Text(localizations.reset, style: TextStyle(fontSize: body - 2)),
                onPressed: _resetFilters,
              ),
            ),
        ],
      ),
    );
  }
}

class _PersonList extends StatelessWidget {
  final List<PersonWithCategories> people;
  final bool isEditMode;
  final Set<PersonWithCategories> selectedPeople;
  final Function(PersonWithCategories) onToggleSelection;
  final Function(PersonWithCategories) onAddCategory;
  final Function(CategoryRecord) onEditCategory;
  final Function(CategoryRecord) onDeleteCategory;

  const _PersonList({
    required this.people,
    required this.isEditMode,
    required this.selectedPeople,
    required this.onToggleSelection,
    required this.onAddCategory,
    required this.onEditCategory,
    required this.onDeleteCategory,
  });

  /// An entry of the edit/delete menu: tinted icon and label.
  static PopupMenuItem<String> _menuItem(
    BuildContext context, {
    required String value,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final responsive = Responsive.of(context);
    return PopupMenuItem(
      value: value,
      height: responsive.buttonHeight + 4,
      child: Row(
        children: [
          Icon(icon, color: color, size: responsive.iconSize(baseSize: 22)),
          SizedBox(width: responsive.isTablet ? 16 : 12),
          Text(
            label,
            style: TextStyle(
              fontSize: responsive.bodyFontSize,
              fontWeight: FontWeight.w500,
              color: value == 'delete' ? color : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) {
      return EmptyState(
        icon: Icons.event_busy_outlined,
        message: AppLocalizations.of(context).noEntriesForThisDay,
      );
    }

    final responsive = Responsive.of(context);
    final scheme = Theme.of(context).colorScheme;
    final bodyFontSize = responsive.bodyFontSize;
    final iconSize = responsive.iconSize();
    final categoryIcons = {
      for (final option in getCategoryOptions(context)) option.category.name: option.icon,
    };

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        responsive.listPadding.horizontal,
        0,
        responsive.listPadding.horizontal,
        responsive.buttonHeight + 60,
      ),
      itemCount: people.length,
      itemBuilder: (context, index) {
        final person = people[index];
        final isSelected = selectedPeople.contains(person);

        return Card(
          color: isSelected ? scheme.primary.withValues(alpha: 0.1) : null,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            side:
                isSelected
                    ? BorderSide(color: scheme.primary, width: 2)
                    : BorderSide.none,
            borderRadius: responsive.cardBorderRadius,
          ),
          child: InkWell(
            onTap: isEditMode ? () => onToggleSelection(person) : null,
            child: Padding(
              padding: responsive.contentPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: responsive.isTablet ? 24 : 18,
                        backgroundColor: scheme.primary.withValues(alpha: 0.15),
                        foregroundColor: scheme.primary,
                        child: Text(
                          person.name.isEmpty ? '?' : person.name.characters.first.toUpperCase(),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: bodyFontSize),
                        ),
                      ),
                      SizedBox(width: responsive.isTablet ? 16 : 12),
                      Expanded(
                        child: Text(
                          person.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: Responsive.of(context).titleFontSize,
                          ),
                        ),
                      ),
                      if (isEditMode)
                        Checkbox(value: isSelected, onChanged: (_) => onToggleSelection(person)),
                    ],
                  ),
                  const Divider(),
                  ...person.records.map(
                    (record) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        categoryIcons[record.category] ?? Icons.label_outline,
                        color: scheme.primary,
                        size: iconSize,
                      ),
                      title: Text(
                        localizedCategoryLabel(context, record.category),
                        style: TextStyle(fontSize: bodyFontSize),
                      ),
                      subtitle:
                          record.comment != null
                              ? Text(record.comment!, style: TextStyle(fontSize: bodyFontSize - 2))
                              : null,
                      trailing:
                          isEditMode
                              ? null
                              : PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert, size: iconSize),
                                position: PopupMenuPosition.under,
                                onSelected: (val) {
                                  if (val == 'edit') onEditCategory(record);
                                  if (val == 'delete') onDeleteCategory(record);
                                },
                                itemBuilder:
                                    (ctx) => [
                                      _menuItem(
                                        context,
                                        value: 'edit',
                                        icon: Icons.edit_outlined,
                                        label: AppLocalizations.of(context).edit,
                                        color: scheme.primary,
                                      ),
                                      const PopupMenuDivider(height: 1),
                                      _menuItem(
                                        context,
                                        value: 'delete',
                                        icon: Icons.delete_outline,
                                        label: AppLocalizations.of(context).delete,
                                        color: scheme.error,
                                      ),
                                    ],
                              ),
                    ),
                  ),
                  if (!isEditMode)
                    Center(
                      child: TextButton.icon(
                        icon: Icon(Icons.add_circle_outline, size: iconSize),
                        label: Text(
                          AppLocalizations.of(context).addCategory,
                          style: TextStyle(fontSize: bodyFontSize),
                        ),
                        style: TextButton.styleFrom(foregroundColor: scheme.primary),
                        onPressed: () => onAddCategory(person),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
