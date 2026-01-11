# XP 마일스톤 시스템 구현 요약

## 🎯 목표

숨은 XP 기반 인카운터 스케줄링 시스템 구축 (UI 노출 없음)

## ✅ 완료된 작업

### 1. 이벤트 정의 추가 ✅
**파일**: `lib/core/state/events.dart`

새로 추가된 이벤트:
- `EncounterEnded` - 인카운터 종료 (XP 정산 트리거)
- `SlotOpened` - 다음 슬롯 열림 (스케줄러 트리거)
- `MilestoneReached` - 마일스톤 도달 (로깅용)
- `ShowEnding` - 엔딩 표시 요청
- `ChapterWrapped` - 챕터 랩 완료

**변경 사항**: 기존 코드 끝에 추가만 (비파괴)

---

### 2. 도메인 서비스 구현 ✅

#### XpService (`lib/core/xp/xp_service.dart`)
**Public API**:
```dart
class XpService {
  // XP 조회/설정
  int get()
  void set(int value)
  
  // XP 추가
  (int previous, int now) addXp(XpSource source, int amount, {String? detail})
  
  // 인카운터 결과 기반 XP 정산
  (int previous, int now, int gained) onEncounterResolved(
    String encounterId,
    Map<String, dynamic> outcome,
  )
  
  // 상태 관리
  void reset()
  Map<String, dynamic> toJson()
  void fromJson(Map<String, dynamic> json)
}
```

**특징**:
- 숨은 XP (UI 노출 금지)
- 히스토리 추적 (디버그 빌드)
- 인카운터 결과 기반 자동 계산

---

#### MilestoneService (`lib/core/milestone/milestone_service.dart`)
**Public API**:
```dart
class MilestoneService {
  // 설정
  void loadConfig(MilestoneConfig config)
  MilestoneConfig get config
  
  // 마일스톤 교차 계산
  List<Milestone> computeCrossed(int prev, int now)
  
  // 큐 관리
  void enqueueAll(List<Milestone> milestones)
  void enqueue(Milestone milestone)
  Milestone? dequeue()
  bool get isQueueEmpty
  int get queueSize
  List<Milestone> peekQueue()
  
  // 터미널 상태
  bool get isTerminalPending
  bool get isTerminalRunning
  bool get isEndingShown
  void markTerminalRunning(bool value)
  void markEndingShown(bool value)
  
  // 챕터 관리
  void wrapChapter()
  
  // 상태 관리
  Map<String, dynamic> toJson()
  void fromJson(Map<String, dynamic> json)
}
```

**특징**:
- 테마(20,40,60,80,100) / 스토리(10,30,50,70,90) 마일스톤
- 중복 방지
- 터미널(100) 특수 처리

---

#### EncounterScheduler (`lib/core/schedule/encounter_scheduler.dart`)
**Public API**:
```dart
class EncounterScheduler {
  // 설정
  void loadConfig({
    ThemeTrackConfig? themeConfig,
    StoryTrackConfig? storyConfig,
    String? startThemeKey,
  })
  void setStartThemeKey(String key)
  
  // 인카운터 선택
  Future<EncounterSelection?> nextSlot()
  
  // 상태 관리
  Map<String, dynamic> toJson()
  void fromJson(Map<String, dynamic> json)
}
```

**동작**:
- 큐에 마일스톤 있음 → 테마/스토리 인카운터
- 큐 비었음 → 반복 랜덤 인카운터
- 터미널 실행 중 → 모든 인카운터 차단

---

#### EndingResolver (`lib/core/ending/ending_resolver.dart`)
**Public API**:
```dart
class EndingResolver {
  void loadEndings(Map<String, dynamic> endingsConfig)
  
  String resolveEnding(String startThemeKey, Map<String, bool> playerFlags)
  String getEndingPath(String endingId)
  Ending? getEnding(String endingId)
  List<Ending> getAllEndings()
}
```

**특징**:
- 시작 테마 + 플레이어 플래그 기반 엔딩 결정
- 조건 매칭 시스템
- 폴백 엔딩 지원

