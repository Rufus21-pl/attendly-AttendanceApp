import 'package:attendly/app/shell/new_year_banner.dart';
import 'package:attendly/data/database/database_state.dart';
import 'package:attendly/features/database_picker/pages/database_picker_page.dart';
import 'package:attendly/core/responsive/responsive.dart';
import 'package:attendly/data/database/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:attendly/features/settings/pages/settings_page.dart';
import 'package:attendly/app/shell/app_tab.dart';
import 'package:attendly/app/startup/app_startup_notifier.dart';
import 'package:attendly/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A tab in the drawer and the rail: outlined icon, filled when selected.
typedef _Destination = ({AppTab tab, IconData icon, IconData selectedIcon, String label});

class AppNavigationDrawer extends ConsumerWidget {
  /// The tablet rail instead of the drawer.
  final bool isRailMode;

  const AppNavigationDrawer({
    super.key,
    this.isRailMode = false,
  });

  void _selectTab(WidgetRef ref, AppTab tab) {
    ref.read(selectedTabProvider.notifier).state = tab;
  }

  /// Runs the default startup again: the new-year banner leads to the
  /// rollover question, "return to main database" leaves a picked database.
  void _openDefaultDatabase(BuildContext context) {
    ProviderScope.containerOf(context, listen: false)
        .read(appStartupProvider.notifier)
        .openDefault();
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
  }

