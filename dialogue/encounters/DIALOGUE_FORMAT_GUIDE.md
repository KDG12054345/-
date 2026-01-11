# DialogueEngine JSON 형식 가이드

DialogueEngine은 **5가지 JSON 형식을 모두 지원**합니다. 상황에 맞는 형식을 선택하세요!

---

## 📝 지원하는 형식

### 1. **오퍼레이션 기반** (권장! ⭐)
**특징**: 깔끔하고 직관적, 순차 실행
**사용처**: 인카운터, 이벤트, 간단한 대화

```json
{
  "scene_name": {
    "ops": [
      {"say": "텍스트"},
      {"choice": [...]},
      {"effect": {...}},
      {"jump": {...}},
      {"end": true}
    ]
  }
}
```

**예제**: `goblin_encounter.json` 참고

---

### 2. **씬 기반** (레거시 호환)
**특징**: 기존 start_001.json과 유사
**사용처**: 레거시 코드 교체

```json
{
  "scene_1": {
    "start": {
      "text": "대화 내용"
    },
    "choices": {
      "choice_id": {
        "text": "선택지",
        "next_scene": "scene_2"
      }
    }
  }
}
```

---

### 3. **씬 배열 형식** (구조화된 대규모 프로젝트)
**특징**: 체계적, IDE 자동완성 우수
**사용처**: 큰 스토리, 챕터 시스템

```json
{
  "scenes": [
    {
      "id": "scene_1",
      "ops": [
        {"say": "..."}
      ]
    },
    {
      "id": "scene_2",
      "ops": [
        {"say": "..."}
      ]
    }
  ]
}
```

---

### 4. **노드 기반**
**특징**: 비선형 스토리, 복잡한 분기
**사용처**: 퍼즐, 탐정 게임

```json
{
  "startNode": "node1",
  "nodes": {
    "node1": {
      "text": "...",
      "choices": [...]
    },
    "node2": {
      "text": "...",
      "choices": [...]
    }
  }
}
```

---

### 5. **단순 텍스트**
**특징**: 초간단, 테스트용
**사용처**: 프로토타입, 빠른 테스트

```json
{
  "text": "단순한 텍스트 한 줄"
}
```

---

## 🎯 인카운터에 권장하는 형식

### **오퍼레이션 기반 (ops)** ⭐⭐⭐

**장점**:
- ✅ 깔끔하고 읽기 쉬움
- ✅ 순차 실행으로 로직 명확
- ✅ effect, choice, jump 등 모든 기능 지원
- ✅ 인카운터의 흐름과 잘 맞음

**인카운터 구조**:
```json
{
  "encounter_start": {
    "ops": [
      {"say": "적 등장!"},
      {"say": "적: 대사"},
      {
        "choice": [
          {"id": "fight", "text": "싸운다"},
          {"id": "run", "text": "도망친다"}
        ]
      }
    ]
  }
}
```

---

## 📋 주요 오퍼레이션 (ops) 종류

### 1. **say** - 텍스트 표시
```json
{"say": "표시할 텍스트"}
{"say": "화자: 대사"}
```

### 2. **choice** - 선택지
```json
{
  "choice": [
    {
      "id": "선택지_id",
      "text": "선택지 텍스트",
      "next": {"scene": "다음_씬"}
    }
  ]
}
```

**선택지 옵션**:
```json
{
  "id": "intimidate",
  "text": "[힘] 위협한다",
  "conditions": {                    // 조건
    "stats": {"strength": 12},
    "items": ["sword"],
    "flags": {"met_guard": true}
  },
  "next": {"scene": "success"}       // 다음 씬
}
```

### 3. **effect** - 게임 상태 변경
```json
{
  "effect": {
    "stat": {"hp": -10, "gold": 50},        // 스탯 변경
    "flag": {"quest_complete": true},       // 플래그 설정
    "item": {"add": "sword", "remove": "gold"}  // 아이템
  }
}
```

### 4. **jump** - 다른 파일로 이동
```json
{
  "jump": {
    "file": "assets/dialogue/town/merchant.json",
    "scene": "shop_intro"
  }
}
```

