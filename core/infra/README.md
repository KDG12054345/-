# Infrastructure Layer (인프라 레이어)

마이그레이션과 시스템 통합을 위한 어댑터 및 브릿지 레이어입니다.

## 📦 포함된 파일들

### 1. LegacyEventAdapter
**파일**: `legacy_event_adapter.dart`  
**목적**: 레거시 `EventManager` → 새로운 `GEvent` 시스템 변환

**사용 예**:
```dart
final adapter = LegacyEventAdapter(gameController.dispatch);
adapter.initialize();

// 레거시 코드는 그대로 작동
eventManager.dispatchEvent(GameEvent(type: GameEventType.HEAL));
// → 자동으로 GEvent로 변환됨
```

**상태**: ✅ 완료 및 활성화

---

### 2. LegacyDialogueAdapter
**파일**: `legacy_dialogue_adapter.dart`  
**목적**: 레거시 `DialogueManager` → 새로운 `DialogueEngine` 변환

**사용 예**:
```dart
// 기존 코드
final manager = DialogueManager();

// 어댑터 사용 (UI 코드 변경 없음!)
final manager = LegacyDialogueAdapter();
await manager.loadDialogue('assets/dialogue/intro.json');
manager.handleChoice('choice1');
```

**상태**: ✅ 완료 (2025-10-07)

---

## 🎯 마이그레이션 전략

### 공통 원칙

1. **"If it ain't broke, don't fix it"**
   - 작동하는 레거시 코드는 건드리지 않음
   - 어댑터로 안전하게 공존

2. **"New code only"**
   - 새 기능만 새 시스템 사용
   - 레거시는 그대로 유지

3. **"점진적 공존"**
   - 레거시 제거를 강요하지 않음
   - 자연스럽게 비율만 변화
   - 영구 공존도 OK

### Event 시스템 전략

```
✅ 인벤토리: GEvent로 마이그레이션 완료
✅ 신규 코드: GEvent 사용
✅ 레거시 10개 파일: 유지
✅ DialogueManager: 유지 (EventSystem 의존)
```

**상세 가이드**: [MIGRATION_GUIDE.md](../MIGRATION_GUIDE.md)

### Dialogue 시스템 전략

```
✅ LegacyDialogueAdapter: 구현 완료
🔄 신규 대화: DialogueEngine 사용
✅ 레거시 3개 시스템: 유지
   - DialogueManager
   - EnhancedDialogueManager
   - SimpleDialogueManagerV2
```

**상세 가이드**: [DIALOGUE_MIGRATION_GUIDE.md](./DIALOGUE_MIGRATION_GUIDE.md)

---

## 📊 현재 상태 (2025-10-07)

| 시스템 | 어댑터 | 상태 | 레거시 비율 |
|--------|--------|------|-------------|
| Event | LegacyEventAdapter | ✅ 활성화 | ~10개 파일 |
| Dialogue | LegacyDialogueAdapter | ✅ 완료 | 3개 시스템 |

---

## 🚀 빠른 시작

### Event 시스템 (이미 적용됨)

```dart
// 레거시 코드는 그대로 작동
eventManager.dispatchEvent(GameEvent(
  type: GameEventType.HEALTH_CHANGED,
  data: {'amount': 10},
));

// 새 코드는 GEvent 사용
gameController.dispatch(HealthChangedEvent(
  oldHealth: 90,
  newHealth: 100,
));
```

### Dialogue 시스템 (적용 가능)

**기존 UI 코드 (변경 없음!)**:
```dart
// 이 import만 변경
import 'package:text/core/infra/legacy_dialogue_adapter.dart';

// 타입만 변경
final manager = LegacyDialogueAdapter();

// 나머지 코드는 완전히 동일
await manager.loadDialogue('assets/dialogue/intro.json');
manager.setScene('intro_start');
final choices = manager.getChoices();
manager.handleChoice(choiceId);
```

**신규 대화 작성**:
```dart
import 'package:text/dialogue/dialogue_engine.dart';

final engine = DialogueEngine();
await engine.loadDialogue('assets/dialogue/new_npc.json');
await engine.start();

final view = engine.getCurrentView();
if (view != null) {
  print(view.text);
  for (var choice in view.choices) {
    print('${choice.id}: ${choice.text}');
  }
}

await engine.selectChoice('choice1');
```

---

## 🧪 테스트

### Event Adapter
```bash
flutter test test/event_system_test.dart
```

### Dialogue Adapter
```bash
flutter test test/dialogue/legacy_dialogue_adapter_test.dart
```

---

## 📖 추가 문서

- [Event 시스템 마이그레이션](../MIGRATION_GUIDE.md)
- [Dialogue 시스템 마이그레이션](./DIALOGUE_MIGRATION_GUIDE.md)
- [DialogueEngine API 문서](../../dialogue/dialogue_engine.dart)

---

## 💡 팁

### ✅ 해야 할 것

1. 새 기능 개발 시 새 시스템 사용
2. 어댑터로 안전하게 전환
3. 레거시는 그대로 유지

### ❌ 하지 말아야 할 것

1. 작동하는 레거시 코드를 찾아서 교체
2. "레거시 비율 줄이기"를 목표로 설정
3. 완전 마이그레이션을 강요

---

**최종 업데이트**: 2025-10-07  
**작성자**: AI Assistant  
**상태**: ✅ 안정적 (Stable)

