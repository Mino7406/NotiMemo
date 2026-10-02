import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notimemo/screens/settings_screen.dart';
import 'package:notimemo/services/update_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> openSettings(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(420, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: SettingsScreen(
        currentMode: ThemeMode.light,
        onThemeChanged: (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: '알림메모',
      packageName: 'com.example.notimemo',
      version: '2.6.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });
  tearDown(() => UpdateService.debugCheck = null);

  testWidgets('새 버전이 있으면 업데이트 안내 창이 뜬다', (tester) async {
    UpdateService.debugCheck = () async =>
        const UpdateResult(UpdateStatus.available, '3.0.0');
    await openSettings(tester);
    await tester.ensureVisible(find.byKey(const Key('check-update')));
    await tester.tap(find.byKey(const Key('check-update')));
    await tester.pumpAndSettle();
    expect(find.text('업데이트 알림'), findsOneWidget);
    expect(find.textContaining('v3.0.0'), findsOneWidget);
  });

  testWidgets('이미 최신이면 토스트로 알려 준다', (tester) async {
    UpdateService.debugCheck = () async =>
        const UpdateResult(UpdateStatus.upToDate);
    await openSettings(tester);
    await tester.ensureVisible(find.byKey(const Key('check-update')));
    await tester.tap(find.byKey(const Key('check-update')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('최신 버전을 사용하고 있어요.'), findsOneWidget);
    expect(find.text('업데이트 알림'), findsNothing);
  });

  testWidgets('확인에 실패하면 오류 토스트를 보여 준다', (tester) async {
    UpdateService.debugCheck = () async =>
        const UpdateResult(UpdateStatus.failed);
    await openSettings(tester);
    await tester.ensureVisible(find.byKey(const Key('check-update')));
    await tester.tap(find.byKey(const Key('check-update')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('확인하지 못했어요'), findsOneWidget);
  });
}
