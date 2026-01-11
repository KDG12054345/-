# Metadata 기반 XP 시스템 구현 완료

## 📋 개요

인카운터 JSON 파일의 `metadata.xp` 필드를 통해 **개발자가 직접 1~3 XP를 설정**할 수 있도록 구현되었습니다.

---

## ✅ 구현 내용

### 1. EncounterController 수정
**파일**: `lib/modules/encounter/encounter_controller.dart`

#### 추가된 기능
- `_extractMetadataXp()`: DialogueEngine의 metadata에서 xp 값 추출
- metadata.xp가 1~3 범위 내 정수인지 검증
- 추출된 xp 값을 `EncounterEnded` 이벤트의 outcome에 포함

```dart
// 🆕 metadata에서 XP 추출
int? _extractMetadataXp() {
  if (_engine?.runtime?.dialogueData.metadata != null) {
    final metadata = _engine!.runtime!.dialogueData.metadata!;
    if (metadata.containsKey('xp')) {
      final xpValue = metadata['xp'];
      if (xpValue is int && xpValue >= 1 && xpValue <= 3) {
        return xpValue;
      }
    }
  }
  return null;
}
```

#### 적용 지점
- Line 104: 대화 종료 시 (isEnded)
- Line 129: 대화 완료 시

---

### 2. 반복 인카운터 JSON 파일 생성

#### 함정 (trap/) - 1 XP
```
assets/dialogue/random/trap/
├── spike_trap.json (1 XP)
└── poison_gas.json (1 XP)
```

#### 전투 (combat/) - 2~3 XP
```
assets/dialogue/random/combat/
├── goblin_encounter.json (2 XP)
├── bandit_encounter.json (2 XP)
└── wolf_pack.json (3 XP)
```

#### 만남 (meeting/) - 1 XP
```
assets/dialogue/random/meeting/
├── merchant_encounter.json (1 XP)
└── traveler_encounter.json (1 XP)
```

#### JSON 파일 형식 예시
```json
{
  "metadata": {
    "xp": 2
  },
  "goblin_encounter": {
    "ops": [
      {"say": "고블린이 나타났다!"},
      {"say": "전투가 시작되었다."},
      {"say": "당신은 고블린을 물리쳤다!"}
    ]
  }
}
```

---

### 3. XP 처리 흐름

```
┌─────────────────────┐
│ DialogueEngine      │
│ (metadata 포함)     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ EncounterController │
│ _extractMetadataXp()│
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ EncounterEnded      │
│ outcome: {xp: 2}    │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ XpModule            │
│ (반복 인카운터 확인)│
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ XpService           │
│ outcome['xp'] 사용  │
└─────────────────────┘
```

---

## 🎯 XP 값 가이드라인

| XP | 난이도 | 인카운터 타입 | 예시 |
|----|--------|--------------|------|
| 1  | 쉬움   | 함정, 만남    | spike_trap, merchant |
| 2  | 중간   | 일반 전투     | goblin, bandit |
| 3  | 어려움 | 강력한 전투   | wolf_pack |

---

## ✅ 테스트 결과

### 테스트 파일
`test/xp/metadata_xp_test.dart`

### 테스트 시나리오 (8개 모두 통과 ✅)
1. ✅ 1 XP 인카운터 (함정)
2. ✅ 2 XP 인카운터 (전투)
3. ✅ 3 XP 인카운터 (어려운 전투)
4. ✅ 다양한 XP 값의 여러 인카운터
5. ✅ metadata 없는 경우 기본값(10 XP)
6. ✅ 범위 초과 XP 값 (그대로 사용)
7. ✅ metadata XP로 마일스톤 도달
8. ✅ 현실적인 게임플레이 패턴

### 실행 결과
```bash
00:14 +8: All tests passed!
```

---

## 📝 XP 처리 규칙

