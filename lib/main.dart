import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'storage/settings_storage.dart';
import 'theme/app_theme.dart';

final _themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));
  try {
    await NotificationService.initialize();
  } catch (_) {}
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
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: mode,
        home: _AppShell(currentMode: mode),
      ),
    );
  }

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

  void _changeTheme(ThemeMode mode) {
    _themeModeNotifier.value = mode;
    SettingsStorage.setThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    return HomeScreen(
      currentMode: currentMode,
      onThemeChanged: _changeTheme,
    );
  }
}
