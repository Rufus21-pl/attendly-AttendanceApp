import 'package:attendly/data/database/exceptions.dart' as custom_db_exceptions;
import 'package:attendly/features/daily_log/data/daily_repository.dart';
import 'package:attendly/features/daily_log/models/category_record.dart';
import 'package:attendly/shared/options/category_label.dart';
import 'package:attendly/shared/options/category_option.dart';
import 'package:attendly/core/responsive/responsive.dart';
import 'package:attendly/l10n/app_localizations.dart';
import 'package:attendly/features/daily_log/providers/daily_log_providers.dart';
import 'package:attendly/core/logging/app_logger.dart';
import 'package:attendly/shared/widgets/choice_chip_group.dart';
import 'package:attendly/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SearchType { name, description, nameAndDescription }

class DailyLogSearchPage extends ConsumerStatefulWidget {

  const DailyLogSearchPage({
    super.key,
  });

  @override
  ConsumerState<DailyLogSearchPage> createState() => _DailyLogSearchPageState();
}

class _DailyLogSearchPageState extends ConsumerState<DailyLogSearchPage> {
  final _nameSearchController = TextEditingController();
  final _descriptionSearchController = TextEditingController();
  String? _selectedCategory;
  bool _isLoading = false;
  Map<String, List<CategoryRecord>> _groupedResults = {};

  /// Before the first search the empty list shows a hint, not "no results".
  bool _hasSearched = false;
  Set<SearchType> _selectedSearchType = {SearchType.name};