---

### 3. 모듈 통합 ✅

#### XpModule (`lib/modules/xp/xp_module.dart`)
```dart
class XpModule implements GameModule {
  Set<AppPhase> get supportedPhases
  Set<Type> get handledEvents  // EncounterEnded, SlotOpened
  
  Future<List<GEvent>> handle(GEvent event, GameVM vm)
}
```

**동작**:
1. `EncounterEnded` 수신
2. `XpService.onEncounterResolved()` 호출
3. `MilestoneService.computeCrossed()` 호출
4. `MilestoneService.enqueueAll()` 호출
5. `MilestoneReached` 이벤트 발생

**GameController 통합**:
```dart
// lib/app/app_wrapper.dart
GameController(modules: [
  CharacterCreationModule(),
  XpModule(),  // 🆕 추가됨
  EncounterModule(),
  CombatModule(),
  RewardModule(),
])
```

---

### 4. EncounterController 훅 추가 ✅

**파일**: `lib/modules/encounter/encounter_controller.dart`

**변경 사항** (비파괴):
```dart
class EncounterController {
  DialogueEngine? _engine;
  String? _currentEncounterId;  // 🆕 추가
  
  // 인카운터 로드 시 ID 저장
  _currentEncounterId = _extractEncounterId(encounterPath);  // 🆕
  
  // 인카운터 종료 시 이벤트 발생
  if (nextView.isEnded) {
    final encounterId = _currentEncounterId ?? 'unknown';
    final outcome = _createOutcome(success: true);
    _engine = null;
    _currentEncounterId = null;
    return [EncounterEnded(encounterId, outcome)];  // 🆕
  }
  
  // 🆕 헬퍼 메서드
  String _extractEncounterId(String path)
  Map<String, dynamic> _createOutcome(...)
}
```

**보존된 기존 코드**:
- ✅ 모든 기존 메서드 시그니처 유지
- ✅ 기존 로직 삭제 없음
- ✅ 주석으로 🆕 표시

---

### 5. 설정 파일 ✅

**파일**: `assets/config/xp_config.json`

```json
{
  "milestoneStep": 10,
  "themeMilestones": [20, 40, 60, 80, 100],
  "storyMilestones": [10, 30, 50, 70, 90],
  "chapter": {
    "end": 100,
    "resetAtEnd": true
  },
  "tracks": {
    "theme": {
      "poolByStart": {
        "default": [...],
        "start_knight": [...],
        "start_mage": [...]
      },
      "selection": "weighted_random"
    },
    "story": {
      "sequence": ["story_10", "story_30", "story_50", "story_70", "story_90"],
      "onMiss": "enqueue_next"
    }
  },
  "endings": {
    "default_ending": {...},
    "start_knight_ending": {...},
    ...
  }
}
```

**pubspec.yaml 업데이트**:
```yaml
assets:
  - assets/config/xp_config.json  # 🆕 추가
```

---

### 6. 테스트 ✅

**파일**: `test/xp/milestone_scheduler_test.dart`

**커버리지**:
1. ✅ 7→10: story(10) 1회 교차
2. ✅ 19→21: theme(20) 1회 교차
3. ✅ 15→55: 다중 마일스톤 순차 처리
4. ✅ 79→81: theme(80) 교차
5. ✅ 95→105: 터미널 마일스톤 처리
6. ✅ 챕터 랩 (리셋)
7. ✅ 중복 마일스톤 방지

**실행**:
```bash
flutter test test/xp/milestone_scheduler_test.dart
```

---

## 📂 추가된 파일 목록

### 도메인 레이어
- `lib/core/xp/xp_service.dart`
- `lib/core/xp/README.md`
- `lib/core/milestone/milestone_service.dart`
- `lib/core/schedule/encounter_scheduler.dart`
- `lib/core/ending/ending_resolver.dart`

### 모듈 레이어
- `lib/modules/xp/xp_module.dart`

### 설정
- `assets/config/xp_config.json`

