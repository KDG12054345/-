# QA 테스트 가이드

## 🎯 Headless 전투 로직 테스트

UI 없이 순수 게임 로직만 테스트합니다.

### 1. 전투 스모크 테스트 실행

```bash
dart run lib/qa/scenarios/combat_test.dart
```

**테스트 내용:**
- Seed 12345로 게임 초기화
- 전투 강제 진입
- 10초간 전투 진행 (100ms × 100 tick)
- HP 변화 검증

**성공 시 출력:**
```
============================================================
전투 로직 스모크 테스트 (Gate-1)
============================================================

[Step 1] 게임 초기화 (Seed: 12345)...
✅ 게임 초기화 완료

[Step 2] 전투 강제 진입...
✅ 전투 진입 완료

[Step 3] 전투 상태 검증...
✅ 전투 상태 검증 완료

[Step 4] 시간 진행 (100ms × 100회 = 10초)...
✅ 시간 진행 완료

[Step 5] HP 변화 검증...
✅ HP 변화 검증 완료

============================================================
✅ 테스트 성공!
============================================================
```

### 2. 커스텀 테스트 작성

`lib/qa/scenarios/` 폴더에 새로운 테스트 스크립트를 작성할 수 있습니다.

**예시: 장시간 전투 테스트**

```dart
// lib/qa/scenarios/long_combat_test.dart
import 'dart:io';
import '../harness.dart';

Future<void> main() async {
  print('장시간 전투 테스트 (60초)');
  
  final harness = HeadlessTestHarness();
  
  try {
    // 초기화
    await harness.initialize(99999);
    
    // 강한 적과 전투
    await harness.forceEnterCombat(
      enemyStats: {
        'maxHealth': 500,
        'attackPower': 5,
        'accuracy': 60,
      },
      enemyName: '강력한 적',
    );
    
    // 60초 진행 (100ms × 600회)
    for (int i = 0; i < 600; i++) {
      await harness.tick(100);
      
      // 5초마다 상태 출력
      if ((i + 1) % 50 == 0) {
        final vm = harness.controller?.vm;
        if (vm?.combat != null) {
          print('[${(i + 1) / 10}초] '
              'Player HP: ${vm!.combat!.player?.currentHealth}, '
              'Enemy HP: ${vm.combat!.enemy?.currentHealth}');
        }
      }
      
      // 전투 종료 체크
      if (harness.controller?.vm.combat?.isCombatOver ?? false) {
        print('전투 종료!');
        break;
      }
    }
    
    // 상태 덤프 저장
    final dumpPath = await harness.saveDumpToFile(
      'qa/dumps/long_combat_${DateTime.now().millisecondsSinceEpoch}.json'
    );
    print('상태 덤프 저장: $dumpPath');
    
    print('✅ 테스트 완료');
    exit(0);
    
  } catch (e, stackTrace) {
    print('❌ 테스트 실패: $e');
    print(stackTrace);
    exit(1);
  } finally {
    harness.dispose();
  }
}
```

실행:
```bash
dart run lib/qa/scenarios/long_combat_test.dart
```

## 🧪 Flutter Widget 테스트

전투 화면 UI를 테스트합니다.

### 1. 전투 화면 위젯 테스트 작성

```dart
// test/combat_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:text/core/game_controller.dart';
import 'package:text/screens/combat_screen.dart';
import 'package:text/modules/character_creation/character_creation_module.dart';
import 'package:text/modules/combat/combat_module.dart';

void main() {
  testWidgets('전투 화면이 정상적으로 렌더링됨', (WidgetTester tester) async {
    // GameController 생성
    final controller = GameController(
      modules: [
        CharacterCreationModule(),
        CombatModule(),
      ],
    );
    
    // 전투 화면 빌드
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<GameController>.value(
          value: controller,
          child: const CombatScreen(),
        ),
      ),
    );
    
    // 텍스트 확인
    expect(find.text('전투 데이터 없음'), findsOneWidget);
  });
}
```

실행:
```bash
flutter test test/combat_screen_test.dart
```

