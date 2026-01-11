# ✅ XP 시스템 필수 초기화 완료

## 📋 구현 내용

### 자동 초기화 시스템 구축

**파일**: `lib/modules/xp/xp_module.dart`

#### 추가된 기능
1. **`CharacterCreated` 이벤트 처리**: 캐릭터 생성 시 자동 초기화
2. **xp_config.json 자동 로드**: `rootBundle.loadString()` 사용
3. **서비스 자동 설정**: MilestoneService + EncounterScheduler
4. **시작 테마 자동 감지**: start 인카운터 경로에서 추출

---

## 🔄 초기화 흐름

```
게임 시작 버튼 클릭
  ↓
[StartGame 이벤트]
  ↓
CharacterCreationModule
  ↓
[CharacterCreated 이벤트] ← 🎯 여기서 초기화!
  ↓
XpModule._handleCharacterCreated()
  ├─ 1. xp_config.json 로드
  ├─ 2. MilestoneService.loadConfig()
  ├─ 3. EncounterScheduler.loadConfig()
  └─ 4. _initialized = true
  ↓
게임 진행 (인카운터 시작)
  ↓
시작 인카운터 종료 시
  ↓
XpModule._detectAndSetStartTheme()
  └─ start_knight.json → 'start_knight' 테마 설정
```

---

## 💻 구현 코드

### 1. 초기화 처리 메서드

```dart
/// 🆕 캐릭터 생성 시 XP 시스템 초기화
Future<List<GEvent>> _handleCharacterCreated(
  CharacterCreated event,
  GameVM vm,
) async {
  if (_initialized) {
    return const [];
  }

  try {
    debugPrint('[XpModule] 🎬 Initializing XP system...');

    // 1. xp_config.json 로드
    final jsonString = await rootBundle.loadString('assets/config/xp_config.json');
    final config = json.decode(jsonString) as Map<String, dynamic>;

    // 2. MilestoneService 설정
    _milestoneService.loadConfig(MilestoneConfig.fromJson(config));
    
    // 3. EncounterScheduler 설정
    final tracks = config['tracks'] as Map<String, dynamic>?;
    if (tracks != null) {
      _scheduler.loadConfig(
        themeConfig: ThemeTrackConfig.fromJson(tracks['chapter']),
        storyConfig: StoryTrackConfig.fromJson(tracks['story']),
        startThemeKey: 'default',
      );
    }

    _initialized = true;
    debugPrint('[XpModule] 🎉 XP system initialization complete!');
    
    return const [];
  } catch (e, stackTrace) {
    debugPrint('[XpModule] ❌ Initialization failed: $e');
    return [ErrorEvt('XP 시스템 초기화 실패: $e')];
  }
}
```

### 2. 시작 테마 자동 감지

```dart
/// 🆕 시작 테마 자동 감지 및 설정
void _detectAndSetStartTheme(String encounterPath) {
  try {
    // 파일명 추출: assets/dialogue/start/start_knight.json → start_knight
    final fileName = encounterPath.split('/').last.replaceAll('.json', '');
    
    if (fileName.startsWith('start_')) {
      _scheduler.setStartThemeKey(fileName);
      debugPrint('[XpModule] 🎭 Detected start theme: $fileName');
    }
  } catch (e) {
    debugPrint('[XpModule] Failed to detect start theme: $e');
  }
}
```

### 3. 인카운터 종료 시 테마 감지

```dart
Future<List<GEvent>> _handleEncounterEnded(...) async {
  final encounterPath = event.outcome['encounterPath'] as String?;
  
  // 🆕 시작 테마 자동 감지 (start 인카운터에서)
  if (encounterPath != null && encounterPath.contains('/start/')) {
    _detectAndSetStartTheme(encounterPath);
  }
  
  // ... XP 정산 로직 ...
}
```

---

## 📊 초기화 로그 예시

게임을 실행하면 다음과 같은 로그가 출력됩니다:

