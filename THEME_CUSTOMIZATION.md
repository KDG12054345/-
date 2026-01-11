# Fantasy Life - 테마 커스터마이징 가이드

## 개요
Fantasy Life는 확장성과 유지보수성을 고려하여 설계된 테마 시스템을 제공합니다. 이 가이드를 통해 배경, 폰트, 색상 등을 쉽게 변경할 수 있습니다.

## 📁 프로젝트 구조

```
lib/
├── app/
│   └── app_wrapper.dart          # 앱 상태 관리 및 화면 라우팅
├── screens/
│   ├── start_screen.dart         # 게임 시작 화면
│   └── game_screen.dart          # 메인 게임 화면
├── theme/
│   └── app_theme.dart            # 테마 설정 및 색상 정의
└── main.dart                     # 앱 진입점
```

## 🎨 테마 커스터마이징

### 1. 색상 변경
`lib/theme/app_theme.dart` 파일에서 색상을 변경할 수 있습니다:

```dart
class AppTheme {
  // 기본 색상 팔레트
  static const Color primaryDark = Color(0xFF1a0d2e);    // 배경 어두운 색
  static const Color primaryNavy = Color(0xFF16213e);    // 배경 중간 색
  static const Color primaryBlue = Color(0xFF0f3460);    // 배경 밝은 색
  static const Color accentGold = Color(0xFFffd700);     // 강조 색상 1
  static const Color accentOrange = Color(0xFFffa500);   // 강조 색상 2
}
```

### 2. 배경 이미지 설정
배경 이미지를 사용하려면:

1. `assets/images/` 폴더에 이미지 파일 추가
2. `pubspec.yaml`에 assets 경로 추가:
```yaml
flutter:
  assets:
    - assets/images/
```
3. `ThemeConfig`에서 배경 이미지 경로 설정:
```dart
const ThemeConfig(
  backgroundImagePath: 'assets/images/background.jpg',
)
```

### 3. 폰트 변경

#### 3.1 폰트 파일 추가
1. `assets/fonts/` 폴더에 폰트 파일(.ttf, .otf) 추가
2. `pubspec.yaml`에 폰트 정의:
```yaml
flutter:
  fonts:
    - family: CustomFont
      fonts:
        - asset: assets/fonts/CustomFont-Regular.ttf
        - asset: assets/fonts/CustomFont-Bold.ttf
          weight: 700
```

#### 3.2 앱에서 폰트 적용
```dart
const ThemeConfig(
  fontFamily: 'CustomFont',
)
```

### 4. 타이틀 크기 조정
```dart
const ThemeConfig(
  titleSize: 60.0,  // 기본값: 48.0
)
```

### 5. 애니메이션 비활성화
```dart
const ThemeConfig(
  enableAnimations: false,  // 기본값: true
)
```

## 🛠️ 개발자를 위한 확장 가이드

### 새로운 화면 추가
1. `lib/app/app_wrapper.dart`의 `AppScreen` enum에 새 화면 추가
2. `_buildCurrentScreen` 메서드에 새 화면 케이스 추가
3. `lib/screens/` 폴더에 새 화면 위젯 생성

### 새로운 테마 속성 추가
1. `ThemeConfig` 클래스에 새 속성 추가
2. `AppTheme` 클래스에 관련 상수 정의
3. 해당 위젯에서 테마 속성 사용

### 설정 메뉴 기능 구현
`lib/app/app_wrapper.dart`의 `_buildSettingsScreen` 메서드에서 각 설정 타일의 `onTap` 콜백을 구현하세요:

```dart
_buildSettingTile(
  '배경 이미지',
  '게임 배경을 변경합니다',
  Icons.image,
  () {
    // 이미지 선택 및 테마 업데이트 로직
    appState.updateTheme(newThemeConfig);
  },
),
```

## 🎯 예제: 다크 모드 테마 만들기

```dart
// lib/theme/dark_theme.dart
class DarkTheme {
  static const ThemeConfig darkConfig = ThemeConfig(
    primaryColor: Color(0xFF000000),
    accentColor: Color(0xFF00ff00),
    fontFamily: 'Courier',
    titleSize: 52.0,
    enableAnimations: true,
  );
}
```

## 💡 팁

1. **성능 최적화**: 큰 배경 이미지 사용 시 적절한 해상도로 최적화하세요
2. **폰트 크기**: 다양한 화면 크기를 고려하여 반응형 폰트 크기를 설정하세요
3. **색상 접근성**: 충분한 대비를 가진 색상을 선택하세요
4. **애니메이션**: 저사양 기기에서는 애니메이션을 비활성화할 수 있는 옵션을 제공하세요

## 🔧 문제 해결

### 폰트가 적용되지 않는 경우
1. `pubspec.yaml`에 폰트가 정확히 정의되었는지 확인
2. `flutter clean && flutter pub get` 실행
3. 앱 재시작

### 배경 이미지가 보이지 않는 경우
1. 이미지 파일 경로가 올바른지 확인
2. `pubspec.yaml`에 assets 경로가 포함되었는지 확인
3. 이미지 파일 형식이 지원되는지 확인 (.jpg, .png, .gif)

이 가이드를 통해 Fantasy Life의 외관을 원하는 대로 커스터마이징할 수 있습니다!

## 📁 제안하는 dialogue 폴더 구조

```
assets/dialogue/
├── start/
│   ├── victory_for_you.json
│   ├── character_intro.json
│   └── tutorial.json
├── main/
│   ├── chapter1.json
│   ├── chapter2.json
│   ├── chapter3.json
│   └── story_events.json
├── repeat/
│   ├── daily_events.json
│   ├── random_encounters.json
│   ├── merchant_visits.json
│   └── common_interactions.json
└── sample_dialogue.json (기존 호환용)
```

## 📝 구현 계획

### 1단계: 폴더 생성 및 파일 배치

**`assets/dialogue/start/victory_for_you.json`** 생성:
```json
{
  "scene_1": {
    "start": {
      "text": "모험을 시작하는 그대에게\n\n그대에겐 그대만을 위한 승리가 있다 \n그러니 그대를 방해하는 모든 계단과 탑은 무너져도 좋으리.\n높은 언덕과 거친 파도를 지나 \n멀리 구멍난 깃발이 나부끼는 저녁\n\n그대는 철혈같은 왕좌에 앉아 이렇게 말할 것이다.\n\n그렇게도 나의 그늘이 궁금한가?",
      "events": [
        { "type": "SET_FLAG", "data": { "flag": "run.startedFrom.start.victory_for_you", "value": true } }
      ]
    },
    "choices": {}
  }
}
```

### 2단계: 게임 화면 수정

```dart:lib/screens/game_screen.dart
// 20번째 라인 수정
dialogueManager.loadDialogue('assets/dialogue/start/victory_for_you.json');
```

### 3단계: pubspec.yaml 에셋 등록

```yaml:pubspec.yaml
flutter:
  assets:
    - assets/dialogue/
    - assets/dialogue/start/
    - assets/dialogue/main/
    - assets/dialogue/repeat/
```

## 🎯 각 폴더의 역할

### 📂 **start/** - 시작
- 게임 첫 시작 시 나오는 인카운터들
- 캐릭터 생성, 튜토리얼, 시작 스토리

### 📂 **main/** - 메인
- 주요 스토리 라인
- 챕터별 진행 스토리
- 중요한 이벤트들

### 📂 **repeat/** - 반복
- 반복적으로 발생하는 이벤트들
- 랜덤 인카운터
- 일상적인 상호작용

이 구조로 진행하시겠어요?
