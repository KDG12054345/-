# Chapter 구조 재편성 완료

## 📋 변경 사항 요약

**theme 폴더를 삭제하고, chapter 폴더가 XP 20, 40, 60, 80, 100에서 트리거되도록 변경**

---

## ✅ 완료된 작업

### 1️⃣ Theme 폴더 완전 삭제
- ❌ `assets/dialogue/main/theme/` 폴더 및 모든 하위 파일 삭제
- ❌ `theme_knight_*.json`, `theme_mage_*.json` 파일들 삭제

### 2️⃣ Chapter 폴더 생성
- ✅ `assets/dialogue/main/chapter/` 폴더 생성
- ✅ Knight 챕터 5개 생성 (20, 40, 60, 80, 100 XP)
- ✅ Mage 챕터 5개 생성 (20, 40, 60, 80, 100 XP)

### 3️⃣ xp_config.json 업데이트
- ✅ `themeMilestones` → `chapterMilestones`
- ✅ `tracks.theme` → `tracks.chapter`
- ✅ `theme_knight_*` → `chapter_knight_*`
- ✅ `theme_mage_*` → `chapter_mage_*`

### 4️⃣ pubspec.yaml 업데이트
- ✅ `assets/dialogue/main/theme/` → `assets/dialogue/main/chapter/`

### 5️⃣ 문서 업데이트
- ✅ `assets/dialogue/main/index.json` (theme → chapter)
- ✅ `assets/dialogue/main/README.md` (완전히 새로 작성)

---

## 📁 최종 폴더 구조

```
main/
├── chapter/          # ⭐ 메인 챕터 (XP 20, 40, 60, 80, 100)
│   ├── index.json
│   ├── chapter_knight_20.json
│   ├── chapter_knight_40.json
│   ├── chapter_knight_60.json
│   ├── chapter_knight_80.json
│   ├── chapter_knight_100.json
│   ├── chapter_mage_20.json
│   ├── chapter_mage_40.json
│   ├── chapter_mage_60.json
│   ├── chapter_mage_80.json
│   └── chapter_mage_100.json
├── story/            # 서브 스토리 (XP 10, 30, 50, 70, 90)
│   ├── index.json
│   ├── story_10.json
│   ├── story_30.json
│   ├── story_50.json
│   ├── story_70.json
│   └── story_90.json
├── index.json
└── README.md
```

---

## 🎯 Chapter 시스템

### 트리거 방식
**XP 20의 배수에서 자동 트리거!**

| XP  | Knight | Mage | 역할 |
|-----|--------|------|------|
| 20  | `chapter_knight_20.json` | `chapter_mage_20.json` | 1번째 챕터 |
| 40  | `chapter_knight_40.json` | `chapter_mage_40.json` | 2번째 챕터 |
| 60  | `chapter_knight_60.json` | `chapter_mage_60.json` | 3번째 챕터 |
| 80  | `chapter_knight_80.json` | `chapter_mage_80.json` | 4번째 챕터 |
| 100 | `chapter_knight_100.json` | `chapter_mage_100.json` | 최종 챕터 (엔딩) |

### 특징
- ✅ **XP 마일스톤 자동 트리거**
- ✅ **시작 테마 (기사/마법사)에 따라 다른 스토리**
- ✅ **플레이어 선택에 따른 분기**
- ❌ **Chapter는 XP를 주지 않음**

---

## 🔄 xp_config.json 변경사항

### Before (Theme)
```json
{
  "themeMilestones": [20, 40, 60, 80, 100],
  "tracks": {
    "theme": {
      "poolByStart": {
        "start_knight": ["theme_knight_20", ...],
        "start_mage": ["theme_mage_20", ...]
      }
    }
  }
}
```

### After (Chapter)
```json
{
  "chapterMilestones": [20, 40, 60, 80, 100],
  "tracks": {
    "chapter": {
      "poolByStart": {
        "start_knight": ["chapter_knight_20", ...],
        "start_mage": ["chapter_mage_20", ...]
      }
    }
  }
}
```

---

## 📖 Knight Chapter 스토리

### Chapter 1 (20 XP): 기사단 선택
- 기사단 합류 or 홀로 강해지기

