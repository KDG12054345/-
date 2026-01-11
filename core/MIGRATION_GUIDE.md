# 레거시 이벤트 시스템 마이그레이션 가이드

## 개요

레거시 `event_system.dart`의 `EventManager`/`GameEvent`를 `core/state/events.dart`의 `GEvent` 시스템으로 마이그레이션하는 작업입니다.

## ✅ 최종 완료 상태

### 1. 레거시 시스템 Deprecation 표시 완료
- `event_system.dart`의 모든 주요 클래스에 `@Deprecated` 추가
- 마이그레이션 안내 메시지 포함

### 2. LegacyEventAdapter 구현 완료
- `lib/core/infra/legacy_event_adapter.dart`
- 레거시 이벤트를 GEvent로 자동 변환
- 하위 호환성 보장

### 3. 인벤토리 시스템 마이그레이션 완료 (100%)
- `TickAlignedInventorySystem` - GEvent 사용
- `ItemManager` - GEvent 디스패치
- 모든 인벤토리 이벤트가 GEvent 기반으로 전환

### 4. 불필요한 Import 정리 완료
다음 파일에서 사용하지 않는 `event_system.dart` import 제거:
- ✅ `lib/combat/combat_conditions.dart`
- ✅ `lib/combat/character.dart`  
- ✅ `lib/combat/combat_engine.dart`
- ✅ `lib/autosave/autosave_dialogue_manager.dart`

### 5. 문서 업데이트 완료
- 마이그레이션 가이드 최종 작성
- 현재 상태 및 향후 계획 문서화

## 📊 현재 시스템 상태

### event_system.dart 사용 현황

**제거 완료 (4개 파일)**
- `combat_conditions.dart` - ✅ import 제거
- `character.dart` - ✅ import 제거
- `combat_engine.dart` - ✅ import 제거
- `autosave_dialogue_manager.dart` - ✅ import 제거

**계속 사용 중 (10개 파일)**

1. **핵심 시스템 (제거 불가)**
   - `lib/dialogue_manager.dart` - EventSystem을 핵심 의존성으로 사용
   - `lib/branch_system.dart` - GameState 타입 사용
   - `lib/save_system.dart` - GameState 타입 사용

2. **전투 시스템 (LegacyEventAdapter로 호환)**
   - `lib/combat/health_system.dart` - eventManager 1회 사용
   - `lib/combat/item_effect.dart` - eventManager 2회 사용
   - `lib/combat/item.dart` - eventManager 다수 사용
   - `lib/combat/status_effect.dart` - GameEvent/GameEventType 대량 사용

3. **어댑터 및 테스트 (유지 필요)**
   - `lib/core/infra/legacy_event_adapter.dart` - 어댑터 구현
   - `lib/core/character/character_sync.dart` - EventSystem 사용
   - `test/event_system_test.dart` - 테스트 파일

## 🔄 마이그레이션 전략

### 현재 전략: 점진적 공존

**선택한 접근 방식**
- ✅ LegacyEventAdapter를 통한 두 시스템 공존
- ✅ 신규 코드는 GEvent 사용
- ✅ 레거시 코드는 안정적으로 유지
- ⚠️ 대화 시스템 재작성은 보류 (큰 작업, 현재 시스템이 잘 작동 중)

### event_system.dart 제거 불가 이유

1. **DialogueManager 의존성**
   - `DialogueManager`가 `EventSystem` 클래스를 생성자에서 사용
   - `GameEvent`, `GameEventType` 등을 직접 사용
   - 전체 대화 시스템 재작성 필요

2. **GameState 타입 사용**
   - `BranchSystem`, `SaveSystem`이 `GameState` 타입에 의존
   - 저장/로드 시스템 전체가 `GameState` 구조 사용
   - 대규모 리팩토링 필요

3. **전투 시스템 광범위 사용**
   - 수백 개의 이벤트 디스패치 코드
   - LegacyEventAdapter로 안정적 호환 중
   - 급하게 변경할 필요 없음

