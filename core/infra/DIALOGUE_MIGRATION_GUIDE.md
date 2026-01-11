# Dialogue 시스템 마이그레이션 가이드

## 개요

레거시 `DialogueManager` / `EnhancedDialogueManager` / `SimpleDialogueManagerV2`를 새로운 `lib/dialogue/` 시스템으로 마이그레이션하는 작업입니다.

## ✅ 최종 완료 상태

### 1. LegacyDialogueAdapter 구현 완료
- `lib/core/infra/legacy_dialogue_adapter.dart`
- 레거시 DialogueManager API를 DialogueEngine으로 변환
- 기존 UI 코드 변경 없이 새 시스템 사용 가능

### 2. 테스트 작성 완료
- `test/dialogue/legacy_dialogue_adapter_test.dart`
- 기본 어댑터 기능 검증
- 게임 상태 접근 테스트

### 3. 문서 작성 완료
- 마이그레이션 전략 문서화
- 점진적 교체 가이드 작성

## 📊 현재 시스템 상태

### 레거시 시스템 (계속 사용 중)

**제거하지 않을 파일들**:
1. **DialogueManager** (`lib/dialogue_manager.dart`)
   - EventSystem 깊은 의존성
   - 저장/불러오기 시스템과 통합
   - 대규모 리팩토링 필요
   - **현재 상태 유지 권장** ⭐

2. **EnhancedDialogueManager** (`lib/enhanced_dialogue_manager.dart`)
   - 스킬 체크 기능 통합
   - DialogueManager 상속
   - 향후 플러그인으로 분리 가능

3. **SimpleDialogueManagerV2** (`lib/simple_dialogue_manager_v2.dart`)
   - 간단한 스트리밍 방식
   - 독립적으로 잘 작동
   - 계속 사용 가능

### 새로운 시스템

**사용 가능 파일들**:
- `lib/dialogue/dialogue_engine.dart` - 메인 엔진
- `lib/dialogue/core/*.dart` - 핵심 데이터 모델
- `lib/dialogue/loaders/*.dart` - 로더
- `lib/dialogue/plugins/*.dart` - 플러그인 시스템
- `lib/dialogue/widgets/*.dart` - UI 위젯

## 🔄 마이그레이션 전략

### ⭐ 권장 전략: "최소 간섭 + 점진적 확장"

Event 시스템 마이그레이션 경험을 바탕으로 한 안전한 접근 방식입니다.

#### Phase 1: 어댑터만 구현 (완료 ✅)
```
목표: 기존 코드는 건드리지 않고, 새 시스템 사용 준비만
시간: 1-2일
리스크: 매우 낮음
```

**완료 항목**:
- ✅ LegacyDialogueAdapter 생성
- ✅ 기본 API 매핑 (showLine, getChoices, handleChoice)
- ✅ 게임 상태 접근 호환
- ✅ 테스트 작성
- ✅ 문서 작성

#### Phase 2: 신규 개발만 새 시스템 (진행 중 🔄)
```
규칙: 새로 만드는 것만 DialogueEngine 사용
     기존 것은 절대 건드리지 않음
기간: 무기한 (지속적)
```

**사용 시점**:
- ✅ 새 NPC 대화 작성 시
- ✅ 새 퀘스트 대화 추가 시
- ✅ 새 이벤트 씬 제작 시
- ❌ 기존 대화 수정 시 (레거시 유지)

#### Phase 3: 선택적 교체 (나중에 ⏰)
```
조건: 아래 경우에만 교체
- 해당 대화에 버그 수정이 필요할 때
- 새 기능 추가가 필요할 때
- 대규모 리팩토링 중일 때
```

**교체하지 않는 경우**:
- ❌ 교체 자체를 목표로 하는 작업
- ❌ "레거시를 줄이자"는 목표
- ❌ 완전 마이그레이션 시도

## 💡 핵심 원칙

### 원칙 1: "If it ain't broke, don't fix it"
> 작동하는 코드는 건드리지 않는다

**적용**:
- DialogueManager가 잘 작동 중 → 그냥 놔둠
- EnhancedDialogueManager도 계속 사용
- SimpleDialogueManagerV2도 유지

### 원칙 2: "New code only"
> 새 코드만 새 시스템 사용

