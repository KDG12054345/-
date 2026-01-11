# Phase 2: 전투 화면 시각화 구현 완료 보고서

## 📋 구현 개요

전투 시스템의 시각적 인터페이스를 구축하여 실시간 전투 상황을 플레이어에게 효과적으로 전달할 수 있도록 구현했습니다.

## ✅ 완료된 작업

### 1. 인벤토리 그리드 시각화

#### 📁 `lib/widgets/combat/combat_inventory_grid.dart`

**주요 기능:**
- 9×6 그리드에 아이템 실시간 표시
- 아이템 크기(width×height)에 맞는 셀 병합 렌더링
- 아이템 등급별 색상 구분 (일반/고급/희귀/영웅/전설)
- 아이템 타입별 아이콘 표시 (무기/방어구/물약/악세서리)
- 회전된 아이템 표시

**구현 세부사항:**
```dart
class CombatInventoryGrid extends StatelessWidget {
  - InventorySystem 통합
  - 동적 셀 크기 계산
  - 아이템 위치 기반 렌더링
  - 그리드 배경 및 테두리
}

class _ItemTile extends StatelessWidget {
  - 등급별 색상 (일반: 회색, 고급: 녹색, 희귀: 파랑, 영웅: 보라, 전설: 주황)
  - 아이템 아이콘/이미지 표시
  - 아이템 이름 오버레이
  - 회전 상태 표시기
  - 발광 효과 (BoxShadow)
}
```

---

### 2. 실시간 상태 바 위젯

#### 📁 `lib/widgets/combat/animated_stat_bar.dart`

**주요 기능:**

#### A. 애니메이션 스탯 바 (`AnimatedStatBar`)
- HP/스태미나 실시간 변화 애니메이션
- 부드러운 전환 효과 (300ms, easeOutCubic)
- 데미지 플래시 효과 (손실된 부분 빨간색 표시)
- 그라데이션 채우기
- 백분율 또는 숫자 표시 옵션

**애니메이션 특징:**
```dart
- 이전 값 → 현재 값 부드러운 전환
- 손실 영역 일시적 빨간색 표시 (데미지 시각화)
- 발광 효과로 시각적 강조
```

#### B. 쿨다운 표시기 (`CooldownIndicator`)
- 원형 진행 바 형태
- 남은 쿨다운 시간 숫자 표시
- 시계방향 감소 애니메이션
- CustomPainter 활용한 부드러운 렌더링

---

### 3. 상태 효과 표시 시스템

#### 📁 `lib/widgets/combat/status_effect_display.dart`

**주요 기능:**
- 버프/디버프 자동 분류 및 표시
- 스택 수 오버레이 표시
- 효과별 고유 아이콘 (14가지 효과 지원)
- 툴팁으로 상세 정보 제공
- 최대 표시 개수 제한 (기본 6개)

**지원하는 상태 효과:**
| 효과 ID | 아이콘 | 타입 | 설명 |
|---------|--------|------|------|
| burn | 🔥 local_fire_department | 디버프 | 화상: 지속 피해 |
| poison | ⚗️ science | 디버프 | 중독: 지속 피해 |
| frost/freeze | ❄️ ac_unit | 디버프 | 동상: 쿨다운 감소 속도 저하 |
| bleed/bleeding | 💧 water_drop | 디버프 | 출혈: 방어 무시 지속 피해 |
| blind | 👁️ visibility_off | 디버프 | 실명: 명중률 및 치명타 감소 |
| weak/weakness | 📉 trending_down | 디버프 | 약화: 공격력 감소 |
| defense | 🛡️ shield | 버프 | 방어: 피해 흡수 |
| regen/regeneration | ❤️ favorite | 버프 | 회복: 지속 체력 회복 |
| haste | ⚡ flash_on | 버프 | 가속: 쿨다운 감소 속도 증가 |
| luck | 🎲 casino | 버프 | 행운: 명중률 증가 |
| lifesteal | 🩸 bloodtype | 버프 | 생명력 흡수: 공격 시 체력 회복 |
| thorns | 🌿 grass | 버프 | 가시: 근접 공격 반사 |
| resistance | 🔰 security | 버프 | 저항: 디버프 차단 |
| mana | ✨ auto_awesome | 버프 | 마나: 마나 스킬 사용 가능 |