### 5. **end** - 대화 종료
```json
{"end": true}
```

---

## 🎮 인카운터 템플릿

### 기본 인카운터
```json
{
  "encounter_name": {
    "ops": [
      {"say": "적 등장 설명"},
      {"say": "적: 대사"},
      {
        "choice": [
          {"id": "fight", "text": "전투", "next": {"scene": "combat"}},
          {"id": "talk", "text": "대화", "next": {"scene": "dialogue"}},
          {"id": "run", "text": "도망", "next": {"scene": "escape"}}
        ]
      }
    ]
  },
  
  "combat": {
    "ops": [
      {"say": "전투가 시작된다!"},
      {"effect": {"flag": {"in_combat": true}}},
      {"end": true}
    ]
  }
}
```

### 조건부 선택지 인카운터
```json
{
  "bandit_encounter": {
    "ops": [
      {"say": "산적: \"지나가려면 통행료를 내!\""},
      {
        "choice": [
          {
            "id": "pay",
            "text": "금화 10개를 건넨다",
            "conditions": {"stats": {"gold": 10}},
            "next": {"scene": "peaceful"}
          },
          {
            "id": "intimidate",
            "text": "[힘 15] 위협한다",
            "conditions": {"stats": {"strength": 15}},
            "next": {"scene": "intimidate_win"}
          },
          {
            "id": "fight",
            "text": "싸운다",
            "next": {"scene": "fight"}
          }
        ]
      }
    ]
  }
}
```

### 체인 인카운터 (여러 단계)
```json
{
  "wolf_encounter_1": {
    "ops": [
      {"say": "늑대가 나타났다!"},
      {
        "choice": [
          {"id": "observe", "text": "관찰한다", "next": {"scene": "wolf_encounter_2"}}
        ]
      }
    ]
  },
  
  "wolf_encounter_2": {
    "ops": [
      {"say": "늑대가 경계하며 으르렁댄다."},
      {
        "choice": [
          {"id": "back_away", "text": "천천히 물러난다", "next": {"scene": "safe"}},
          {"id": "attack", "text": "선제공격", "next": {"scene": "combat"}}
        ]
      }
    ]
  }
}
```

---

## ✅ 사용 방법

### Dart 코드에서 로드
```dart
// 1. DialogueEngine 생성
final engine = DialogueEngine();

// 2. 인카운터 로드
await engine.loadDialogue('assets/dialogue/encounters/goblin_encounter.json');

// 3. 시작
await engine.start(fromScene: 'goblin_encounter');

// 4. 현재 화면 가져오기
final view = engine.getCurrentView();

// 5. 선택지 처리
await engine.selectChoice('fight');
```

### 전체 예제
```dart
class EncounterScreen extends StatefulWidget {
  @override
  State<EncounterScreen> createState() => _EncounterScreenState();
}

class _EncounterScreenState extends State<EncounterScreen> {
  late DialogueEngine _engine;
  
  @override
  void initState() {
    super.initState();
    _engine = DialogueEngine();
    _loadEncounter();
  }
  
  Future<void> _loadEncounter() async {
    await _engine.loadDialogue(
      'assets/dialogue/encounters/goblin_encounter.json'
    );
    await _engine.start(fromScene: 'goblin_encounter');
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
            onPressed: choice.enabled 
              ? () => _handleChoice(choice.id)
              : null,
            child: Text(choice.text),
          ),
        ),
      ],
    );
  }
}
```

---

## 🎯 권장사항

### ✅ 인카운터에는
- **오퍼레이션 기반 (ops)** 사용
- 명확한 씬 이름 (`goblin_encounter`, `combat_start`)
- 조건부 선택지 적극 활용
- effect로 게임 상태 변경

### ✅ 네이밍 규칙
```
파일명: {적_이름}_encounter.json
씬 이름: {상황}__{단계}

예:
- goblin_encounter.json
- 씬: goblin_encounter, combat_start, escape_success
```

### ✅ 구조
```
1. 메인 인카운터 씬
2. 분기별 결과 씬들
3. 각 씬은 end로 종료
```

---

**이 형식으로 모든 인카운터를 작성하면 됩니다!** ✅
















