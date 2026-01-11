# 📖 Dialogue System

DialogueEngine을 사용한 대화 및 인카운터 시스템입니다.

## 📁 폴더 구조

```
assets/dialogue/
├── encounters/          # 📚 문서 및 스키마 (실제 파일 아님)
│   ├── README.md
│   ├── SCHEMA_COMPACT.json
│   ├── SCHEMA_REFERENCE.md
│   ├── DIALOGUE_FORMAT_GUIDE.md
│   └── ...
│
├── start/              # 🎬 시작 인카운터
│   ├── index.json
│   └── start_001.json
│
├── main/               # 📜 메인 스토리
│   ├── index.json
│   └── chapter_01.json
│
└── random/             # 🎲 랜덤 인카운터
    ├── index.json      # 카테고리 정의
    │
    ├── trap/           # 🪤 함정
    │   ├── index.json
    │   ├── spike_trap.json
    │   └── poison_gas.json
    │
    ├── combat/         # ⚔️ 전투
    │   ├── index.json
    │   ├── goblin_encounter.json
    │   ├── bandit_encounter.json
    │   └── wolf_pack.json
    │
    └── meeting/        # 👥 만남
        ├── index.json
        ├── merchant_encounter.json
        └── traveler_encounter.json
```

## 🎯 각 폴더의 역할

### start/ - 시작 인카운터
- 게임 시작 버튼을 누르면 **1회만** 실행
- 여러 파일 중 가중치 기반 랜덤 선택
- 게임의 첫인상을 만드는 중요한 인카운터

### main/ - 메인 스토리
- 게임의 주요 스토리 진행
- 순서대로 진행되는 챕터
- `unlockConditions`로 잠금 관리

### random/ - 반복 랜덤 인카운터
플레이 중 반복적으로 발생하는 인카운터들:

#### trap/ - 함정
- 가시 함정, 독가스 등
- 회피/대처 선택지 제공
- 주로 피해 발생

#### combat/ - 전투
- 적 조우 이벤트
- 전투, 도망, 협상 등 선택지
- 전투 시스템 연동

#### meeting/ - 만남
- NPC 만남
- 상점, 정보 제공, 퀘스트 등
- 주로 우호적 상호작용

## 🔧 DialogueIndex API

### 시작 인카운터
```dart
final startEncounters = await DialogueIndex.instance.getStartEncounters();
```

### 메인 스토리
```dart
final mainEncounters = await DialogueIndex.instance.getMainEncounters();
```

### 랜덤 인카운터
```dart
// 모든 카테고리에서 가중치 기반 랜덤 선택
final path = await DialogueIndex.instance.selectRandomEncounter();

// 특정 카테고리에서만 선택
final trapPath = await DialogueIndex.instance.selectRandomEncounterFromCategory('trap');
final combatPath = await DialogueIndex.instance.selectRandomEncounterFromCategory('combat');
final meetingPath = await DialogueIndex.instance.selectRandomEncounterFromCategory('meeting');

// 카테고리별로 모두 가져오기
final allRandom = await DialogueIndex.instance.getAllRandomEncounters();
// allRandom['trap'], allRandom['combat'], allRandom['meeting']
```

## 📝 새 인카운터 추가하기

1. **적절한 폴더 선택**
   - 게임 시작용? → `start/`
   - 메인 스토리? → `main/`
   - 반복 이벤트? → `random/{category}/`

2. **JSON 파일 작성**
   - `encounters/` 폴더의 문서 참고
   - 기본 형식: ops 배열 사용

3. **index.json에 등록**
   ```json
   {
     "id": "unique_id",
     "path": "assets/dialogue/.../file.json",
     "weight": 10,
     "tags": ["tag1", "tag2"]
   }
   ```

4. **테스트**
   - DialogueEngine으로 로드 테스트
   - 모든 분기 확인

## 🎮 가중치 시스템

### 카테고리 가중치 (random/index.json)
```json
{
  "categories": [
    {"id": "trap", "weight": 20},    // 20% 확률
    {"id": "combat", "weight": 50},  // 50% 확률
    {"id": "meeting", "weight": 30}  // 30% 확률
  ]
}
```

### 인카운터 가중치 (각 카테고리/index.json)
```json
{
  "files": [
    {"path": "...", "weight": 15},  // 더 자주 등장
    {"path": "...", "weight": 10},  // 보통
    {"path": "...", "weight": 5}    // 드물게 등장
  ]
}
```

## 📚 추가 문서

자세한 내용은 `encounters/` 폴더의 문서를 참고하세요:
- 스키마 레퍼런스
- 작성 가이드
- 예시 파일들