**적용**:
```dart
// 새 대화 작성 시
final engine = DialogueEngine();  // ✅ 새 시스템
await engine.loadDialogue('assets/dialogue/new_npc.json');

// 기존 대화 수정 시
final manager = DialogueManager();  // ✅ 레거시 유지
await manager.loadDialogue('assets/dialogue/old_npc.json');
```

### 원칙 3: "레거시를 줄이려고 하지 않는다"
> 레거시 제거는 목표가 아님

**올바른 사고**:
- ✅ 새 시스템이 점점 늘어남
- ✅ 레거시 비율은 자연스럽게 줄어듦
- ✅ 레거시가 영원히 남아도 괜찮음

**잘못된 사고**:
- ❌ "레거시를 30%로 줄이자"
- ❌ "이번 주에 레거시 3개 교체하자"
- ❌ "완전 마이그레이션이 목표다"

## 📝 실전 예제

### 예제 1: 기존 UI 코드를 어댑터로 교체

**Before (레거시 그대로)**:
```dart
import 'package:text/dialogue_manager.dart';

class GameScreen extends StatefulWidget {
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late DialogueManager _manager;
  
  @override
  void initState() {
    super.initState();
    _manager = DialogueManager();
    _loadDialogue();
  }
  
  Future<void> _loadDialogue() async {
    await _manager.loadDialogue('assets/dialogue/intro.json');
    _manager.setScene('intro_start');
    setState(() {});
  }
  
  void _handleChoice(String choiceId) {
    _manager.handleChoice(choiceId);
    setState(() {});
  }
}
```

**After (어댑터 사용 - UI 코드 변경 없음!)**:
```dart
import 'package:text/core/infra/legacy_dialogue_adapter.dart';  // ← 이것만 변경

class GameScreen extends StatefulWidget {
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late LegacyDialogueAdapter _manager;  // ← 타입만 변경
  
  @override
  void initState() {
    super.initState();
    _manager = LegacyDialogueAdapter();  // ← 생성자만 변경
    _loadDialogue();
  }
  
  // 나머지 코드는 완전히 동일!
  Future<void> _loadDialogue() async {
    await _manager.loadDialogue('assets/dialogue/intro.json');
    _manager.setScene('intro_start');
    setState(() {});
  }
  
  void _handleChoice(String choiceId) {
    _manager.handleChoice(choiceId);
    setState(() {});
  }
}
```

### 예제 2: 새 대화는 DialogueEngine 직접 사용

```dart
import 'package:text/dialogue/dialogue_engine.dart';

class NewNPCScreen extends StatefulWidget {
  @override
  State<NewNPCScreen> createState() => _NewNPCScreenState();
}

class _NewNPCScreenState extends State<NewNPCScreen> {
  late DialogueEngine _engine;  // ✅ 새 시스템 직접 사용
  
  @override
  void initState() {
    super.initState();
    _engine = DialogueEngine();
    _loadDialogue();
  }
  
  Future<void> _loadDialogue() async {
    await _engine.loadDialogue('assets/dialogue/new_npc.json');
    await _engine.start();
    setState(() {});
  }
  
  Future<void> _handleChoice(String choiceId) async {
    await _engine.selectChoice(choiceId);
    setState(() {});
  }
  
  @override
  Widget build(BuildContext context) {
    final view = _engine.getCurrentView();
    if (view == null) return Container();
    
    return Column(
      children: [
        if (view.hasText) Text(view.text!),
        ...view.choices.map((choice) => 
          ElevatedButton(
            onPressed: () => _handleChoice(choice.id),
            child: Text(choice.text),
          ),
        ),
      ],
    );
  }
}
```

## 🚨 주의사항

### ⚠️ 하지 말아야 할 것

1. **레거시 코드를 찾아서 교체하지 마세요**
   ```dart
   // ❌ 이런 작업은 하지 마세요
   // "이번 주 목표: 레거시 DialogueManager 5개 교체"
   ```

2. **작동하는 코드를 건드리지 마세요**
   ```dart
   // ❌ 이미 잘 작동하는 대화를 굳이 교체하지 마세요
   // "버그 없고 잘 되는데 새 시스템으로 바꿔야지"
   ```

3. **완전 교체를 목표로 하지 마세요**
   ```dart
   // ❌ 이런 목표는 설정하지 마세요
   // "6개월 내 DialogueManager 완전 제거"
   ```

