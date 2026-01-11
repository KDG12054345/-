# RunState vs MetaProfile 리팩터링 계획

## [1단계] 코드베이스 현황 분석 ✅

### 1.1 GameController 및 이벤트 흐름
- **위치**: `lib/core/game_controller.dart`
- **생성 시점**: `AppWrapper`에서 Provider로 생성
- **자동 StartGame**: 생성자에서 `Future.microtask(() => dispatch(const StartGame()))`
- **이벤트 시스템**: `GEvent` 기반 (레거시 `EventSystem`은 deprecated)
- **문제점**: 한 번 생성되면 재사용됨 → RunState가 남을 수 있음

### 1.2 DialogueManager / AutosaveDialogueManager
- **위치**: 
  - `lib/dialogue_manager.dart` (기본 클래스)
  - `lib/autosave/autosave_dialogue_manager.dart` (실제 사용)
- **책임**:
  - 대화/인카운터 관리 (실제로는 EncounterModule이 담당)
  - 플레이어 정보 보관 (`getCurrentPlayer()`)
  - 저장/로드는 AutosaveDialogueManager에서 처리
- **저장 구조**: `AutosaveSystem` → `autosave.json`
  - stats, items, flags, currentScene, branchHistory 저장
  - **Player 데이터는 현재 저장 안 됨!**
- **문제점**: 회차가 바뀌어도 같은 인스턴스 재사용

### 1.3 Provider/싱글톤 시스템
```dart
// AppWrapper에서 관리되는 시스템들:
- AppState (화면 네비게이션)
- InventorySystem (Provider.value로 단일 인스턴스)
- DialogueManager (ChangeNotifierProxyProvider)
- GameController (ChangeNotifierProxyProvider, 재사용)
```

**문제점**: 모두 재사용되므로 명시적 reset 필요

### 1.4 인카운터 선택 로직
- **핵심 클래스**: `EncounterScheduler`
- **선택 방식**:
  1. Milestone 큐에서 dequeue
  2. Theme/Story/Repeat 중 선택
  3. Config 파일 기반 (poolByStart, sequence 등)
- **현재 메타데이터**: `xp` (1-3)
- **필터링 없음**: requiredMetaFlags 같은 개념 없음

### 1.5 Effect / 선택 결과 처리
- **DialogueEngine**: 대화 선택 처리
- **EncounterController**: 인카운터 결과 처리
- **Effect 처리**: 명시적인 Effect 시스템은 없음
  - 대화 선택 후 결과는 DialogueEngine이 처리
  - 전투 결과는 CombatModule이 처리
  - XP는 XpModule이 처리

---

## [2단계] RunState vs MetaProfile 설계

### 2.1 RunState (매 회차 초기화)
```dart
class RunState {
  // UI 상태
  String? text;
  List<ChoiceVM> choices;
  String? currentEncounterId;
  AppPhase phase;
  
  // 전투 상태
  CombatState? combat;
  String? victoryScenePath;
  String? defeatScenePath;
  
  // 플레이어 회차 상태
  Player? player;  // HP, 정신력, 능력치, 특성
  InventorySystem inventory;  // 아이템, 상처/저주
  
  // 진행도
  int currentSlot;
  List<String> epilogueLog;
  
  // DialogueManager 상태
  String currentScene;
  Map<String, dynamic> localVariables;
  // ... 기타 대화 관련 상태
}
```

### 2.2 MetaProfile (회차 간 유지)
```dart
class MetaProfile {
  // 기본 메타 정보
  int runCount;  // 총 회차 수
  DateTime? lastPlayedAt;
  
  // 언락 시스템
  Set<String> unlockedFlags;  // "unlocked_merfolk_capital" 등
  
  // 도감/통계
  Map<String, int> seenEncounterCount;  // 인카운터별 본 횟수
  Set<String> seenEndings;  // 본 엔딩 목록
  
  // (선택적) 업적, 설정 등
}
```

### 2.3 저장 구조
```
saves/
  ├── autosave.json     (RunState - 현재 회차 재개용)
  └── meta.json         (MetaProfile - 회차 간 유지)
```

---

## [3단계] StartGame 리팩터링 계획

