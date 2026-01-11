# 반복 인카운터 XP 설정 가이드

## 📋 개요

반복 인카운터는 각 JSON 파일의 `metadata.xp` 필드에서 **1~3 XP**를 개발자가 직접 설정합니다.

---

## ✅ 설정 규칙

### XP 범위
- **1 XP**: 쉬운 인카운터 (함정, 만남)
- **2 XP**: 중간 난이도 (일반 전투)
- **3 XP**: 어려운 인카운터 (강력한 전투)

### JSON 파일 형식
```json
{
  "metadata": {
    "xp": 1
  },
  "encounter_id": {
    "ops": [
      {"say": "인카운터 내용..."}
    ]
  }
}
```

---

## 📁 현재 설정된 인카운터

### 함정 (trap/) - 1 XP
- `spike_trap.json`: 1 XP
- `poison_gas.json`: 1 XP

### 전투 (combat/)
- `goblin_encounter.json`: 2 XP (중간)
- `bandit_encounter.json`: 2 XP (중간)
- `wolf_pack.json`: 3 XP (어려움)

### 만남 (meeting/) - 1 XP
- `merchant_encounter.json`: 1 XP
- `traveler_encounter.json`: 1 XP

---

## 🔧 새 인카운터 추가 방법

1. **JSON 파일 생성**
   ```json
   {
     "metadata": {
       "xp": 2
     },
     "my_new_encounter": {
       "ops": [
         {"say": "내용..."}
       ]
     }
   }
   ```

2. **index.json 업데이트**
   ```json
   {
     "files": [
       {
         "id": "my_new_encounter",
         "path": "assets/dialogue/random/combat/my_new_encounter.json",
         "weight": 10
       }
     ]
   }
   ```

3. **XP 값 가이드라인**
   - 플레이 시간이 짧으면 1 XP
   - 전투가 있으면 2 XP
   - 복잡하거나 위험하면 3 XP

---

## ⚠️ 주의사항

1. **metadata.xp는 필수**: 없으면 기본 10 XP가 지급됨
2. **범위 엄수**: 1~3 범위를 벗어나면 무시됨
3. **반복 인카운터만**: `/random/` 폴더 내 인카운터만 XP 지급
4. **start, main은 XP 없음**: 시작/메인 인카운터는 XP를 주지 않음

---

## 🎯 테스트 방법

```dart
// lib/modules/xp/xp_module.dart에서 디버그 로그 확인
// [XpModule] Not a repeat encounter → XP 없음
// [XpModule] Gained X XP → XP 획득
```