### 테스트
- `test/xp/milestone_scheduler_test.dart`

### 문서
- `lib/core/xp/README.md`
- `IMPLEMENTATION_SUMMARY_XP.md` (this file)

---

## 🔧 수정된 파일 목록

### 이벤트 시스템
- `lib/core/state/events.dart` (5개 이벤트 추가)

### 컨트롤러
- `lib/modules/encounter/encounter_controller.dart` (훅 추가, 비파괴)

### 앱 설정
- `lib/app/app_wrapper.dart` (XpModule 추가)
- `pubspec.yaml` (assets 경로 추가)

---

## 🎮 통합 지점

### 1. 인카운터 종료 → XP 정산
```
EncounterController.isEnded
    ↓
EncounterEnded 이벤트
    ↓
XpModule.handle()
    ↓
XpService.onEncounterResolved()
    ↓
MilestoneService.computeCrossed()
    ↓
MilestoneService.enqueueAll()
```

### 2. 다음 슬롯 → 인카운터 선택
```
SlotOpened 이벤트
    ↓
EncounterScheduler.nextSlot()
    ├─ 큐 있음 → 테마/스토리
    └─ 큐 없음 → 반복 랜덤
```

### 3. 터미널 마일스톤 → 엔딩
```
theme(100) dequeue
    ↓
MilestoneService.markTerminalRunning(true)
    ↓
테마(100) 인카운터 실행
    ↓
EncounterEnded
    ↓
ShowEnding 이벤트
    ↓
EndingScreen 표시
    ↓
ChapterWrapped 이벤트
```

---

## 🚫 비파괴 규칙 준수 확인

### ✅ 삭제된 기존 코드: 없음
- 모든 기존 파일과 메서드 유지
- 주석 처리된 코드도 보존

### ✅ 변경된 시그니처: 없음
- 기존 public API 모두 유지
- 새 파라미터는 optional로만 추가

### ✅ 추가된 코드 표시
- 🆕 주석으로 신규 코드 명시
- // ❌ 주석으로 기존 제거 코드 명시

### ✅ 어댑터 패턴 사용
- 기존 시스템 위에 훅 추가
- 기존 동작 방해 없음

---

## 📊 실행 로그 예시

### 시나리오: 15 XP → 55 XP

```
[EncounterController] Dialogue ended
[EncounterController] Encounter ID: combat_goblin_001
[XpService] XP: 15 → 55 (+40)
[MilestoneService] Crossed: 15 → 55, milestones: [Milestone(20, theme), Milestone(30, story), Milestone(50, story)]
[MilestoneService] Enqueued: Milestone(20, theme) (queue size: 1)
[MilestoneService] Enqueued: Milestone(30, story) (queue size: 2)
[MilestoneService] Enqueued: Milestone(50, story) (queue size: 3)
[XpModule] Crossed milestones: [Milestone(20, theme), Milestone(30, story), Milestone(50, story)]
[XpModule] Queue size: 3

--- 다음 슬롯 ---
[MilestoneService] Dequeued: Milestone(20, theme) (remaining: 2)
[EncounterScheduler] Processing milestone: Milestone(20, theme)
[EncounterScheduler] Selected theme: assets/dialogue/main/theme_knight_20.json for M20

--- 다음 슬롯 ---
[MilestoneService] Dequeued: Milestone(30, story) (remaining: 1)
[EncounterScheduler] Processing milestone: Milestone(30, story)
[EncounterScheduler] Selected story: assets/dialogue/main/story_30.json for M30

--- 다음 슬롯 ---
[MilestoneService] Dequeued: Milestone(50, story) (remaining: 0)
[EncounterScheduler] Processing milestone: Milestone(50, story)
[EncounterScheduler] Selected story: assets/dialogue/main/story_50.json for M50

--- 다음 슬롯 ---
[EncounterScheduler] Queue empty, selecting repeat encounter
[EncounterScheduler] Selected repeat: assets/dialogue/random/combat/goblin_encounter.json
```

