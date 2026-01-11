# RunState vs MetaProfile 구현 완료 보고서

## 📋 구현 상태

### ✅ 완료된 작업

#### [1단계] 코드베이스 스캔 및 구조 파악
- GameController, DialogueManager, InventorySystem 구조 분석 완료
- Provider 싱글톤 시스템 파악
- 인카운터 선택 로직 (EncounterScheduler) 확인
- 이벤트 시스템 (GEvent) 구조 이해

#### [2단계] RunState vs MetaProfile 설계
- `MetaProfile` 클래스 구현 (`lib/core/meta/meta_profile.dart`)
  - runCount, unlockedFlags, seenEncounterCount, seenEndings
  - JSON 직렬화/역직렬화
  - 버전 관리 및 마이그레이션 준비
- `MetaProfileSystem` 구현 (`lib/core/meta/meta_profile_system.dart`)
  - 별도 meta.json 파일로 저장/로드
  - 백업 파일 지원
  - path_provider를 통한 앱 전용 디렉토리 사용
- `MetaProfileModule` 구현 (`lib/core/meta/meta_profile_module.dart`)
  - GameModule 통합
  - StartGame, UnlockMetaFlag, EncounterEnded, ShowEnding 이벤트 처리
  - MetaProfile 자동 저장

#### [3단계] reset 메서드 추가
- `InventorySystem.resetForNewRun()` 구현
  - 모든 아이템 제거
  - GridMap 초기화
  - LockSystem 초기화
- `AutosaveDialogueManager.resetForNewRun()` 구현
  - DialogueManager 상태 초기화
  - 새 runId 생성
  - 저장 파일 삭제
- `RunStateResetModule` 구현 (`lib/core/modules/runstate_reset_module.dart`)
  - StartGame 이벤트 시 모든 시스템 reset 호출

#### [4단계] StartGame 리팩터링
- GameController 생성자에서 자동 StartGame 제거
- AppWrapper를 StatefulWidget으로 변경
  - MetaProfile 비동기 초기화
  - 초기화 완료 전 로딩 화면 표시
- MetaProfileModule을 GameController에 주입
- RunStateResetModule을 GameController에 주입
- reducer.dart의 StartGame 핸들러 완전 초기화
  - 모든 RunState 필드를 명시적으로 null/기본값으로 설정
- StartScreen에서 명시적으로 StartGame dispatch (이미 구현됨)

#### [5단계] 인카운터 언락 시스템 (부분 완료)
- `UnlockMetaFlag` 이벤트 정의 (`lib/core/state/events.dart`)
- EncounterController에 unlock_meta 핸들러 등록
  - JSON에서 `{type: "unlock_meta", data: {flag: "..."}}` 사용 가능

### 🔄 진행 중

#### [5단계] 인카운터 언락 시스템 (계속)
- [ ] EncounterScheduler에서 MetaProfile 기반 필터링
- [ ] JSON 인카운터 메타데이터에 requiredMetaFlags 필드 추가
- [ ] 테스트용 인카운터 JSON 작성

### ⏳ 대기 중

#### [6단계] 트랜잭션 안전성 및 마이그레이션
- [ ] MetaProfile 저장 실패 시 재시도 로직
- [ ] dirty 플래그 기반 자동 저장
- [ ] 버전 마이그레이션 테스트

#### [7단계] 테스트 및 검증
- [ ] 회차 리셋 완전성 테스트
- [ ] 메타 언락 동작 테스트
- [ ] 엣지 케이스 처리 확인

---

## 🎯 사용 방법

### 인카운터 JSON에서 메타 플래그 언락

```jsonc
// assets/dialogue/main/special_encounter.json
{
  "metadata": {
    "id": "enc_unlock_merfolk",
    "xp": 2
  },
  "scenes": {
    "unlock_scene": {
      "nodes": [
        {
          "type": "text",
          "speaker": "안내자",
          "text": "당신은 인어들의 비밀 통로를 발견했습니다!"
        },
        {
          "type": "event",
          "event": "unlock_meta",
          "data": {
            "flag": "unlocked_merfolk_capital"
          }
        },
        {
          "type": "text",
          "speaker": "안내자",
          "text": "이제 다음 회차부터 인어 수도로 갈 수 있습니다."
        }
      ]
    }
  }
}
```

