# XP 시스템 통합 완료

## 📋 개요

EncounterController와 XP 시스템(EncounterScheduler, XpModule, MilestoneService)을 완전히 통합하여 인카운터가 연속적으로 진행되도록 구현했습니다.

---

## ✅ 통합된 기능

### 1️⃣ EncounterController 확장
**파일**: `lib/modules/encounter/encounter_controller.dart`

#### 추가된 기능
- **`SlotOpened` 이벤트 처리**: 다음 인카운터 자동 로드
- **EncounterScheduler 연동**: 스케줄러를 통한 인카운터 선택
- **인카운터 종료 시 SlotOpened 발생**: 연속 진행 가능

```dart
class EncounterController {
  // 🆕 XP 통합: 스케줄러 인스턴스
  final EncounterScheduler _scheduler = EncounterScheduler.instance;
  
  Future<List<GEvent>> handle(GEvent e, GameVM vm) async {
    if (e is CharacterCreated) {
      return await _handleStartGame(vm);
    } else if (e is Next) {
      return await _handleNext();
    } else if (e is SlotOpened) { // 🆕 XP 통합
      return await _handleSlotOpened(vm);
    }
    return const [];
  }
  
  // 🆕 다음 슬롯 인카운터 로드
  Future<List<GEvent>> _handleSlotOpened(GameVM vm) async {
    final selection = await _scheduler.nextSlot();
    if (selection == null) return const [];
    return await _loadEncounter(selection.path);
  }
  
  // 🆕 인카운터 로드 헬퍼
  Future<List<GEvent>> _loadEncounter(String encounterPath) async { ... }
}
```

### 2️⃣ 인카운터 종료 플로우
**인카운터 종료 시 두 이벤트 동시 발생**:

```dart
// Line 121, 147에서:
return [EncounterEnded(encounterId, outcome), const SlotOpened()];
```

#### 작동 순서
1. 인카운터 종료 → `EncounterEnded` 발생
2. 동시에 `SlotOpened` 발생
3. `XpModule`이 `EncounterEnded` 처리 (XP 정산, 마일스톤 큐잉)
4. `EncounterController`가 `SlotOpened` 처리 (다음 인카운터 로드)

---

### 3️⃣ EncounterScheduler 경로 수정
**파일**: `lib/core/schedule/encounter_scheduler.dart`

#### Chapter 경로
```dart
// theme → chapter 경로로 변경
final path = 'assets/dialogue/main/chapter/$selected.json';
```

#### Story 경로
```dart
// story 서브폴더 경로
final path = 'assets/dialogue/main/story/$selected.json';
```

---

### 4️⃣ MilestoneConfig 호환성
**파일**: `lib/core/milestone/milestone_service.dart`

#### xp_config.json 하위 호환
```dart
factory MilestoneConfig.fromJson(Map<String, dynamic> json) {
  return MilestoneConfig(
    // 🆕 chapterMilestones를 themeMilestones로 읽기
    themeMilestones: (json['chapterMilestones'] as List<dynamic>? ?? 
                      json['themeMilestones'] as List<dynamic>?)
            ?.map((e) => e as int)
            .toList() ??
        const [20, 40, 60, 80, 100],
    
    // 🆕 game.end를 chapter.end로도 읽기
    chapterEnd: (json['game']?['end'] as int? ?? 
                 json['chapter']?['end'] as int?) ?? 100,
    resetAtEnd: (json['game']?['resetAtEnd'] as bool? ?? 
                 json['chapter']?['resetAtEnd'] as bool?) ?? true,
  );
}
```

---

## 🔄 인카운터 진행 흐름

### 1. 시작 인카운터
```
[CharacterCreated 이벤트]
  ↓
[EncounterController._handleStartGame]
  ↓
[Start 인카운터 로드 (start_knight.json 등)]
  ↓
[플레이어 "Next" 버튼 클릭]
  ↓
[인카운터 종료]
  ↓
[EncounterEnded + SlotOpened 발생]
```

### 2. 반복 인카운터 (XP 획득)
```
[SlotOpened 이벤터]
  ↓
[EncounterController._handleSlotOpened]
  ↓
[EncounterScheduler.nextSlot()]
  ├─ 큐 비었음 → 반복 인카운터 선택
  └─ 큐 있음 → 마일스톤 인카운터 선택
  ↓
[랜덤 인카운터 로드 (goblin_encounter.json 등)]
  ↓
[플레이어 진행...]
  ↓
[인카운터 종료]
  ↓
[EncounterEnded + SlotOpened 발생]
  ↓
[XpModule이 EncounterEnded 처리]
  ├─ 반복 인카운터? → XP 정산
  ├─ 마일스톤 교차? → 큐에 추가
  └─ XP: 0 → 2 (고블린 2 XP)
  ↓
[다시 SlotOpened 처리 → 다음 인카운터 로드]
```

### 3. 마일스톤 인카운터 (Chapter/Story)
```
[XP 8 → 12 (마일스톤 10 교차)]
  ↓
[MilestoneService.computeCrossed] → [Milestone(10, story)]
  ↓
[MilestoneService.enqueueAll] → 큐: [story_10]
  ↓
[다음 SlotOpened]
  ↓
[EncounterScheduler.nextSlot()]
  ├─ 큐에 story_10 있음!
  └─ _selectStoryEncounter(10)
  ↓
[story_10.json 로드]
  ↓
[플레이어 진행...]
  ↓
[인카운터 종료]
  ↓
[EncounterEnded + SlotOpened]
  ├─ XP 정산 안 함 (story는 XP 없음)
  └─ 다음 인카운터로...
```