## 📱 실제 앱 실행 테스트

### 1. 일반 실행 (Prod 빌드)

```bash
flutter run --flavor prod
```

### 2. QA 빌드 실행

```bash
flutter run --flavor qa --dart-define=IS_QA=true
```

### 3. 특정 시나리오 강제 실행

`lib/main_qa.dart`를 수정하여 특정 시나리오를 바로 실행할 수 있습니다.

```dart
// lib/main_qa.dart
import 'package:flutter/material.dart';
import 'qa/harness.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🧪 QA 모드로 실행 중...');
  
  // Headless 테스트 실행
  final harness = HeadlessTestHarness();
  
  try {
    await harness.initialize(12345);
    await harness.forceEnterCombat();
    
    // 5초간 전투
    for (int i = 0; i < 50; i++) {
      await harness.tick(100);
    }
    
    print('✅ QA 테스트 완료');
    print(harness.dumpState());
    
  } finally {
    harness.dispose();
  }
  
  runApp(const QaApp());
}

class QaApp extends StatelessWidget {
  const QaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fantasy Life QA',
      home: Scaffold(
        appBar: AppBar(title: const Text('QA 테스트 완료')),
        body: const Center(
          child: Text('로그를 확인하세요'),
        ),
      ),
    );
  }
}
```

실행:
```bash
flutter run -t lib/main_qa.dart --flavor qa
```

## 🔍 디버깅 팁

### 1. 상태 덤프 저장

전투 중 특정 시점의 상태를 JSON으로 저장:

```dart
final dumpPath = await harness.saveDumpToFile('qa/dumps/state.json');
```

### 2. 로그 레벨 조정

`lib/qa/harness.dart`의 `_log()` 메서드를 수정하여 더 상세한 로그 출력:

```dart
void _log(String message, {String level = 'INFO'}) {
  final timeStr = (_gameTimeMs / 1000.0).toStringAsFixed(2);
  print('[$level][HeadlessTestHarness][$_runId][${timeStr}s] $message');
}
```

### 3. 조건부 중단점

특정 조건에서 테스트를 중단:

```dart
// 테스트 중 특정 조건 체크
if (harness.controller?.vm.combat?.player?.currentHealth == 0) {
  print('플레이어 사망! 덤프 저장 중...');
  await harness.saveDumpToFile('qa/dumps/player_death.json');
  exit(1);
}
```

## 📊 테스트 결과 분석

### JSON 덤프 예시

```json
{
  "meta": {
    "run_id": "18a3b2c1-123456-3039",
    "seed": 12345,
    "timestamp": "2025-01-27T15:30:45.123Z"
  },
  "state": {
    "phase": "AppPhase.inGame_combat",
    "player": {
      "hp": 75,
      "maxHp": 100,
      "stamina": 3.5,
      "maxStamina": 5.0,
      "effects": ["bleeding"]
    },
    "enemy": {
      "hp": 60,
      "maxHp": 100,
      "id": "테스트 적",
      "stamina": 4.2,
      "effects": []
    },
    "combat": {
      "turn_timer": 10.0,
      "isActive": true,
      "isCombatOver": false,
      "playerWon": false
    }
  }
}
```

## 🚀 CI/CD 통합

GitHub Actions에서 자동으로 테스트 실행:

```yaml
# .github/workflows/test.yml
name: QA Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
      
      - name: Run Headless Combat Test
        run: dart run lib/qa/scenarios/combat_test.dart
      
      - name: Run Flutter Tests
        run: flutter test
```

## 💡 추천 테스트 순서

1. ✅ **Headless 스모크 테스트** (가장 빠름, 로직 검증)
   ```bash
   dart run lib/qa/scenarios/combat_test.dart
   ```

2. ✅ **Widget 테스트** (UI 컴포넌트 검증)
   ```bash
   flutter test
   ```

3. ✅ **통합 테스트** (전체 플로우 검증)
   ```bash
   flutter test integration_test/
   ```

4. ✅ **수동 테스트** (실제 디바이스/시뮬레이터)
   ```bash
   flutter run --flavor qa
   ```