**레이아웃:**
```dart
버프들 (상단)
[🛡️3] [❤️5] [⚡2] [🎲1]

디버프들 (하단)
[🔥2] [❄️1] [💧3] +2개 더
```

---

### 4. 전투 피드백 애니메이션

#### 📁 `lib/widgets/combat/damage_popup.dart`

**A. 데미지 팝업 (`DamagePopup`)**
- 위로 떠오르며 사라지는 애니메이션
- 일반/크리티컬/힐링 구분
- 크리티컬 시 탄성 스케일 효과 (elasticOut)
- 색상 구분: 힐링(초록), 크리티컬(주황), 일반(흰색)

**애니메이션 구성:**
```dart
1. 페이드 인 (0 → 1, 240ms)
2. 유지 (600ms)
3. 페이드 아웃 (1 → 0, 360ms)
동시에 위로 슬라이드 (0 → -100px)
```

**B. 데미지 팝업 관리자 (`DamagePopupManager`)**
- 여러 팝업 동시 관리
- 랜덤 오프셋으로 겹침 방지
- 자동 제거 시스템

---

#### 📁 `lib/widgets/combat/combat_effects.dart`

**A. 타격 플래시 (`HitFlash`)**
- 피격 시 화면 번쩍임 효과
- 커스터마이징 가능한 색상
- 200ms 기본 지속시간
- easeOut 곡선으로 부드러운 사라짐

**B. 화면 쉐이크 (`ScreenShake`)**
- 강한 타격/크리티컬 시 화면 흔들림
- 진폭이 시간에 따라 감소
- 랜덤 방향 진동
- 기본 300ms 지속

**C. 아이템 사용 이펙트 (`ItemUseEffect`)**
- 아이템 사용 위치에 아이콘 표시
- 회전하며 커지는 애니메이션
- 페이드 인/아웃
- 800ms 지속

**D. 전투 시작 애니메이션 (`CombatStartAnimation`)**
- "FIGHT!" 텍스트 등장
- 스케일 + 페이드 조합
- 1500ms 지속
- 전투 시작 시 자동 재생

**E. 이펙트 관리자 (`CombatEffectsManager`)**
```dart
// 사용 예시
final manager = CombatEffectsManager.of(context);

// 화면 쉐이크
manager?.triggerShake(intensity: 15.0);

// 플래시 효과
manager?.triggerFlash(color: Colors.red);

// 아이템 사용 이펙트
manager?.showItemEffect(
  position: Offset(100, 200),
  color: Colors.blue,
  icon: Icons.healing,
);
```

---

### 5. 전투 화면 통합

#### 📁 `lib/screens/combat_screen.dart` (업데이트)

**주요 변경사항:**

1. **StatelessWidget → StatefulWidget 변환**
   - 전투 시작 애니메이션 상태 관리

2. **이펙트 매니저 래핑**
   ```dart
   CombatEffectsManager(
     child: DamagePopupManager(
       child: 기존 화면
     )
   )
   ```

3. **인벤토리 그리드 통합**
   - `CombatInventoryGrid` 위젯 사용
   - Character의 inventorySystem 연결
   - 플레이스홀더 그리드 (인벤토리 없을 때)

4. **애니메이션 스탯 바 적용**
   - 기존 정적 게이지 → AnimatedStatBar로 교체
   - HP/스태미나 실시간 애니메이션

5. **상태 효과 표시 추가**
   - 각 전투원의 버프/디버프 표시
   - 컴팩트한 아이콘 레이아웃

6. **테스트 버튼 개선**
   - 이펙트 테스트 버튼 추가
   - 데미지 팝업 + 쉐이크 + 플래시 동시 테스트

---

### 6. Character 클래스 확장

#### 📁 `lib/combat/character.dart` (업데이트)

