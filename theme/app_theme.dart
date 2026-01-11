import 'package:flutter/material.dart';

class AppTheme {
  // 기본 색상 팔레트 - 쉽게 변경 가능
  static const Color primaryDark = Color(0xFF1a0d2e);
  static const Color primaryNavy = Color(0xFF16213e);
  static const Color primaryBlue = Color(0xFF0f3460);
  static const Color accentGold = Color(0xFFffd700);
  static const Color accentOrange = Color(0xFFffa500);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFffffff80); // 50% opacity
  
  // 그라디언트 정의
  static const Gradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryDark, primaryNavy, primaryBlue],
  );
  
  static const Gradient buttonGradient = LinearGradient(
    colors: [accentGold, accentOrange],
  );
  
  // 폰트 사이즈 정의
  static const double titleFontSize = 48;
  static const double subtitleFontSize = 18;
  static const double buttonFontSize = 22;
  static const double bodyFontSize = 16;
  
  // 그림자 효과
  static List<Shadow> get titleShadow => [
    const Shadow(
      offset: Offset(2, 2),
      blurRadius: 8,
      color: primaryDark,
    ),
  ];
  
  static List<BoxShadow> get glowShadow => [
    BoxShadow(
      color: accentGold.withOpacity(0.3),
      blurRadius: 20,
      spreadRadius: 5,
    ),
  ];
  
  static List<BoxShadow> get buttonShadow => [
    BoxShadow(
      color: accentGold.withOpacity(0.4),
      blurRadius: 15,
      offset: const Offset(0, 5),
    ),
  ];
  
  // 애니메이션 지속 시간
  static const Duration fadeInDuration = Duration(seconds: 2);
  static const Duration buttonAnimationDuration = Duration(milliseconds: 200);
  
  // 테마 데이터 생성
  static ThemeData get themeData => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.dark,
    ),
    fontFamily: 'NanumGothic',
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: titleFontSize,
        fontWeight: FontWeight.bold,
        color: accentGold,
        letterSpacing: 3,
      ),
      displayMedium: TextStyle(
        fontSize: subtitleFontSize,
        color: textSecondary,
        fontWeight: FontWeight.w300,
        letterSpacing: 1,
      ),
      labelLarge: TextStyle(
        fontSize: buttonFontSize,
        fontWeight: FontWeight.bold,
        color: primaryDark,
        letterSpacing: 1,
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

// 설정 가능한 테마 설정 클래스
class ThemeConfig {
  final String backgroundImagePath;
  final String fontFamily;
  final Color primaryColor;
  final Color accentColor;
  final double titleSize;
  final bool enableAnimations;
  
  const ThemeConfig({
    this.backgroundImagePath = '',
    this.fontFamily = 'NanumGothic',
    this.primaryColor = AppTheme.primaryDark,
    this.accentColor = AppTheme.accentGold,
    this.titleSize = AppTheme.titleFontSize,
    this.enableAnimations = true,
  });
  
  // 나중에 JSON에서 로드할 수 있도록
  factory ThemeConfig.fromJson(Map<String, dynamic> json) {
    return ThemeConfig(
      backgroundImagePath: json['backgroundImagePath'] ?? '',
      fontFamily: json['fontFamily'] ?? 'NanumGothic',
      primaryColor: Color(json['primaryColor'] ?? 0xFF1a0d2e),
      accentColor: Color(json['accentColor'] ?? 0xFFffd700),
      titleSize: (json['titleSize'] ?? 48).toDouble(),
      enableAnimations: json['enableAnimations'] ?? true,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'backgroundImagePath': backgroundImagePath,
      'fontFamily': fontFamily,
      'primaryColor': primaryColor.value,
      'accentColor': accentColor.value,
      'titleSize': titleSize,
      'enableAnimations': enableAnimations,
    };
  }
}
