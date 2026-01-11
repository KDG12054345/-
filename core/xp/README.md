# XP 마일스톤 시스템

숨은 XP 기반 인카운터 스케줄링 시스템입니다.

## 📋 개요

- **XP는 UI에 노출되지 않습니다** (숫자/게이지/퍼센트 모두 금지)
- 마일스톤: 테마(20,40,60,80,100), 스토리(10,30,50,70,90)
- XP는 **인카운터 종료 시에만** 일괄 정산
- 마일스톤 교차 시 큐에 적재, 다음 슬롯에서 순차 실행

## 🎯 마일스톤 규칙

### 테마 마일스톤 (20, 40, 60, 80, 100)
- 시작 테마에 따라 다른 인카운터 풀 사용
- `start_knight`, `start_mage` 등으로 분기
- **100은 터미널 마일스톤**: 엔딩으로 이어짐

### 스토리 마일스톤 (10, 30, 50, 70, 90)
- 고정 순서대로 스토리 인카운터 실행
- `story_10`, `story_30`, ... `story_90`

## 🔄 동작 흐름

```
인카운터 종료
    ↓
EncounterEnded 이벤트
    ↓
XpService.addXp() → (prev, now)
    ↓
MilestoneService.computeCrossed() → [M20, M30, M50]
    ↓
MilestoneService.enqueueAll()
    ↓
(다음 슬롯 열림)
    ↓
EncounterScheduler.nextSlot()
    ├─ 큐에 있으면 → 테마/스토리 인카운터
    └─ 큐가 비었으면 → 반복 랜덤 인카운터
```

## 🚫 터미널 마일스톤 (100)

100 마일스톤은 특별 처리됩니다:

1. 큐에 추가되면 `terminalPending = true`
2. Dequeue되면 `terminalRunning = true` (다른 인카운터 차단)
3. 테마(100) 인카운터 종료 직후 **즉시 엔딩 화면**
4. 엔딩 화면 종료 후 챕터 랩 (`resetAtEnd` 제어)

### 상태 머신
```
NORMAL
  └─(M=100 큐잉)→ RUN_THEME_100
RUN_THEME_100(완료)
  └→ SHOW_ENDING
SHOW_ENDING(확인)
  └→ CHAPTER_WRAP → NORMAL
```

## 📦 주요 클래스

### XpService
- **역할**: 숨은 XP 관리
- **API**:
  - `get()`: 현재 XP 조회
  - `set(value)`: XP 직접 설정 (로드/리셋용)
  - `addXp(source, amount)`: XP 추가
  - `onEncounterResolved(id, outcome)`: 인카운터 결과 기반 XP 정산

### MilestoneService
- **역할**: 마일스톤 교차 검출 및 큐 관리
- **API**:
  - `computeCrossed(prev, now)`: 교차한 마일스톤 계산
  - `enqueueAll(milestones)`: 마일스톤들 큐에 추가
  - `dequeue()`: 다음 마일스톤 꺼내기
  - `isQueueEmpty`: 큐 비었는지 확인
  - `wrapChapter()`: 챕터 종료 처리

### EncounterScheduler
- **역할**: 마일스톤 기반 인카운터 선택
- **API**:
  - `nextSlot()`: 다음 인카운터 선택
  - `setStartThemeKey(key)`: 시작 테마 설정

## 🎮 통합 지점

### 1. 이벤트 정의 (`lib/core/state/events.dart`)
```dart
class EncounterEnded extends GEvent {
  final String encounterId;
  final Map<String, dynamic> outcome;
}

class SlotOpened extends GEvent {}
class MilestoneReached extends GEvent {}
class ShowEnding extends GEvent {}
```

### 2. EncounterController 훅
```dart
// 인카운터 종료 시
if (nextView.isEnded) {
  final encounterId = _currentEncounterId ?? 'unknown';
  final outcome = _createOutcome(success: true);
  return [EncounterEnded(encounterId, outcome)];
}
```

### 3. XpModule
```dart
// EncounterEnded 이벤트 처리
Future<List<GEvent>> handle(GEvent event, GameVM vm) async {
  if (event is EncounterEnded) {
    // XP 정산 및 마일스톤 큐잉
    final (prev, now, _) = _xpService.onEncounterResolved(...);
    final crossed = _milestoneService.computeCrossed(prev, now);
    _milestoneService.enqueueAll(crossed);
  }
}
```

## ⚙️ 설정 파일

`assets/config/xp_config.json`:

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
        "start_knight": ["theme_knight_20", ...],
        "start_mage": ["theme_mage_20", ...]
      }
    },
    "story": {
      "sequence": ["story_10", "story_30", ...]
    }
  }
}
```

## 🧪 테스트

`test/xp/milestone_scheduler_test.dart`에서 핵심 시나리오 테스트:

1. ✅ 7→10: story(10) 1회
2. ✅ 19→21: theme(20) 1회
3. ✅ 15→55: theme(20)→story(30)→story(50) 순차
4. ✅ 79→81: theme(80) 1회
5. ✅ 95→105: story(90)→theme(100)→엔딩
6. ✅ 챕터 랩: 리셋 동작
7. ✅ 중복 방지

## 🔒 비파괴 규칙 준수

- ✅ 기존 파일 삭제 없음
- ✅ 함수 시그니처 변경 없음
- ✅ 기존 코드 위에 훅/어댑터 추가만
- ✅ 🆕 주석으로 새 코드 명시
- ✅ 전투/인벤토리/특성 로직 미변경

## 📊 디버그 로깅

개발 빌드에서만 활성화:

```dart
if (kDebugMode) {
  debugPrint('[XpService] XP: $prev → $now (+$gained)');
  debugPrint('[MilestoneService] Crossed: $crossed');
  debugPrint('[EncounterScheduler] Selected: $path');
}
```

## 🚀 사용 예시

### 게임 시작 시 설정 로드
```dart
// assets/config/xp_config.json 로드
final jsonString = await rootBundle.loadString('assets/config/xp_config.json');
final config = json.decode(jsonString);

MilestoneService.instance.loadConfig(MilestoneConfig.fromJson(config));
EncounterScheduler.instance.loadConfig(
  themeConfig: ThemeTrackConfig.fromJson(config['tracks']['theme']),
  storyConfig: StoryTrackConfig.fromJson(config['tracks']['story']),
);
```

### 상태 저장/복원
```dart
// 저장
final save = {
  'xp': XpService.instance.toJson(),
  'milestones': MilestoneService.instance.toJson(),
  'scheduler': EncounterScheduler.instance.toJson(),
};

// 복원
XpService.instance.fromJson(save['xp']);
MilestoneService.instance.fromJson(save['milestones']);
EncounterScheduler.instance.fromJson(save['scheduler']);
```

## 📝 커밋 메시지 예시

```
feat(xp): Add XpService for hidden XP management
feat(milestone): Add MilestoneService with queue system
feat(schedule): Add EncounterScheduler with theme/story tracks
feat(ending): Add EndingResolver for ending selection
chore(test): Add milestone scheduler test scenarios
chore(config): Add xp_config.json configuration file
```