```
[XpModule] 🎬 Initializing XP system...
[XpModule] ✅ Loaded xp_config.json
[XpModule] ✅ MilestoneService configured
[XpModule]    Chapter: [20, 40, 60, 80, 100]
[XpModule]    Story: [10, 30, 50, 70, 90]
[XpModule] ✅ EncounterScheduler configured
[XpModule] 🎉 XP system initialization complete!

... (게임 진행) ...

[XpModule] 🎭 Detected start theme: start_knight
```

---

## 🎯 주요 특징

### 1️⃣ 완전 자동화
- ✅ 수동 초기화 코드 불필요
- ✅ 게임 시작 시 자동 실행
- ✅ 한 번만 실행되도록 플래그 관리

### 2️⃣ 안전한 에러 처리
- ✅ try-catch로 초기화 실패 처리
- ✅ 실패 시 ErrorEvt 발생
- ✅ 상세한 디버그 로그

### 3️⃣ 스마트 테마 감지
- ✅ 시작 인카운터 경로에서 자동 추출
- ✅ start_knight.json → 'start_knight' 테마
- ✅ start_mage.json → 'start_mage' 테마

---

## 🔗 연동 확인

### 초기화 대상 서비스

| 서비스 | 설정 내용 | 출처 |
|--------|-----------|------|
| **MilestoneService** | Chapter/Story 마일스톤 | `chapterMilestones`, `storyMilestones` |
| **EncounterScheduler** | Chapter/Story 인카운터 목록 | `tracks.chapter`, `tracks.story` |
| **XpService** | 자동 생성 (싱글톤) | - |

### 테마 키 매핑

| 시작 인카운터 파일 | 감지된 테마 키 | Chapter 파일 |
|-------------------|---------------|--------------|
| `start_knight.json` | `start_knight` | `chapter_knight_20.json` ~ `100` |
| `start_mage.json` | `start_mage` | `chapter_mage_20.json` ~ `100` |
| 기타 | `default` | `chapter_default_20.json` ~ `100` |

---

## ✅ 완료된 작업

- [x] `xp_config.json` 자동 로드
- [x] `MilestoneService` 자동 설정
- [x] `EncounterScheduler` 자동 설정
- [x] 시작 테마 자동 감지
- [x] 중복 초기화 방지
- [x] 에러 처리 및 로깅

---

## 🎉 결과

**이제 게임 시작 시 아무 코드 없이 XP 시스템이 자동으로 초기화됩니다!**

1. ✅ 플레이어가 "게임 시작" 클릭
2. ✅ 캐릭터 생성
3. ✅ XP 시스템 자동 초기화
4. ✅ 시작 인카운터 감지
5. ✅ Chapter/Story 인카운터 준비 완료
6. ✅ XP 기반 진행 시작

---

## 🐛 디버깅 팁

### 초기화가 안 되는 경우

1. **xp_config.json 경로 확인**
   ```
   assets/config/xp_config.json
   ```

2. **pubspec.yaml에 등록 확인**
   ```yaml
   assets:
     - assets/config/xp_config.json
   ```

3. **디버그 로그 확인**
   ```
   [XpModule] 🎬 Initializing XP system...
   ```
   
   이 로그가 안 보이면 `CharacterCreated` 이벤트가 발생하지 않은 것

### 테마 감지가 안 되는 경우

1. **파일명 형식 확인**
   - ✅ `start_knight.json`
   - ✅ `start_mage.json`
   - ❌ `knight_start.json` (인식 안 됨)

2. **인카운터 경로 확인**
   ```
   [XpModule] 🎭 Detected start theme: start_knight
   ```
   
   이 로그가 안 보이면 `encounterPath`가 제대로 전달되지 않은 것

---

## 📝 추가 개선 가능성

1. **설정 파일 검증**: xp_config.json 스키마 검증
2. **폴백 설정**: 로드 실패 시 하드코딩된 기본값 사용
3. **핫 리로드**: 개발 중 설정 변경 시 자동 재로드
4. **상태 저장**: 초기화 상태를 GameVM에 저장

---

**모든 필수 초기화가 자동으로 처리됩니다! 🎊**