  late DailyRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(dailyRepositoryProvider);
    _nameSearchController.addListener(() => setState(() {}));
    _descriptionSearchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameSearchController.dispose();
    _descriptionSearchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _groupedResults = {};
    });

    try {
      final searchType = _selectedSearchType.first;
      final results = await _repo.searchLogs(
        name: searchType == SearchType.name || searchType == SearchType.nameAndDescription
            ? _nameSearchController.text
            : null,
        description: searchType == SearchType.description || searchType == SearchType.nameAndDescription
            ? _descriptionSearchController.text
            : null,
        category: _selectedCategory,
      );

      final Map<String, List<CategoryRecord>> grouped = {};
      
      for (final row in results) {
        final person = row.readTable(_repo.db.directoryPeople);
        final entry = row.readTable(_repo.db.dailyEntry);

        final record = CategoryRecord.fromDrift(person, entry);
        
        if (grouped.containsKey(record.date)) {
          grouped[record.date]!.add(record);
        } else {
          grouped[record.date] = [record];
        }
      }

      setState(() {
        _groupedResults = grouped;
      });
    } on custom_db_exceptions.DatabaseNotReadyException {
      setState(() {
        _isLoading = false;
      });
      return;
    }
    catch (e, stackTrace) {
      AppLogger.e('Search', 'Search failed', e, stackTrace);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onEntryTap(String date) {
    Navigator.of(context).pop(DateTime.parse(date));
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final responsive = Responsive.of(context);
    final scheme = Theme.of(context).colorScheme;
    final iconSize = responsive.iconSize();
    final bodySize = responsive.bodyFontSize;
    final searchType = _selectedSearchType.first;
    final showName = searchType == SearchType.name || searchType == SearchType.nameAndDescription;
    final showDescription =
        searchType == SearchType.description || searchType == SearchType.nameAndDescription;
    final gap = SizedBox(height: responsive.listPadding.vertical * 3);
    final sideInset = responsive.contentPadding.left + 4;

    Widget sectionLabel(String text) => Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            text,
            style: TextStyle(fontSize: bodySize - 2, fontWeight: FontWeight.w600),
          ),
        );

    InputDecoration fieldDecoration({
      required String label,
      required IconData icon,
      required TextEditingController controller,
    }) {
      return InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: bodySize),
        prefixIcon: Icon(icon, size: iconSize, color: scheme.primary),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear, size: iconSize),
                onPressed: () => controller.clear(),
              )
            : null,
        border: OutlineInputBorder(borderRadius: responsive.cardBorderRadius),
        contentPadding: responsive.contentPadding,
      );
    }

    final form = Padding(
      padding: EdgeInsets.fromLTRB(sideInset, responsive.contentPadding.top, sideInset, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sectionLabel(localizations.searchIn),
          // A search field is always needed, so the selected chip cannot be cleared.
          ChoiceChipGroup<SearchType>(
            choices: [
              (value: SearchType.name, label: localizations.name, icon: Icons.person_search),
              (value: SearchType.description, label: localizations.searchByDescription, icon: Icons.description_outlined),
              (value: SearchType.nameAndDescription, label: localizations.searchByNameAndDescription, icon: Icons.find_in_page_outlined),
            ],
            selected: searchType,
            onChanged: (value) {
              if (value != null) setState(() => _selectedSearchType = {value});
            },
          ),
          gap,
          if (showName)
            TextField(
              controller: _nameSearchController,
              style: TextStyle(fontSize: bodySize),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _performSearch(),
              decoration: fieldDecoration(
                label: localizations.searchByName,
                icon: Icons.person_search,
                controller: _nameSearchController,
              ),
            ),
          if (showName && showDescription) SizedBox(height: responsive.listPadding.vertical * 2),
          if (showDescription)
            TextField(
              controller: _descriptionSearchController,
              style: TextStyle(fontSize: bodySize),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _performSearch(),
              decoration: fieldDecoration(
                label: localizations.searchByDescription,
                icon: Icons.description_outlined,
                controller: _descriptionSearchController,
              ),
            ),
          gap,
          sectionLabel(localizations.filterByCategory),
          ChoiceChipGroup<String>(
            choices: [
              for (final option in getCategoryOptions(context))
                (value: option.category.name, label: option.label, icon: option.icon),
            ],
            selected: _selectedCategory,
            onChanged: (value) => setState(() => _selectedCategory = value),
          ),
          SizedBox(height: responsive.listPadding.vertical * 4),
          ElevatedButton.icon(
            onPressed: _performSearch,
            icon: Icon(Icons.search, size: iconSize, color: Colors.white),
            label: Text(
              localizations.search,
              style: TextStyle(fontSize: bodySize, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, responsive.buttonHeight + 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
            ),
          ),
          SizedBox(height: responsive.listPadding.vertical * 3),
          const Divider(),
        ],
      ),
    );

    final List<Widget> results;
    if (_isLoading) {
      results = [
        const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    } else if (_groupedResults.isEmpty) {
      results = [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: EmptyState(
            icon: _hasSearched ? Icons.search_off : Icons.manage_search,
            message: _hasSearched ? localizations.noResultsFound : localizations.searchHint,
          ),
        ),
      ];
    } else {
      final locale = Localizations.localeOf(context).toString();
      results = [
        for (final MapEntry(key: date, value: records) in _groupedResults.entries)
          _buildDateGroup(date, records, locale, sideInset),
      ];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.searchDailyLog,
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
        padding: EdgeInsets.only(
          bottom: responsive.contentPadding.bottom + MediaQuery.of(context).padding.bottom,
        ),
        children: [form, ...results],
      ),
    );
  }

  /// The entries of one day: a header with date, weekday and count, then a
  /// card per entry. Tapping an entry opens that day in the daily log.
  Widget _buildDateGroup(String date, List<CategoryRecord> records, String locale, double sideInset) {
    final localizations = AppLocalizations.of(context);
    final responsive = Responsive.of(context);
    final scheme = Theme.of(context).colorScheme;
    final bodySize = responsive.bodyFontSize;
    final categoryIcons = {
      for (final option in getCategoryOptions(context)) option.category.name: option.icon,
    };

    DateTime parsedDate = DateTime.parse(date);
    String formattedDisplayDate = DateFormat('dd.MM.yyyy').format(parsedDate);
    final weekday = DateFormat.EEEE(locale).format(parsedDate);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: sideInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              4,
              responsive.listPadding.vertical * 3,
              4,
              responsive.listPadding.vertical * 1.5,
            ),
            child: Row(
              children: [
                Icon(Icons.event_outlined, color: scheme.primary, size: responsive.iconSize(baseSize: 22)),
                const SizedBox(width: 8),
                Text(
                  formattedDisplayDate,
                  style: TextStyle(fontSize: responsive.titleFontSize, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    weekday,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: bodySize - 2,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                Badge(
                  label: Text('${records.length}'),
                  backgroundColor: scheme.primary,
                  textColor: scheme.onPrimary,
                ),
              ],
            ),
          ),
          for (final record in records)
            Card(
              margin: EdgeInsets.only(bottom: responsive.listPadding.vertical * 1.5),
              elevation: responsive.cardElevation,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: responsive.cardBorderRadius),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: responsive.contentPadding.left,
                  vertical: 4,
                ),
                leading: CircleAvatar(
                  backgroundColor: scheme.primary.withValues(alpha: 0.12),
                  child: Icon(
                    categoryIcons[record.category] ?? Icons.label_outline,
                    color: scheme.primary,
                    size: responsive.iconSize(baseSize: 22),
                  ),
                ),
                title: Text(
                  record.personName ?? localizations.unknown,
                  style: TextStyle(fontSize: bodySize, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${localizedCategoryLabel(context, record.category)}${record.comment != null && record.comment!.isNotEmpty ? ': ${record.comment}' : ''}',
                  style: TextStyle(fontSize: bodySize - 2),
                ),
                trailing: Icon(Icons.chevron_right, size: responsive.iconSize()),
                onTap: () => _onEntryTap(record.date),
              ),
            ),
        ],
      ),
    );
  }
}
