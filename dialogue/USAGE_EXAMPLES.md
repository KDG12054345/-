# 🎮 DialogueIndex 사용 예시

DialogueIndex 서비스를 사용하여 인카운터를 로드하고 관리하는 방법입니다.

## 📚 기본 사용법

### 1. 시작 인카운터 로드 (게임 시작 시)

```dart
// EncounterController에서 사용
Future<String?> _loadStartEncounter() async {
  final entries = await DialogueIndex.instance.getStartEncounters();
  
  if (entries.isEmpty) return null;
  
  // 가중치 기반 랜덤 선택은 자동으로 처리됨
  final random = Random();
  final totalWeight = entries.fold<int>(0, (sum, e) => sum + e.weight);
  int value = random.nextInt(totalWeight);
  
  for (final entry in entries) {
    value -= entry.weight;
    if (value < 0) return entry.path;
  }
  
  return entries.first.path;
}

// 사용 예시
final startPath = await _loadStartEncounter();
await dialogueEngine.loadDialogue(startPath);
```

### 2. 랜덤 인카운터 발생

```dart
// 모든 카테고리에서 가중치 기반 랜덤 선택
Future<void> triggerRandomEncounter() async {
  final encounterPath = await DialogueIndex.instance.selectRandomEncounter();
  
  if (encounterPath != null) {
    final engine = DialogueEngine();
    await engine.loadDialogue(encounterPath);
    await engine.start();
    
    // UI 업데이트
    final view = engine.getCurrentView();
    // ...
  }
}
```

### 3. 특정 카테고리 인카운터 선택

```dart
// 함정 인카운터만
Future<void> triggerTrap() async {
  final trapPath = await DialogueIndex.instance
      .selectRandomEncounterFromCategory('trap');
  
  if (trapPath != null) {
    await _loadAndStartEncounter(trapPath);
  }
}

// 전투 인카운터만
Future<void> triggerCombat() async {
  final combatPath = await DialogueIndex.instance
      .selectRandomEncounterFromCategory('combat');
  
  if (combatPath != null) {
    await _loadAndStartEncounter(combatPath);
  }
}

// 만남 인카운터만
Future<void> triggerMeeting() async {
  final meetingPath = await DialogueIndex.instance
      .selectRandomEncounterFromCategory('meeting');
  
  if (meetingPath != null) {
    await _loadAndStartEncounter(meetingPath);
  }
}

Future<void> _loadAndStartEncounter(String path) async {
  final engine = DialogueEngine();
  await engine.loadDialogue(path);
  await engine.start();
  // ...
}
```

### 4. 메인 스토리 진행

```dart
// 메인 스토리 인카운터 목록 가져오기
Future<void> loadMainStory() async {
  final mainEncounters = await DialogueIndex.instance.getMainEncounters();
  
  // 조건에 맞는 인카운터 찾기
  for (final encounter in mainEncounters) {
    // unlockConditions 체크 (직접 구현 필요)
    if (await _checkUnlockConditions(encounter)) {
      await _loadAndStartEncounter(encounter.path);
      break;
    }
  }
}

Future<bool> _checkUnlockConditions(DialogueIndexEntry entry) async {
  // index.json의 unlockConditions를 체크하는 로직
  // 예: flags, stats, items 등 확인
  return true; // 구현 필요
}
```

## 🎲 고급 사용법

### 확률 조정 시스템

```dart
class EncounterManager {
  // 플레이어 상태에 따라 카테고리 확률 동적 조정
  Future<String?> selectContextualEncounter({
    required int playerLevel,
    required int currentDanger,
  }) async {
    String category;
    
    // 위험도가 높으면 전투 확률 증가
    if (currentDanger > 70) {
      category = Random().nextBool() ? 'combat' : 'trap';
    }
    // 안전한 지역이면 만남 확률 증가
    else if (currentDanger < 30) {
      category = 'meeting';
    }
    // 중간 지역은 랜덤
    else {
      final path = await DialogueIndex.instance.selectRandomEncounter();
      return path;
    }
    
    return await DialogueIndex.instance
        .selectRandomEncounterFromCategory(category);
  }
}
```

### 인카운터 빈도 제어

