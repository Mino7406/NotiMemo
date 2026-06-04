import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
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
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
        indicatorColor: AppColors.gradStart.withAlpha(isDark ? 45 : 30),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? AppColors.gradStart
                : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? AppColors.gradStart
                : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
            size: 22,
          );
        }),
      ),
    );
  }
}

class _AppShell extends StatefulWidget {
  final ThemeMode currentMode;
  const _AppShell({required this.currentMode});

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  int _index = 0;

  void _changeTheme(ThemeMode mode) {
    _themeModeNotifier.value = mode;
    SettingsStorage.setThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.bgDark : AppColors.bgLight,
      body: IndexedStack(
        index: _index,
        children: [
          const HomeScreen(),
          SettingsScreen(
            currentMode: widget.currentMode,
            onThemeChanged: _changeTheme,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        elevation: 0,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: '설정',
          ),
        ],
      ),
    );
  }
}