**추가된 기능:**
```dart
class Character extends CombatEntity {
  // 인벤토리 시스템 추가
  late final InventorySystem inventorySystem;
  
  Character({
    required this.name,
    required super.stats,
    super.items,
    int inventoryWidth = 9,   // 기본 9칸 너비
    int inventoryHeight = 6,  // 기본 6칸 높이
  }) {
    inventorySystem = InventorySystem(
      width: inventoryWidth,
      height: inventoryHeight,
    );
  }
}
```

**이점:**
- 전투 화면에서 아이템 배치 시각화
- 인벤토리 관리와 전투 시스템 통합
- 아이템 드래그 앤 드롭 준비 완료

---

## 🎨 시각적 특징

### 색상 체계

| 요소 | 색상 | 용도 |
|------|------|------|
| 플레이어 | 파랑 (Blue) | 인벤토리, 초상화 테두리 |
| 적 | 빨강 (Red) | 인벤토리, 초상화 테두리 |
| HP | 빨강 (Red) | 체력 바 |
| 스태미나 | 노랑 (Yellow) | 스태미나 바 |
| 버프 | 초록 (Green) | 상태 효과 테두리 |
| 디버프 | 빨강 (Red) | 상태 효과 테두리 |
| 크리티컬 | 주황 (Orange) | 데미지 숫자 |
| 힐링 | 초록 (Green) | 회복 숫자 |
| 일반 아이템 | 회색 (Grey) | 등급 테두리 |
| 고급 아이템 | 초록 (Green) | 등급 테두리 |
| 희귀 아이템 | 파랑 (Blue) | 등급 테두리 |
| 영웅 아이템 | 보라 (Purple) | 등급 테두리 |
| 전설 아이템 | 주황 (Orange) | 등급 테두리 |

### 애니메이션 타이밍

| 애니메이션 | 지속시간 | Curve |
|------------|----------|-------|
| 스탯 바 변화 | 300ms | easeOutCubic |
| 데미지 팝업 | 1200ms | easeOut |
| 크리티컬 스케일 | 300ms | elasticOut |
| 타격 플래시 | 200ms | easeOut |
| 화면 쉐이크 | 300ms | linear |
| 아이템 이펙트 | 800ms | easeOut |
| 전투 시작 | 1500ms | easeOut |

---

## 🔧 기술적 세부사항

### 사용된 Flutter 기능

1. **애니메이션**
   - `AnimationController`
   - `Tween` / `TweenSequence`
   - `CurvedAnimation`
   - `AnimatedBuilder`

2. **커스텀 페인팅**
   - `CustomPainter` (쿨다운 원형 진행 바)
   - `Canvas` API

3. **레이아웃**
   - `Stack` / `Positioned`
   - `GridView.builder`
   - `LayoutBuilder`
   - `FractionallySizedBox`

4. **상태 관리**
   - `StatefulWidget`
   - `SingleTickerProviderStateMixin`
   - Context 기반 매니저 접근 (`of(context)`)

5. **시각 효과**
   - `BoxShadow` (발광 효과)
   - `LinearGradient`
   - `Transform.translate` / `Transform.scale` / `Transform.rotate`
   - `Opacity`

---

## 📊 성능 최적화

### 적용된 최적화 기법

1. **효율적인 렌더링**
   - `const` 생성자 활용
   - `AnimatedBuilder`로 리빌드 최소화
   - `RepaintBoundary` 후보 지점 파악

2. **메모리 관리**
   - 애니메이션 컨트롤러 dispose
   - 스트림 컨트롤러 정리
   - 완료된 팝업/이펙트 자동 제거

3. **레이아웃 효율**
   - `physics: NeverScrollableScrollPhysics` (불필요한 스크롤 비활성화)
   - 고정 크기 컨테이너
   - aspectRatio 계산 최적화

---

## 🧪 테스트 기능

### 추가된 테스트 버튼

1. **이펙트 테스트** (주황색)
   - 크리티컬 데미지 팝업 (100)
   - 화면 쉐이크
   - 빨간색 플래시