```dart
class EncounterFrequencyManager {
  final Map<String, DateTime> _lastEncounters = {};
  final Duration _cooldown = Duration(minutes: 5);
  
  Future<String?> selectWithCooldown() async {
    final allCategories = ['trap', 'combat', 'meeting'];
    final availableCategories = <String>[];
    
    final now = DateTime.now();
    for (final category in allCategories) {
      final lastTime = _lastEncounters[category];
      if (lastTime == null || now.difference(lastTime) > _cooldown) {
        availableCategories.add(category);
      }
    }
    
    if (availableCategories.isEmpty) {
      return null; // 모든 카테고리가 쿨다운 중
    }
    
    // 사용 가능한 카테고리 중에서 랜덤 선택
    final category = availableCategories[
      Random().nextInt(availableCategories.length)
    ];
    
    _lastEncounters[category] = now;
    
    return await DialogueIndex.instance
        .selectRandomEncounterFromCategory(category);
  }
}
```

### 모든 인카운터 정보 가져오기

```dart
// 디버깅이나 관리 UI에서 사용
Future<void> debugPrintAllEncounters() async {
  print('=== Start Encounters ===');
  final startEncounters = await DialogueIndex.instance.getStartEncounters();
  for (final e in startEncounters) {
    print('${e.path} (weight: ${e.weight})');
  }
  
  print('\n=== Main Story ===');
  final mainEncounters = await DialogueIndex.instance.getMainEncounters();
  for (final e in mainEncounters) {
    print('${e.path} (weight: ${e.weight})');
  }
  
  print('\n=== Random Encounters ===');
  final allRandom = await DialogueIndex.instance.getAllRandomEncounters();
  
  for (final category in allRandom.keys) {
    print('\n[$category]');
    for (final e in allRandom[category]!) {
      print('  ${e.path} (weight: ${e.weight})');
    }
  }
}
```

### 캐시 관리

```dart
// 새로운 인카운터 파일을 추가한 후
void reloadEncounters() {
  DialogueIndex.instance.clearCache();
  
  // 다음 호출 시 파일을 다시 로드함
}

// 또는 앱 시작 시
void initializeApp() {
  // 이전 세션의 캐시 제거
  DialogueIndex.instance.clearCache();
}
```

## 🎯 실전 예제

### 게임 루프에 통합

```dart
class GameLoop {
  int _stepCount = 0;
  final int _encounterFrequency = 10; // 10걸음마다
  
  Future<void> onPlayerMove() async {
    _stepCount++;
    
    if (_stepCount >= _encounterFrequency) {
      _stepCount = 0;
      await _triggerRandomEncounter();
    }
  }
  
  Future<void> _triggerRandomEncounter() async {
    final path = await DialogueIndex.instance.selectRandomEncounter();
    
    if (path != null) {
      final engine = DialogueEngine();
      await engine.loadDialogue(path);
      await engine.start();
      
      // 게임 일시 정지하고 인카운터 UI 표시
      _showEncounterUI(engine);
    }
  }
  
  void _showEncounterUI(DialogueEngine engine) {
    // UI 구현
  }
}
```

### 지역별 인카운터 테이블

```dart
class LocationBasedEncounters {
  final Map<String, List<String>> _locationCategories = {
    'forest': ['trap', 'combat'],       // 숲: 함정, 전투
    'town': ['meeting'],                // 마을: 만남
    'dungeon': ['trap', 'combat'],      // 던전: 함정, 전투
    'road': ['meeting', 'combat'],      // 길: 만남, 전투
  };
  
  Future<String?> selectForLocation(String location) async {
    final categories = _locationCategories[location];
    if (categories == null || categories.isEmpty) {
      return null;
    }
    
    // 해당 지역에서 가능한 카테고리 중 랜덤 선택
    final category = categories[Random().nextInt(categories.length)];
    
    return await DialogueIndex.instance
        .selectRandomEncounterFromCategory(category);
  }
}
```

## 📝 참고사항

- 모든 메서드는 `async`이므로 `await` 필요
- 경로가 `null`일 수 있으므로 null 체크 필수
- 캐시는 자동으로 관리되지만 필요시 `clearCache()` 호출
- `index.json` 파일 수정 시 앱 재시작 또는 캐시 초기화 필요