### 3.1 초기화 순서 재정의
```
현재: GameController 생성 → 자동 StartGame

변경 후:
1. AppWrapper에서 MetaProfile 먼저 로드
2. GameController 생성 (자동 StartGame 제거)
3. StartScreen에서 "게임 시작" 클릭
4. StartGame 이벤트 dispatch
5. RunState 완전 초기화
6. MetaProfile.runCount++
```

### 3.2 필요한 reset 메서드
- `InventorySystem.resetForNewRun()`
- `DialogueManager.resetForNewRun()` (또는 AutosaveDialogueManager)
- `EncounterScheduler.reset()` (milestone 큐 초기화)

### 3.3 StartGame 이벤트 처리 변경
```dart
// lib/core/state/reducer.dart
} else if (e is StartGame) {
  // 완전히 새로운 GameVM 생성 (모든 필드 초기화)
  next = const GameVM(
    phase: AppPhase.inGame_characterCreation,
    loading: true,
    error: null,
    // 나머지 모두 기본값 (null)
  );
}
```

---

## [4단계] 인카운터 언락 시스템

### 4.1 Effect 확장
```jsonc
// 인카운터 JSON에 새 effect 타입 추가
{
  "type": "unlock_meta",
  "flag": "unlocked_merfolk_capital"
}
```

### 4.2 인카운터 메타데이터 확장
```jsonc
// 인카운터 JSON metadata
{
  "id": "enc_merfolk_capital",
  "metadata": {
    "xp": 2,
    "requiredMetaFlags": ["unlocked_merfolk_capital"]  // 새로 추가
  }
}
```

### 4.3 EncounterScheduler 필터링
```dart
// 인카운터 선택 시 MetaProfile 확인
List<String> filterByMetaFlags(
  List<String> pool,
  MetaProfile metaProfile,
) {
  return pool.where((encId) {
    final metadata = getEncounterMetadata(encId);
    final required = metadata?['requiredMetaFlags'] as List?;
    if (required == null) return true;
    return required.every((flag) => metaProfile.unlockedFlags.contains(flag));
  }).toList();
}
```

---

## [5단계] 트랜잭션 안전성

### 5.1 저장 실패 처리
- MetaProfile 변경 시 dirty 플래그 설정
- 저장 실패 시 재시도 로직
- 앱 종료 시 최종 저장 보장

### 5.2 마이그레이션
```dart
class MetaProfile {
  static const int CURRENT_VERSION = 1;
  final int version;
  
  // v0 (없음) → v1 마이그레이션
  static MetaProfile migrateFromV0() {
    return MetaProfile(
      version: 1,
      runCount: 0,
      unlockedFlags: {},
      seenEncounterCount: {},
      seenEndings: {},
    );
  }
}
```

---

## 구현 우선순위

1. ✅ 코드베이스 스캔 완료
2. 🔄 MetaProfile 클래스 및 저장/로드 구현
3. 🔄 reset 메서드 추가 (InventorySystem, DialogueManager 등)
4. 🔄 GameController 생성자에서 자동 StartGame 제거
5. 🔄 StartGame 리팩터링 (완전 초기화)
6. 🔄 인카운터 언락 시스템 구현
7. 🔄 테스트 및 검증

---

## 주요 변경 파일 목록

### 새로 생성
- `lib/core/meta/meta_profile.dart` (MetaProfile 클래스)
- `lib/core/meta/meta_profile_system.dart` (저장/로드)
- `lib/core/meta/meta_profile_module.dart` (GameModule)

### 수정
- `lib/core/game_controller.dart` (자동 StartGame 제거)
- `lib/core/state/reducer.dart` (StartGame 완전 초기화)
- `lib/core/state/game_state.dart` (필요 시)
- `lib/app/app_wrapper.dart` (MetaProfile 로드 추가)
- `lib/screens/start_screen.dart` (StartGame dispatch 추가)
- `lib/inventory/inventory_system.dart` (resetForNewRun 추가)
- `lib/autosave/autosave_dialogue_manager.dart` (resetForNewRun 추가)
- `lib/core/schedule/encounter_scheduler.dart` (reset + 필터링)
- `lib/dialogue/dialogue_engine.dart` (unlock_meta effect 추가)

---

## 다음 단계

지금부터 2단계 구현을 시작합니다.