### 우선순위
1. **metadata.xp**: 1~3 범위의 정수 (최우선)
2. **outcome['xp']**: 직접 설정된 XP 값
3. **기본값**: 10 XP (metadata와 outcome 모두 없는 경우)

### 검증 로직
```dart
// EncounterController._extractMetadataXp()
if (xpValue is int && xpValue >= 1 && xpValue <= 3) {
  return xpValue; // ✅ 유효
}
return null; // ❌ 무시 (범위 초과 or 타입 불일치)
```

### 반복 인카운터만 XP 지급
```dart
// XpModule._isRepeatEncounter()
return encounterPath.contains('/random/');
```

- ✅ `/random/` 폴더: XP 지급
- ❌ `/start/`, `/main/`: XP 없음

---

## 📁 관련 파일

### 수정된 파일
- `lib/modules/encounter/encounter_controller.dart`

### 새로 생성된 파일
- `assets/dialogue/random/trap/spike_trap.json`
- `assets/dialogue/random/trap/poison_gas.json`
- `assets/dialogue/random/combat/goblin_encounter.json`
- `assets/dialogue/random/combat/bandit_encounter.json`
- `assets/dialogue/random/combat/wolf_pack.json`
- `assets/dialogue/random/meeting/merchant_encounter.json`
- `assets/dialogue/random/meeting/traveler_encounter.json`
- `assets/dialogue/random/XP_README.md`
- `test/xp/metadata_xp_test.dart`
- `IMPLEMENTATION_SUMMARY_METADATA_XP.md` (이 파일)

---

## 🔧 새 인카운터 추가 방법

### 1단계: JSON 파일 생성
```json
{
  "metadata": {
    "xp": 2
  },
  "my_encounter": {
    "ops": [
      {"say": "인카운터 내용..."}
    ]
  }
}
```

### 2단계: index.json 업데이트
```json
{
  "files": [
    {
      "id": "my_encounter",
      "path": "assets/dialogue/random/combat/my_encounter.json",
      "weight": 10
    }
  ]
}
```

### 3단계: XP 값 결정
- 플레이 시간 짧음 → 1 XP
- 전투 있음 → 2 XP
- 복잡하거나 위험 → 3 XP

---

## ⚠️ 주의사항

1. **metadata.xp는 필수가 아님**
   - 없으면 기본 10 XP 지급
   - 권장: 모든 반복 인카운터에 설정

2. **범위 준수**
   - 1~3 범위 벗어나면 무시됨
   - null로 처리되어 기본값 사용

3. **반복 인카운터만 해당**
   - `/random/` 폴더 내 인카운터만
   - start, main, theme, story는 XP 없음

4. **디버그 로그 확인**
   ```
   [XpModule] Gained 2 XP from goblin_encounter
   [XpService] XpChange(0 → 2, +2 from encounter: goblin_encounter)
   ```

---

## 🎯 향후 확장 가능성

### 동적 XP 계산
metadata에 난이도 정보 추가 후 조정:
```json
{
  "metadata": {
    "xp": 2,
    "difficulty": "medium",
    "modifiers": {
      "perfect_victory": 1.5,
      "no_damage": 1.2
    }
  }
}
```

### 조건부 XP
플레이어 행동에 따른 XP 변동:
```dart
final baseXp = metadata['xp'];
final multiplier = outcome['perfect'] ? 1.5 : 1.0;
final finalXp = (baseXp * multiplier).round();
```

---

## ✅ 완료 체크리스트

- [x] EncounterController에서 metadata.xp 추출
- [x] 반복 인카운터 JSON 파일 생성 (7개)
- [x] metadata.xp 설정 (1~3 범위)
- [x] XP 처리 흐름 검증
- [x] 단위 테스트 작성 및 통과 (8개)
- [x] 문서화 (XP_README.md, 구현 요약)

---

## 🎉 결과

**반복 인카운터는 이제 개발자가 JSON 파일에서 직접 1~3 XP를 설정할 수 있으며, 모든 테스트가 통과하여 안정적으로 작동합니다!**