### Chapter 2 (40 XP): 드래곤 위기
- 드래곤 전투 or 마을 사람 대피

### Chapter 3 (60 XP): 성검 획득
- 직접 돌파 or 숨겨진 통로

### Chapter 4 (80 XP): 어둠의 기사
- 결투 or 협상

### Chapter 5 (100 XP): 전설의 갑옷
- 성기사 완성 → 엔딩 트리거

---

## 📖 Mage Chapter 스토리

### Chapter 1 (20 XP): 고대 마법사의 탑
- 수수께끼 풀기 or 마법으로 강행

### Chapter 2 (40 XP): 차원의 균열
- 균열 봉인 or 균열 연구

### Chapter 3 (60 XP): 마법 아카데미
- 아카데미 입학 or 독학 계속

### Chapter 4 (80 XP): 금단의 마법
- 금단의 마법 or 순수한 길

### Chapter 5 (100 XP): 태초의 지팡이
- 대마법사 완성 → 엔딩 트리거

---

## 📊 플레이 흐름

```
게임 시작 (기사 선택)
  ↓
Random 인카운터 (XP 획득)
  ↓
10 XP → Story 10
  ↓
20 XP → Chapter Knight 20 (기사단 선택) ⭐
  ↓
30 XP → Story 30
  ↓
40 XP → Chapter Knight 40 (드래곤 위기) ⭐
  ↓
50 XP → Story 50
  ↓
60 XP → Chapter Knight 60 (성검 획득) ⭐
  ↓
70 XP → Story 70
  ↓
80 XP → Chapter Knight 80 (어둠의 기사) ⭐
  ↓
90 XP → Story 90
  ↓
100 XP → Chapter Knight 100 (전설의 갑옷) → Ending ⭐
```

---

## 🔧 코드 수정 필요 사항

현재 코드에서 `theme` 또는 `themeMilestones`를 참조하는 부분이 있다면, 모두 `chapter` / `chapterMilestones`로 변경해야 합니다:

### 수정 필요한 파일 (추정)
1. `lib/core/milestone/milestone_service.dart`
   - `themeMilestones` → `chapterMilestones`
   - `MilestoneType.theme` → `MilestoneType.chapter` (enum 이름 변경 필요)

2. `lib/core/schedule/encounter_scheduler.dart`
   - `runThemeEncounter` → `runChapterEncounter`
   - theme 관련 로직 → chapter 관련 로직

3. `lib/core/state/events.dart`
   - 이벤트명에 theme이 포함되어 있다면 chapter로 변경

4. `lib/services/dialogue_index.dart`
   - `getThemeEncounters` → `getChapterEncounters`

---

## ⚠️ 중요 포인트

### ✅ 변경된 것
- **폴더명**: `theme/` → `chapter/`
- **파일명**: `theme_*.json` → `chapter_*.json`
- **설정 키**: `themeMilestones` → `chapterMilestones`
- **트랙 이름**: `tracks.theme` → `tracks.chapter`

### 🔄 변경되지 않은 것
- **트리거 XP**: 여전히 20, 40, 60, 80, 100
- **트리거 방식**: XP 마일스톤 자동 트리거
- **분기 로직**: 시작 테마(기사/마법사)에 따른 선택
- **역할**: 메인 스토리 챕터

### 🎯 핵심 개념
**"Chapter = XP 20의 배수에서 트리거되는 메인 챕터"**

---

## ✅ 완료 체크리스트

- [x] theme 폴더 및 파일 삭제
- [x] chapter 폴더 및 파일 생성 (10개)
- [x] xp_config.json 업데이트
- [x] pubspec.yaml 업데이트
- [x] main/index.json 업데이트
- [x] README.md 업데이트
- [x] 빈 theme 폴더 삭제

---

## 🎉 결과

**Theme이 삭제되고, Chapter가 XP 20, 40, 60, 80, 100에서 트리거되는 메인 스토리 역할을 담당합니다!**

기사와 마법사는 각각 자신만의 5개 챕터를 경험하며, 100 XP에서 최종 챕터와 함께 엔딩을 맞이합니다.

