import 'package:attendly/core/app_info/app_info.dart';
import 'package:attendly/data/database/app_database.dart';
import 'package:attendly/features/settings/pages/settings_page.dart';
import 'package:attendly/l10n/app_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../helpers/pump_app.dart';
import '../helpers/test_database.dart';

/// The author and license entries in Settings > About.
void main() {
  final l10n = AppLocalizationsEn();
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
    PackageInfo.setMockInitialValues(
      appName: 'attendly',
      packageName: 'attendly',
      version: '1.2.3',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  tearDown(() => db.close());

  /// A tall screen, so the About section at the end of the list is built.
  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpWithDatabase(tester, const SettingsPage(), db: db);
  }

  testWidgets('shows the copyright notice with the author name', (tester) async {
    await pumpSettings(tester);

    expect(find.text('© ${AppInfo.copyrightYear} ${AppInfo.authorName}'), findsOneWidget);
    expect(find.text(l10n.allRightsReserved), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('the license entry shows the LICENSE file', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.text(l10n.licenseTitle));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.textContaining('WITHOUT WARRANTY OF ANY KIND')),
      findsOneWidget,
    );
    expect(find.descendant(of: dialog, matching: find.text(l10n.licenseLoadFailed)), findsNothing);

    await tester.tap(find.text(l10n.close));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);

    await unmount(tester);
  });

  testWidgets('the open-source entry shows the licenses of the packages', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.text(l10n.openSourceLicenses));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(LicensePage), findsOneWidget);
    expect(find.text(AppInfo.copyrightNotice), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('the contact entry shows the repository link and copies it', (tester) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await pumpSettings(tester);

    await tester.tap(find.text(l10n.contactAuthor));
    await tester.pumpAndSettle();
    expect(find.text(AppInfo.repositoryUrl), findsOneWidget);

    await tester.tap(find.text(l10n.copyToClipboard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(clipboard, AppInfo.repositoryUrl);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(l10n.linkCopiedToClipboard), findsOneWidget);

    // Let the snackbar timer finish before the tree is removed.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await unmount(tester);
  });
}