### ✅ 해야 할 것

1. **새 기능만 새 시스템 사용**
   ```dart
   // ✅ 새로 만드는 대화
   final engine = DialogueEngine();
   ```

2. **버그 수정 시 선택적 교체 고려**
   ```dart
   // ✅ 버그가 있는 레거시 대화를 수정할 때
   // "어차피 고치는 김에 새 시스템으로 바꿀까?" ← OK
   ```

3. **어댑터로 안전하게 전환**
   ```dart
   // ✅ UI는 그대로, 내부만 교체
   LegacyDialogueAdapter()  // 대신 사용
   ```

## 📊 성공 지표

### ✅ 성공의 정의

- 신규 대화가 DialogueEngine으로 작성됨
- 기존 대화가 계속 잘 작동함
- 버그가 증가하지 않음
- 팀이 두 시스템을 구분할 수 있음
- 개발 속도가 유지되거나 향상됨

### ❌ 실패의 정의 (이런 사고방식)

- "레거시가 50% 남았으니 실패다"
- "DialogueManager를 완전히 못 없앴으니 의미 없다"
- "교체 속도가 느리다"

## 🎯 로드맵

### 현재 (2025-10-07) ✅
- [x] LegacyDialogueAdapter 구현
- [x] 기본 테스트 작성
- [x] 마이그레이션 가이드 작성

### 다음 단계 (진행 중 🔄)
- [ ] 새 NPC 대화는 DialogueEngine 사용
- [ ] 새 퀘스트는 DialogueEngine 사용
- [ ] 팀에 사용법 공유

### 나중에 (선택적 ⏰)
- [ ] 버그 있는 레거시 대화 교체 고려
- [ ] EnhancedDialogueManager → 플러그인 분리 고려
- [ ] 완전 교체는 "검토만" (실행 X)

## 🔍 Event 시스템에서 배운 교훈

### ✅ 잘한 점

1. **LegacyEventAdapter로 안전하게 공존**
   - 레거시와 새 시스템이 평화롭게 공존
   - UI 코드 변경 없음
   - 점진적 전환 가능

2. **신규 코드만 새 시스템 사용**
   - 인벤토리 시스템: 100% GEvent
   - 새로운 기능: GEvent 사용
   - 레거시: 그대로 유지

3. **완전 제거를 강요하지 않음**
   - DialogueManager, EventSystem 모두 유지 중
   - "영구 공존"도 OK
   - 안정성 최우선

### ⚠️ 주의할 점

1. **두 시스템 공존 복잡도**
   - 신입이 배울 게 많아짐
   - 문서화 필수
   - 명확한 규칙 필요

2. **이중 유지보수 비용**
   - 두 시스템 모두 관리
   - 버그 수정도 두 배
   - 어댑터도 관리 필요

3. **영구 미완성 가능성**
   - 10년 후에도 레거시 남을 수 있음
   - 하지만 괜찮음!
   - 안정성이 더 중요

## 📚 참고 문서

- [Event 시스템 마이그레이션 가이드](../MIGRATION_GUIDE.md)
- [DialogueEngine API 문서](../../dialogue/dialogue_engine.dart)
- [LegacyDialogueAdapter 소스](./legacy_dialogue_adapter.dart)

## 💡 FAQ

### Q: 레거시 코드를 언제 교체해야 하나요?
**A: 교체하지 마세요.** 새 것만 새 시스템으로 만드세요.

### Q: DialogueManager를 완전히 없앨 수 있나요?
**A: 가능하지만 권장하지 않습니다.** 대규모 리팩토링이 필요하고 리스크가 높습니다.

### Q: 레거시 비율이 안 줄어드는데 괜찮나요?
**A: 완전히 괜찮습니다.** 새 시스템이 늘어나는 게 더 중요합니다.

### Q: 언제 완전 마이그레이션을 고려하나요?
**A: 레거시 비율이 10% 이하로 떨어지면 고려.** 그 전까지는 공존 유지.

### Q: 어댑터 성능이 걱정됩니다.
**A: 미미한 오버헤드입니다.** 실제 측정 전까지는 걱정하지 마세요.

---

**최종 업데이트**: 2025-10-07  
**상태**: ✅ Phase 1 완료 - 점진적 공존 전략 적용  
**다음 단계**: 신규 개발 시 DialogueEngine 사용