2. **승리** (초록색)
   - 전투 종료 (승리)

3. **패배** (빨간색)
   - 전투 종료 (패배)

---

## 📁 생성된 파일 목록

```
lib/widgets/combat/
├── combat_inventory_grid.dart    (162 lines)
├── animated_stat_bar.dart         (210 lines)
├── status_effect_display.dart     (238 lines)
├── damage_popup.dart              (230 lines)
└── combat_effects.dart            (440 lines)

lib/combat/
└── character.dart                 (수정: inventorySystem 추가)

lib/screens/
└── combat_screen.dart             (수정: 모든 위젯 통합)
```

**총 라인 수:** ~1,280 lines (신규)

---

## 🚀 다음 단계 제안

### Phase 3: 실시간 전투 로직 연동

1. **이벤트 리스너 구현**
   ```dart
   - DamageTaken → 데미지 팝업 + 플래시
   - WeaponUsed → 아이템 이펙트
   - StatusEffectApplied → 상태 효과 표시 업데이트
   - StaminaChanged → 스탯 바 애니메이션
   ```

2. **전투 엔진 통합**
   - CombatEngine 업데이트 시 UI 자동 갱신
   - 실시간 쿨다운 표시
   - 무기 사용 시각 피드백

3. **고급 이펙트**
   - 파티클 시스템 (화염, 얼음 등)
   - 무기별 고유 이펙트
   - 연속 공격 콤보 표시
   - 크리티컬 카메라 줌

4. **사운드 통합**
   - 타격음
   - 크리티컬 효과음
   - 버프/디버프 사운드
   - 배경음악 관리

---

## ✅ 완료 체크리스트

- [x] 인벤토리 그리드에 아이템 표시
- [x] 배치된 아이템을 그리드에 렌더링
- [x] 아이템 크기(width×height)에 맞게 셀 병합 표시
- [x] 아이템 아이콘 또는 색상 구분
- [x] HP/스태미나 바 애니메이션
- [x] 쿨다운 진행 시각화
- [x] 상태 효과 아이콘 표시
- [x] 데미지 숫자 팝업
- [x] 타격 효과 (플래시/쉐이크)
- [x] 아이템 사용 시 간단한 이펙트
- [x] Character 클래스에 InventorySystem 통합
- [x] 전투 화면에 모든 위젯 통합
- [x] 테스트 기능 추가
- [x] Linter 에러 제거

---

## 📝 사용 예시

### 데미지 팝업 표시하기
```dart
final popupManager = DamagePopupManager.of(context);
popupManager?.showDamage(
  damage: 50,
  position: Offset(200, 300),
  isCritical: false,
);
```

### 화면 쉐이크 트리거
```dart
final effectsManager = CombatEffectsManager.of(context);
effectsManager?.triggerShake(intensity: 15.0);
```

### 플래시 효과
```dart
final effectsManager = CombatEffectsManager.of(context);
effectsManager?.triggerFlash(color: Colors.red);
```

### 아이템 사용 이펙트
```dart
final effectsManager = CombatEffectsManager.of(context);
effectsManager?.showItemEffect(
  position: Offset(100, 200),
  color: Colors.blue,
  icon: Icons.healing,
);
```

---

## 🎓 배운 점 & 개선 사항

### 성공 요인
- 체계적인 위젯 분리로 재사용성 확보
- 애니메이션 타이밍 세밀한 조정
- Context 기반 매니저 패턴으로 전역 상태 관리
- 일관된 색상 체계로 직관적인 UI

### 개선 가능 영역
1. 아이템 아이콘을 실제 이미지로 교체
2. 파티클 시스템 추가
3. 더 다양한 이펙트 타입
4. 사운드 통합
5. 성능 프로파일링 및 최적화
6. 애니메이션 속도 사용자 설정

---

## 📞 문의 & 피드백

전투 화면 시각화가 완료되었습니다! 🎉

- 모든 요구사항 구현 완료
- Linter 에러 없음
- 테스트 기능 포함
- 확장 가능한 구조

**다음 단계가 필요하시면 알려주세요!**

