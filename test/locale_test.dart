import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notimemo/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 글을 길게 눌렀을 때 뜨는 복사/붙여넣기가 기기 언어를 따르는지 확인한다.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'tutorial_seen': true}));

  Future<String> pasteLabel(WidgetTester tester, Locale device) async {
    tester.platformDispatcher.localesTestValue = [device];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(const NotiMemoApp());
    await tester.pump(const Duration(milliseconds: 500));
    final label = MaterialLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    ).pasteButtonLabel;
    // 홈 화면이 만든 타이머(업데이트 확인 8초, 진입 애니메이션)를 정리한다.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 13));
    return label;
  }

  testWidgets('기기 언어가 한국어면 붙여넣기가 한글로 나온다', (tester) async {
    expect(await pasteLabel(tester, const Locale('ko', 'KR')), '붙여넣기');
  });

  testWidgets('기기 언어가 영어면 Paste로 나온다', (tester) async {
    expect(await pasteLabel(tester, const Locale('en', 'US')), 'Paste');
  });
}