### 메타 플래그 확인

```dart
// MetaProfileModule 접근
final metaModule = context.read<MetaProfileModule>();

// 특정 플래그가 언락되었는지 확인
if (metaModule.hasFlag('unlocked_merfolk_capital')) {
  print('인어 수도 언락됨!');
}

// 회차 수 확인
print('현재 회차: ${metaModule.profile.runCount}');
```

### 새 회차 시작 흐름

```
1. 게임 오버
   ↓
2. GameOverScreen 표시
   - initState에서 autosave 자동 삭제
   ↓
3. "다시 시작" 버튼 클릭
   - appState.returnToStart()
   ↓
4. StartScreen 표시
   - MetaProfile은 유지됨 (meta.json)
   ↓
5. "게임 시작" 버튼 클릭
   - gameController.dispatch(StartGame())
   ↓
6. StartGame 이벤트 처리
   - MetaProfileModule: runCount++, 저장
   - RunStateResetModule: 모든 시스템 reset
   - reducer: GameVM 완전 초기화
   ↓
7. CharacterCreated 이벤트
   - 새 캐릭터 생성
   - InventoryInitModule: 시작 아이템 배치
   ↓
8. 새 회차 시작!
```

---

## 📁 주요 파일

### 새로 생성된 파일
```
lib/core/meta/
  ├── meta_profile.dart              # MetaProfile 클래스
  ├── meta_profile_system.dart       # 저장/로드 시스템
  └── meta_profile_module.dart       # GameModule 통합

lib/core/modules/
  └── runstate_reset_module.dart     # RunState 초기화 모듈

saves/
  ├── autosave.json                  # RunState (회차 상태)
  └── meta.json                      # MetaProfile (메타 진행도)
```

### 수정된 파일
```
lib/core/
  ├── game_controller.dart           # 자동 StartGame 제거
  └── state/
      ├── reducer.dart               # StartGame 완전 초기화
      └── events.dart                # UnlockMetaFlag 이벤트 추가

lib/app/
  └── app_wrapper.dart               # MetaProfile 초기화, Provider 추가

lib/inventory/
  └── inventory_system.dart          # resetForNewRun() 추가

lib/autosave/
  └── autosave_dialogue_manager.dart # resetForNewRun() 추가

lib/modules/encounter/
  └── encounter_controller.dart      # unlock_meta 핸들러 추가
```

---

## 🐛 알려진 이슈

### 해결됨
- ✅ GameController가 재사용되어 이전 상태가 남는 문제 → reducer에서 완전 초기화로 해결
- ✅ InventorySystem, DialogueManager가 싱글톤이라 reset 필요 → resetForNewRun() 추가
- ✅ MetaProfile 초기화 타이밍 문제 → AppWrapper를 StatefulWidget으로 변경

### 미해결
- ⚠️ EncounterScheduler가 MetaProfile을 참조하지 않음 → 필터링 미구현
- ⚠️ requiredMetaFlags JSON 스키마 미정의

---

## 🚀 다음 단계

1. **EncounterScheduler 필터링 구현**
   - MetaProfileModule 참조 추가
   - 인카운터 선택 시 requiredMetaFlags 확인
   - 조건 만족하는 인카운터만 풀에 포함

2. **테스트 인카운터 작성**
   - 메타 언락 테스트용 인카운터
   - requiredMetaFlags 테스트용 인카운터

3. **UX 개선**
   - 언락 발생 시 UI 피드백 (토스트/다이얼로그)
   - StartScreen에서 언락된 콘텐츠 수 표시

4. **안전성 강화**
   - MetaProfile 저장 실패 시 재시도
   - 백그라운드 자동 저장
   - 버전 마이그레이션 테스트

---

## 📊 통계

- **새 파일**: 4개
- **수정 파일**: 7개
- **추가 코드**: ~800줄
- **새 이벤트**: 1개 (UnlockMetaFlag)
- **새 모듈**: 2개 (MetaProfileModule, RunStateResetModule)

---

**작성 시각**: 2025-11-19  
**작업 완료도**: 약 80%  
**예상 남은 작업**: 2-3시간



