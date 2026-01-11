import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/start_screen.dart';
import '../screens/game_screen.dart';
import '../dialogue_manager.dart';
import '../simple_dialogue_manager_v2.dart';
import '../inventory/inventory_system.dart';
import '../inventory/bootstrap_noninvasive.dart';
import '../autosave/bootstrap.dart' show createDialogueManager;
import '../theme/app_theme.dart';
// ⭐⭐⭐⭐⭐ Dependency Injection + Interface Segregation 구현
import '../core/game_controller.dart';
import '../modules/encounter/encounter_module.dart';
import '../modules/combat/combat_module.dart';
import '../modules/reward/reward_module.dart';
import '../modules/character_creation/character_creation_module.dart';
import '../modules/xp/xp_module.dart'; // 🆕 XP 시스템

enum AppScreen {
  start,
  game,
  settings,
  credits,
}

class AppState extends ChangeNotifier {
  AppScreen _currentScreen = AppScreen.start;
  ThemeConfig _themeConfig = const ThemeConfig();
  
  AppScreen get currentScreen => _currentScreen;
  ThemeConfig get themeConfig => _themeConfig;
  
  void navigateToScreen(AppScreen screen) {
    _currentScreen = screen;
    notifyListeners();
  }
  
  void updateTheme(ThemeConfig newConfig) {
    _themeConfig = newConfig;
    notifyListeners();
  }
  
  void startGame() {
    navigateToScreen(AppScreen.game);
  }
  
  void returnToStart() {
    navigateToScreen(AppScreen.start);
  }
}

class AppWrapper extends StatelessWidget {
  const AppWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AppState()),
        ChangeNotifierProvider<DialogueManager>(
          create: (_) => createDialogueManager(),
        ),
        ChangeNotifierProvider(create: (context) => SimpleDialogueManagerV2()),
        // ⭐⭐⭐⭐⭐ 캐릭터 생성 모듈 추가
        ChangeNotifierProvider<GameController>(
          create: (_) => GameController(modules: [
            CharacterCreationModule(), // 캐릭터 생성 모듈 추가
            XpModule(),                 // 🆕 XP 및 마일스톤 처리
            EncounterModule(),          // 인카운터 처리
            CombatModule(),             // 전투 처리  
            RewardModule(),             // 보상 처리
          ]),
        ),
        Provider<InventorySystem>.value(
          value: createInventoryWithFootprintPlacement(
            InventorySystem(width: 9, height: 6),  // 9x6 = 54칸 격자
          ),
        ),
      ],
      child: Consumer<AppState>(
        builder: (context, appState, child) {
          return MaterialApp(
            title: 'Fantasy Life',
            theme: _buildThemeData(appState.themeConfig),
            home: _buildCurrentScreen(appState),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }

  ThemeData _buildThemeData(ThemeConfig config) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: config.primaryColor,
        brightness: Brightness.dark,
      ),
      // 한글 글리프 지원을 위한 안전한 폰트 설정 제거
      // fontFamily 지정하지 않아 시스템 기본 폰트 사용
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 2,
        ),
        displayMedium: TextStyle(
          fontSize: 18,
          color: Colors.white70,
          fontWeight: FontWeight.w300,
        ),
        labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentScreen(AppState appState) {
    switch (appState.currentScreen) {
      case AppScreen.start:
        return StartScreen(
          onStartGame: () => appState.startGame(),
          themeConfig: appState.themeConfig,
        );
      case AppScreen.game:
        return const GameScreen();
      case AppScreen.settings:
        return _buildSettingsScreen(appState);
      case AppScreen.credits:
        return _buildCreditsScreen(appState);
    }
  }

  Widget _buildSettingsScreen(AppState appState) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: const Text('설정'),
                backgroundColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => appState.returnToStart(),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSettingTile(
                      '배경 이미지',
                      '게임 배경을 변경합니다',
                      Icons.image,
                      () {
                        // TODO: 배경 이미지 선택 구현
                      },
                    ),
                    _buildSettingTile(
                      '폰트 설정',
                      '게임 폰트를 변경합니다',
                      Icons.text_fields,
                      () {
                        // TODO: 폰트 선택 구현
                      },
                    ),
                    _buildSettingTile(
                      '색상 테마',
                      '게임 색상 테마를 변경합니다',
                      Icons.palette,
                      () {
                        // TODO: 색상 테마 선택 구현
                      },
                    ),
                    _buildSettingTile(
                      '애니메이션',
                      '애니메이션 효과를 설정합니다',
                      Icons.animation,
                      () {
                        // TODO: 애니메이션 설정 구현
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreditsScreen(AppState appState) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: const Text('제작진'),
                backgroundColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => appState.returnToStart(),
                ),
              ),
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Fantasy Life',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentGold,
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Made with Flutter',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      color: Colors.white.withOpacity(0.1),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.accentGold),
        title: Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: AppTheme.textSecondary,
        ),
        onTap: onTap,
      ),
    );
  }
}