### 4. Chapter 마일스톤 (XP 20, 40, 60, 80, 100)
```
[XP 18 → 22 (마일스톤 20 교차)]
  ↓
[MilestoneService.computeCrossed] → [Milestone(20, theme)]
  ↓
[큐: [chapter_20]]
  ↓
[다음 SlotOpened]
  ↓
[EncounterScheduler.nextSlot()]
  ├─ 큐에 chapter_20 있음!
  └─ _selectThemeEncounter(20)
  ├─ 시작 테마 확인: start_knight
  └─ poolByStart['start_knight'] → 'chapter_knight_20'
  ↓
[chapter_knight_20.json 로드]
  ↓
[기사단 선택 챕터 진행...]
```

---

## 📊 데이터 흐름 다이어그램

```
┌─────────────────────────────────────────┐
│         EncounterController             │
├─────────────────────────────────────────┤
│  handle(CharacterCreated) → Start       │
│  handle(Next) → 대화 진행               │
│  handle(SlotOpened) → 다음 인카운터     │ ← 🆕
└─────────────────┬───────────────────────┘
                  │
    ┌─────────────┴─────────────┐
    │                           │
    ▼                           ▼
[EncounterEnded]          [SlotOpened] ← 🆕
    │                           │
    ▼                           ▼
┌──────────┐            ┌──────────────────┐
│ XpModule │            │ EncounterScheduler│
├──────────┤            ├──────────────────┤
│ XP 정산  │            │ nextSlot()       │
│ 마일스톤 │            │ ├─ 큐 있음?      │
│ 큐 추가  │            │ │  └─ Chapter/Story│
└──────────┘            │ └─ 큐 없음?      │
                        │    └─ Random     │
                        └──────────────────┘
```

---

## 🎯 핵심 개선 사항

### Before (통합 전)
- ❌ 시작 인카운터 이후 멈춤
- ❌ 수동으로 다음 인카운터 로드 필요
- ❌ XP 시스템과 연결 없음

### After (통합 후)
- ✅ 인카운터 자동 연속 진행
- ✅ XP 정산 자동 처리
- ✅ 마일스톤 도달 시 자동 Chapter/Story 로드
- ✅ 큐가 비면 자동으로 Random 인카운터
- ✅ 완전한 이벤트 기반 아키텍처

---

## 🔧 설정 요구사항

### xp_config.json
```json
{
  "chapterMilestones": [20, 40, 60, 80, 100],
  "storyMilestones": [10, 30, 50, 70, 90],
  "tracks": {
    "chapter": {
      "poolByStart": {
        "start_knight": ["chapter_knight_20", ...],
        "start_mage": ["chapter_mage_20", ...]
      }
    },
    "story": {
      "sequence": ["story_10", "story_30", ...]
    }
  }
}
```

### 초기화 (게임 시작 시 필요)
```dart
// 설정 로드
final jsonString = await rootBundle.loadString('assets/config/xp_config.json');
final config = json.decode(jsonString);

MilestoneService.instance.loadConfig(MilestoneConfig.fromJson(config));
EncounterScheduler.instance.loadConfig(
  themeConfig: ThemeTrackConfig.fromJson(config['tracks']['chapter']),
  storyConfig: StoryTrackConfig.fromJson(config['tracks']['story']),
  startThemeKey: 'start_knight', // 플레이어 선택에 따라
);
```

---

## 📝 XP 정산 규칙

| 인카운터 타입 | XP 지급 | 경로 | 트리거 |
|--------------|---------|------|--------|
| **Start** | ❌ | `/start/` | CharacterCreated |
| **Chapter** | ❌ | `/main/chapter/` | XP 20, 40, 60, 80, 100 |
| **Story** | ❌ | `/main/story/` | XP 10, 30, 50, 70, 90 |
| **Random** | ✅ 1~3 XP | `/random/` | 큐 비었을 때 |

---

## 🐛 디버그 로깅

개발 빌드에서 확인 가능한 로그:

```
[EncounterController] Dialogue ended
[XpModule] Encounter ended: goblin_encounter
[XpModule] Repeat encounter detected: assets/dialogue/random/combat/goblin_encounter.json
[XpModule] XP: 0 → 2 (+2)
[XpModule] No milestones crossed
[EncounterController] Slot opened - selecting next encounter...
[EncounterScheduler] Queue empty, selecting repeat encounter
[EncounterScheduler] Selected: EncounterSelection(repeat: assets/dialogue/random/combat/bandit_encounter.json)
[EncounterController] Loading encounter: assets/dialogue/random/combat/bandit_encounter.json
```

---

## ⚠️ 주의사항

1. **xp_config.json 로드**: 게임 시작 시 반드시 로드해야 함
2. **시작 테마 설정**: 캐릭터 생성 시 `EncounterScheduler.setStartThemeKey()` 호출 필요
3. **인카운터 경로**: 반드시 서브폴더 포함 (`main/chapter/`, `main/story/`)
4. **마일스톤 이름**: 내부적으로 theme/story 사용, xp_config에서는 chapter로 참조

---

## ✅ 완료된 통합

- [x] EncounterController에 SlotOpened 처리 추가
- [x] EncounterScheduler 연동
- [x] 인카운터 종료 시 SlotOpened 발생
- [x] Chapter/Story 경로 수정 (서브폴더)
- [x] MilestoneConfig 하위 호환성 (chapterMilestones 읽기)
- [x] 이벤트 기반 연속 진행 구현

---

## 🎉 결과

**인카운터가 끊김 없이 연속적으로 진행되며, XP 시스템과 완벽하게 통합되었습니다!**

- Start → Random → Random → Story(10) → Random → Chapter(20) → ...

모든 인카운터가 자동으로 연결되어 플레이어는 계속해서 "Next" 버튼만 누르면 게임이 진행됩니다.