## 💡 향후 옵션

### Option A: 현재 상태 유지 (권장 ⭐)

**장점**
- ✅ 안정성: 검증된 시스템 유지
- ✅ 점진적 개선: 신규 기능은 GEvent 사용
- ✅ 리스크 최소화: 큰 규모 리팩토링 회피
- ✅ 하위 호환성: LegacyEventAdapter로 보장

**단점**
- ⚠️ 두 시스템 공존으로 인한 복잡도

### Option B: 완전 마이그레이션 (대규모 작업)

**필요 작업**
1. 새로운 `GameState` 모델 설계 (core/state/)
2. `DialogueManager` GEvent 기반으로 재작성
3. `BranchSystem`, `SaveSystem` 재설계
4. 전투 시스템 이벤트 전면 전환 (수백 개 코드)
5. `event_system.dart` 완전 제거
6. 전체 시스템 통합 테스트

**예상 소요 시간**: 수일~수주

**리스크**: 높음 (기존 기능 깨질 가능성)

## 📝 마이그레이션 예시

### 신규 코드 작성 시 (GEvent 사용 권장)

```dart
// lib/core/state/combat_events.dart
import 'events.dart';

class HealthChangedEvent extends GEvent {
  final int oldHealth;
  final int newHealth;
  final String source;
  
  const HealthChangedEvent({
    required this.oldHealth,
    required this.newHealth,
    required this.source,
  });
}

// 사용 예시
dispatch(HealthChangedEvent(
  oldHealth: 100,
  newHealth: 110,
  source: 'potion',
));
```

### 레거시 코드 (호환 유지)

```dart
// 기존 코드는 그대로 작동
eventManager.dispatchEvent(GameEvent(
  type: GameEventType.HEALTH_CHANGED,
  data: {'amount': 10},
));
// → LegacyEventAdapter가 자동으로 GEvent로 변환
```

## ✨ GEvent 시스템의 이점

- ✅ **타입 안전성**: GEvent는 컴파일 타임 타입 체크
- ✅ **명확한 계약**: 각 이벤트의 필드가 명확히 정의됨
- ✅ **IDE 지원**: 자동완성 및 리팩토링 지원
- ✅ **디버깅**: 이벤트 타입이 명확해 디버깅 용이
- ✅ **하위 호환성**: LegacyEventAdapter로 기존 코드 보호
- ✅ **유지보수**: 이벤트 구조 변경 시 컴파일 에러로 즉시 감지

## 📋 완료 작업 요약

| 작업 | 상태 | 날짜 |
|------|------|------|
| 레거시 시스템에 @Deprecated 추가 | ✅ 완료 | 2025-10-07 |
| LegacyEventAdapter 구현 | ✅ 완료 | 2025-10-07 |
| 인벤토리 시스템 100% 마이그레이션 | ✅ 완료 | 2025-10-07 |
| 불필요한 import 정리 (4개 파일) | ✅ 완료 | 2025-10-07 |
| 문서 업데이트 및 가이드 작성 | ✅ 완료 | 2025-10-07 |
| 현재 상태 분석 및 향후 계획 수립 | ✅ 완료 | 2025-10-07 |

## 🎯 결론

**마이그레이션 작업 1단계 완료 ✅**

현재 시스템은 안정적으로 작동하며, 신규 코드는 GEvent를 사용할 수 있습니다. `event_system.dart`의 완전한 제거는 대규모 리팩토링이 필요하므로, 현재로서는 두 시스템의 공존이 최선의 선택입니다.

신규 기능 개발 시에는 GEvent를 사용하여 점진적으로 새로운 시스템으로 전환하는 것을 권장합니다.

---

**최종 업데이트**: 2025-10-07  
**상태**: ✅ 안정적 (Stable) - 점진적 마이그레이션 전략 적용  
**다음 단계**: 신규 기능 개발 시 GEvent 사용
