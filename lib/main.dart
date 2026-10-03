import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/home_screen.dart';
import 'storage/settings_storage.dart';
import 'theme/app_theme.dart';

// 현재 테마(시스템/라이트/다크). 값이 바뀌면 MaterialApp이 다시 그려진다
final _themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

// 앱 시작점: 저장된 테마를 읽고 나서 화면을 띄운다
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  _themeModeNotifier.value = await SettingsStorage.getThemeMode();
  runApp(const NotiMemoApp());
}

class NotiMemoApp extends StatelessWidget {
  const NotiMemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeModeNotifier,
      builder: (_, mode, _) => MaterialApp(
        title: '알림메모',
        debugShowCheckedModeBanner: false,
        // 글을 길게 눌렀을 때 뜨는 복사/붙여넣기 같은 기본 문구를 기기 언어로 보여준다.
        // 기기 언어가 아래 목록에 없으면 영어로 나온다.
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [
          Locale('ko'),
          Locale('en'),
          Locale('ja'),
          Locale('zh'),
          Locale('es'),
          Locale('fr'),
          Locale('de'),
        ],
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: mode,
        home: _AppShell(currentMode: mode),
      ),
    );
  }

  // 라이트/다크 공통 테마. 색은 AppColors에서 가져온다
  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.gradStart,
        brightness: brightness,
      ),
      useMaterial3: true,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      ),
    );
  }
}

class _AppShell extends StatelessWidget {
  final ThemeMode currentMode;
  const _AppShell({required this.currentMode});

  // 설정 화면에서 테마를 바꾸면 화면에 바로 반영하고 저장도 해 둔다
  void _changeTheme(ThemeMode mode) {
    _themeModeNotifier.value = mode;
    SettingsStorage.setThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    return HomeScreen(currentMode: currentMode, onThemeChanged: _changeTheme);
  }
}
