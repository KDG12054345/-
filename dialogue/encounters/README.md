# 📚 Encounters Documentation

이 폴더는 인카운터 JSON 작성을 위한 **문서와 스키마 파일**을 포함합니다.

## 📁 폴더 구조

실제 인카운터 JSON 파일들은 다음 폴더에 위치합니다:

```
assets/dialogue/
├── start/           # 시작 인카운터 (게임 시작 시 1회)
├── main/            # 메인 스토리 인카운터
└── random/          # 반복 발생 랜덤 인카운터
    ├── trap/        # 함정 인카운터
    ├── combat/      # 전투 인카운터
    └── meeting/     # 만남 인카운터
```

## 📖 문서 파일

### 스키마 참고 문서
- **SCHEMA_COMPACT.json** - 간결한 스키마 레퍼런스 (JSON 형식)
- **SCHEMA_REFERENCE.md** - 완전한 스키마 문서 (Markdown)
- **COMPLETE_SCHEMA.json** - 전체 스키마 정의

### 가이드 문서
- **DIALOGUE_FORMAT_GUIDE.md** - DialogueEngine JSON 형식 가이드
- **PROMPT_FOR_AI.md** - AI에게 제공할 프롬프트용 간결한 스키마

## 🎯 인카운터 작성 시작하기

### 1. 어떤 카테고리에 넣을지 결정
- **start/** - 게임 시작 시 한 번만 실행
- **main/** - 메인 스토리 진행
- **random/trap/** - 랜덤 함정 이벤트
- **random/combat/** - 랜덤 전투 이벤트
- **random/meeting/** - 랜덤 만남 이벤트

### 2. JSON 파일 작성
기본 형식:
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

### 3. index.json에 등록
해당 카테고리의 `index.json`에 파일 경로와 가중치 추가

## 🔧 사용 예시

```dart
// 랜덤 인카운터 선택
final path = await DialogueIndex.instance.selectRandomEncounter();

// 특정 카테고리에서만 선택
final combatPath = await DialogueIndex.instance.selectRandomEncounterFromCategory('combat');

// 메인 스토리 인카운터
final mainEncounters = await DialogueIndex.instance.getMainEncounters();
```

## 📝 네이밍 규칙

- **파일명**: `{내용}_encounter.json` 또는 `{챕터명}.json`
- **씬 이름**: `{상황}_{단계}` 또는 `{내용}_encounter`
- **선택지 ID**: `fight`, `run`, `talk`, `intimidate`, etc.

## ✅ 체크리스트

인카운터를 만들 때:
- [ ] 적절한 카테고리 폴더에 JSON 파일 생성
- [ ] 해당 폴더의 index.json에 등록
- [ ] 가중치(weight) 설정
- [ ] 태그(tags) 추가 (선택사항)
- [ ] 조건(conditions) 확인
- [ ] 모든 씬이 `{"end": true}`로 종료되는지 확인



