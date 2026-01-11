# DialogueEngine 인카운터 작성 형식

다른 AI에게 제공할 프롬프트용 간결한 스키마입니다.

---

## 기본 구조

```json
{
  "scene_name": {
    "ops": [
      {"say": "텍스트"},
      {"choice": [...]},
      {"effect": {...}},
      {"end": true}
    ]
  }
}
```

---

## 오퍼레이션(ops)

### 1. say - 텍스트
```json
{"say": "내용", "speaker": "화자(선택)"}
```

### 2. choice - 선택지
```json
{
  "choice": [
    {
      "id": "필수",
      "text": "필수",
      "next": {"scene": "다음씬"},
      "conditions": { /* 선택 */ },
      "effects": [ /* 선택 */ ]
    }
  ]
}
```

### 3. effect - 상태 변경
```json
{
  "effect": {
    "stat": {"스탯명": 변경량},
    "flag": {"플래그명": true},
    "item": {"add": "id", "remove": "id"}
  }
}
```

### 4. jump - 파일 이동
```json
{"jump": {"file": "경로", "scene": "씬"}}
```

### 5. end - 종료
```json
{"end": true}
```

---

## 조건(conditions)

```json
"conditions": {
  "stats": {"strength": 10},
  "items": ["sword"],
  "flags": {"quest_done": true}
}
```

**타입**: `hasStat`, `hasItem`, `hasFlag`, `and`, `or`, `not`, `custom`

---

## 효과(effects)

### 간단
```json
"effect": {
  "stat": {"hp": -10},
  "flag": {"done": true},
  "item": {"add": "sword"}
}
```

### 고급
```json
"effects": [
  {"type": "changeStat", "data": {"stats": {"hp": -10}}},
  {"type": "addItem", "data": {"item": "sword"}},
  {"type": "setFlag", "data": {"flag": "done", "value": true}}
]
```

**타입**: `changeStat`, `addItem`, `removeItem`, `setFlag`, `changeScene`, `customEvent`

---

## next 옵션

```json
"next": {"scene": "다음씬"}
"next": {"jump": {"file": "경로", "scene": "씬"}}
"next": {"end": true}
```

---

## 인카운터 템플릿

```json
{
  "encounter_start": {
    "ops": [
      {"say": "적 등장!"},
      {"say": "적: 대사"},
      {
        "choice": [
          {
            "id": "fight",
            "text": "싸운다",
            "next": {"scene": "combat"}
          },
          {
            "id": "intimidate",
            "text": "[힘 12] 위협",
            "conditions": {"stats": {"strength": 12}},
            "next": {"scene": "intimidate_success"}
          },
          {
            "id": "run",
            "text": "도망",
            "next": {"scene": "escape"}
          }
        ]
      }
    ]
  },
  
  "combat": {
    "ops": [
      {"say": "전투 시작!"},
      {"effect": {"flag": {"in_combat": true}}},
      {"end": true}
    ]
  },
  
  "intimidate_success": {
    "ops": [
      {"say": "위협 성공!"},
      {"effect": {"stat": {"reputation": 1}}},
      {"end": true}
    ]
  },
  
  "escape": {
    "ops": [
      {"say": "도망쳤다!"},
      {"effect": {"stat": {"stamina": -10}}},
      {"end": true}
    ]
  }
}
```

---

## 규칙

1. **씬 이름**: `{적}_encounter`, `combat`, `success`, `fail`
2. **선택지 id**: `fight`, `run`, `talk`, `intimidate`, `persuade`
3. **조건**: stats, items, flags 사용
4. **효과**: stat, flag, item 변경
5. **종료**: 각 결과 씬은 `{"end": true}`로 끝

---

## 예시 요청

"고블린 인카운터를 만들어줘. 선택지: 싸우기, 위협(힘 12), 설득(금화 5), 도망"

→ 위 템플릿 형식으로 작성

---

**이 형식을 사용해 인카운터 JSON을 생성하세요.**
