---

## 🔍 디버그 도구

### XpService 디버그
```dart
final history = XpService.instance.getHistory();
for (final change in history) {
  print(change);  // XpChange(prev → now, +delta from source: detail)
}
```

### MilestoneService 디버그
```dart
print(MilestoneService.instance.debugInfo());
// Output:
// MilestoneService Debug:
//   Theme triggered: {20, 40}
//   Story triggered: {10, 30}
//   Queue: [Milestone(50, story)]
//   Terminal: pending=false, running=false, ending=false
```

### EncounterScheduler 디버그
```dart
print(EncounterScheduler.instance.debugInfo());
// Output:
// EncounterScheduler Debug:
//   Start Theme Key: start_knight
//   Queue Size: 2
//   Terminal: false
//   Ending Shown: false
//   Current XP: 45
```

---

## ✅ Definition of Done 체크

- ✅ 숨은 XP가 UI에 노출되지 않음
- ✅ 테스트 시나리오 1-7 모두 통과
- ✅ 기존 인벤토리/전투/특성 파일 미삭제·미파손
- ✅ 컴파일/런타임 경고 없음
- ✅ 린트 에러 없음
- ✅ 작은 커밋 단위로 구성 가능
- ✅ 커밋 메시지 형식 제시

---

## 🚀 다음 단계 (선택사항)

### EndingScreen 구현
```dart
// lib/screens/ending_screen.dart
class EndingScreen extends StatelessWidget {
  final String endingId;
  final Map<String, dynamic> context;
  
  // 엔딩 텍스트 표시
  // 확인 버튼 → ChapterWrapped 이벤트
}
```

### 설정 파일 로드 자동화
```dart
// lib/core/xp/xp_config_loader.dart
class XpConfigLoader {
  static Future<void> loadConfig() async {
    final jsonString = await rootBundle.loadString('assets/config/xp_config.json');
    final config = json.decode(jsonString);
    
    MilestoneService.instance.loadConfig(MilestoneConfig.fromJson(config));
    EncounterScheduler.instance.loadConfig(...);
    EndingResolver.instance.loadEndings(config['endings']);
  }
}
```

### 상태 저장 통합
```dart
// lib/modules/save/save_controller.dart
class SaveData {
  final Map<String, dynamic> xp;
  final Map<String, dynamic> milestones;
  final Map<String, dynamic> scheduler;
  
  // toJson/fromJson
}
```

---

## 📝 커밋 제안

```bash
git add lib/core/state/events.dart
git commit -m "feat(xp): Add XP milestone system events"

git add lib/core/xp/xp_service.dart
git commit -m "feat(xp): Add XpService for hidden XP management"

git add lib/core/milestone/milestone_service.dart
git commit -m "feat(milestone): Add MilestoneService with queue system"

git add lib/core/schedule/encounter_scheduler.dart
git commit -m "feat(schedule): Add EncounterScheduler for milestone-based encounters"

git add lib/core/ending/ending_resolver.dart
git commit -m "feat(ending): Add EndingResolver for conditional endings"

git add lib/modules/xp/xp_module.dart
git commit -m "feat(xp): Add XpModule for event integration"

git add lib/modules/encounter/encounter_controller.dart
git commit -m "feat(encounter): Add XP hooks to EncounterController (non-destructive)"

git add lib/app/app_wrapper.dart
git commit -m "feat(xp): Integrate XpModule into GameController"

git add assets/config/xp_config.json pubspec.yaml
git commit -m "chore(config): Add XP system configuration file"

git add test/xp/milestone_scheduler_test.dart
git commit -m "test(xp): Add milestone scheduler test scenarios"

git add lib/core/xp/README.md IMPLEMENTATION_SUMMARY_XP.md
git commit -m "docs(xp): Add XP milestone system documentation"
```

---

## 🎉 완료!

XP 마일스톤 시스템이 성공적으로 구현되었습니다.
기존 코드를 손상시키지 않고 모듈형 아키텍처로 통합되었습니다.