  void _openDatabaseAction(BuildContext context, DatabaseState appState) {
    if (appState.isTemporaryDb) {
      _openDefaultDatabase(context);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DatabasePickerPage(
            currentDbPath: appState.currentDbPath,
          ),
        ),
      );
    }
  }

  List<_Destination> _destinations(AppLocalizations localizations) => [
        (tab: AppTab.directory, icon: Icons.people_outline, selectedIcon: Icons.people, label: localizations.directory),
        (tab: AppTab.dailyLog, icon: Icons.calendar_today_outlined, selectedIcon: Icons.calendar_today, label: localizations.dailyLogs),
        (tab: AppTab.weeklyReport, icon: Icons.view_week_outlined, selectedIcon: Icons.view_week, label: localizations.weeklyReport),
        (tab: AppTab.yearlyReport, icon: Icons.bar_chart_outlined, selectedIcon: Icons.bar_chart, label: localizations.yearStats),
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isRailMode) {
      return _buildNavigationRail(context, ref);
    } else {
      return _buildDrawer(context, ref);
    }
  }

  Widget _buildNavigationRail(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(databaseProvider);
    final showBanner = appState.showNewYearBanner;
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final iconSize = Responsive.of(context).iconSize(baseSize: 32);

    final selectedTab = ref.watch(selectedTabProvider);

    return NavigationRail(
      extended: false,
      minWidth: 72,
      selectedIndex: selectedTab.index,
      onDestinationSelected: (index) => _selectTab(ref, AppTab.values[index]),
      labelType: NavigationRailLabelType.none,
      backgroundColor: theme.scaffoldBackgroundColor,
      indicatorColor: scheme.primary.withValues(alpha: 0.15),
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Column(
        children: [
          const SizedBox(height: 8),
          Builder(
            builder: (context) => IconButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: Icon(
                Icons.menu,
                color: theme.iconTheme.color,
                size: iconSize * 0.95,
              ),
            ),
          ),
          if (showBanner)
            Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 16),
              child: NewYearRailBadge(
                iconSize: iconSize,
                onTap: () => _openDefaultDatabase(context),
              ),
            ),
          SizedBox(height: showBanner ? 0 : 40),
        ],
      ),
      destinations: [
        for (final destination in _destinations(localizations))
          NavigationRailDestination(
            icon: Icon(destination.icon, size: iconSize),
            selectedIcon: Icon(destination.selectedIcon, size: iconSize, color: scheme.primary),
            label: Text(destination.label, style: const TextStyle(fontSize: 14)),
          ),
      ],
      trailing: Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: Icon(Icons.settings_outlined, size: iconSize),
              onPressed: () => _openSettings(context),
              tooltip: localizations.settings,
            ),
            const SizedBox(height: 16),
            IconButton(
              icon: Icon(
                appState.isTemporaryDb ? Icons.exit_to_app : Icons.folder_open_outlined,
                size: iconSize,
              ),
              onPressed: () => _openDatabaseAction(context, appState),
              tooltip: appState.isTemporaryDb
                  ? localizations.returnToMainDatabase
                  : localizations.changeDatabase,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(selectedTabProvider);
    final appState = ref.watch(databaseProvider);
    final showBanner = appState.showNewYearBanner;
    final localizations = AppLocalizations.of(context);
    final responsive = Responsive.of(context);
    final isTablet = responsive.isTablet;

    return Drawer(
      width: isTablet
          ? MediaQuery.of(context).size.width * 0.55
          : MediaQuery.of(context).size.width * 0.75,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _DrawerHeader(
            appState: appState,
            showBanner: showBanner,
            onBannerTap: () => _openDefaultDatabase(context),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(vertical: isTablet ? 12 : 8),
              children: [
                for (final destination in _destinations(localizations))
                  _DrawerItem(
                    icon: destination.icon,
                    selectedIcon: destination.selectedIcon,
                    text: destination.label,
                    isSelected: selectedTab == destination.tab,
                    onTap: () {
                      _selectTab(ref, destination.tab);
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
          const Divider(indent: 16, endIndent: 16),
          _DrawerItem(
            icon: Icons.settings_outlined,
            text: localizations.settings,
            onTap: () {
              Navigator.pop(context);
              _openSettings(context);
            },
          ),
          _DrawerItem(
            icon: appState.isTemporaryDb ? Icons.exit_to_app : Icons.folder_open_outlined,
            text: appState.isTemporaryDb ? localizations.returnToMainDatabase : localizations.changeDatabase,
            onTap: () {
              Navigator.pop(context);
              _openDatabaseAction(context, appState);
            },
          ),
          const _VersionFooter(),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

/// Gradient header: app name, the open database with its year and kind, and
/// the new-year banner when a new year is available.
class _DrawerHeader extends StatelessWidget {
  final DatabaseState appState;
  final bool showBanner;
  final VoidCallback onBannerTap;

  const _DrawerHeader({
    required this.appState,
    required this.showBanner,
    required this.onBannerTap,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isTablet = Responsive.of(context).isTablet;
    final dbName = p.basename(appState.currentDbPath ?? localizations.noDatabaseOpen);
    final year = appState.dbYear;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade700, theme.primaryColor, theme.primaryColorLight],
          stops: const [0.0, 0.55, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Soft circles give the flat gradient some depth.
          Positioned(
            right: -40,
            top: -30,
            child: _Circle(size: isTablet ? 200 : 150, alpha: 0.10),
          ),
          Positioned(
            right: 40,
            bottom: -60,
            child: _Circle(size: isTablet ? 140 : 110, alpha: 0.07),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              isTablet ? 24 : 20,
              MediaQuery.of(context).padding.top + (isTablet ? 24 : 16),
              isTablet ? 24 : 20,
              isTablet ? 24 : 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isTablet ? 10 : 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.how_to_reg, color: Colors.white, size: isTablet ? 32 : 26),
                    ),
                    SizedBox(width: isTablet ? 14 : 12),
                    Text(
                      localizations.attendly,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isTablet ? 30 : 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isTablet ? 24 : 18),
                // The open database on a frosted card.
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isTablet ? 16 : 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(isTablet ? 18 : 14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.storage, size: isTablet ? 22 : 18, color: Colors.white70),
                          const SizedBox(width: 6),
                          Text(
                            localizations.currentDatabase,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: isTablet ? 16 : 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dbName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isTablet ? 22 : 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                      SizedBox(height: isTablet ? 10 : 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (year != null) _HeaderChip(icon: Icons.event, label: '$year'),
                          _HeaderChip(
                            icon: appState.isTemporaryDb ? Icons.history : Icons.verified_outlined,
                            label: appState.isTemporaryDb
                                ? localizations.otherDatabaseOpen
                                : localizations.mainDatabase,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (showBanner) ...[
                  SizedBox(height: isTablet ? 16 : 12),
                  NewYearBanner(onTap: onBannerTap),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  final double size;
  final double alpha;

  const _Circle({required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: alpha),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Small white pill in the header, e.g. the database year.
class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final isTablet = Responsive.of(context).isTablet;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 10 : 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isTablet ? 16 : 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: isTablet ? 14 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A drawer entry with a pill-shaped highlight when selected.
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final IconData? selectedIcon;
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    this.selectedIcon,
    required this.text,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.primary;
    final defaultTextColor = theme.listTileTheme.textColor ?? theme.textTheme.bodyLarge?.color ?? Colors.black87;
    final defaultIconColor = theme.listTileTheme.iconColor ?? theme.iconTheme.color ?? Colors.grey;
    final responsive = Responsive.of(context);
    final isTablet = responsive.isTablet;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 16 : 12,
        vertical: 2,
      ),
      // The highlight is a Material, so the ListTile's ink splash stays visible.
      child: Material(
        color: isSelected ? selectedColor.withValues(alpha: 0.12) : Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: isTablet ? 20 : 16,
            vertical: isTablet ? 4 : 0,
          ),
          leading: Icon(
            isSelected ? (selectedIcon ?? icon) : icon,
            color: isSelected ? selectedColor : defaultIconColor,
            size: (isTablet ? 32 : 24) * responsive.iconScaleFactor,
          ),
          title: Text(
            text,
            style: TextStyle(
              fontSize: (isTablet ? 18 : 16) * (isTablet ? 0.9 : 1.0),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? selectedColor : defaultTextColor,
            ),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

/// App version at the bottom of the drawer.
class _VersionFooter extends StatelessWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 12);
        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          child: Text(
            AppLocalizations.of(context).getAppsVerision(snapshot.data!.version),
            style: TextStyle(
              fontSize: responsive.smallFontSize,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        );
      },
    );
  }
}
