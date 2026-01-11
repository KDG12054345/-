# 아이템 스키마 구조 문서

이 문서는 게임 내 아이템을 생성할 때 필요한 모든 스키마 구조를 정의합니다.
다른 AI나 개발자와의 협업을 위한 참고 자료입니다.

## 목차
1. [기본 구조](#기본-구조)
2. [속성(Properties) 구조](#속성properties-구조)
3. [전투 효과(Effects) 스키마](#전투-효과effects-스키마)
4. [아이템 타입별 예시](#아이템-타입별-예시)
5. [확장 가이드](#확장-가이드)

---

## 기본 구조

### RewardItemDefinition

```dart
RewardItemDefinition({
  required String id,              // 아이템 고유 ID (예: 'steel_sword')
  required String name,             // 아이템 이름 (예: '강철 검')
  required String description,      // 아이템 설명
  required int baseWidth,           // (사용 안 함, 호환성 유지용 - 그리드 방식 아님)
  required int baseHeight,          // (사용 안 함, 호환성 유지용 - 그리드 방식 아님)
  Map<String, dynamic> properties,  // 확장 가능한 속성들 (아래 상세 설명)
})
```

### 필수 필드
- `id`: 고유 식별자 (문자열, 소문자+언더스코어 권장)
- `name`: 표시 이름
- `description`: 아이템 설명
- `baseWidth`, `baseHeight`: (사용 안 함, 호환성 유지용 - 그리드 방식이 아니므로 의미 없음)

---

## 속성(Properties) 구조

`properties`는 `Map<String, dynamic>` 타입으로, 다음 키들을 사용할 수 있습니다:

### 1. 기본 속성

```dart
properties: {
  'rarity': String,        // 'COMMON', 'RARE', 'EPIC', 'LEGENDARY' (대소문자 무관)
  'type': String,          // 'weapon', 'armor', 'accessory', 'bag' (대소문자 무관, 정규화됨)
  'iconPath': String?,     // 아이콘 경로 (선택)
  'footprint': List<List<int>>?,  // 커스텀 모양 (선택, footprint가 없으면 기본 사각형 사용)
  'buyPrice': int?,        // 구입 가격 (선택, 기본값: 0)
  'weightUnits': int?,     // 무게 units (선택, 권장) - 1 unit = 0.5 weight
}
```

**참고:**
- `buyPrice`: 아이템 구입 가격 (정수). `InventoryItem.buyPrice` getter로 접근 가능
- 판매 가격: `InventoryItem.sellPrice` getter로 자동 계산 (구입 가격의 절반)
- `weightUnits`: 아이템 무게 (정수, 0.5 단위). `InventoryItem.weightUnits` getter로 접근 가능
- `type`: 아이템 타입. `InventoryItem.itemType` (enum) 또는 `InventoryItem.itemTypeString` (문자열)로 접근

### 타입(type) 정규화 규칙

`type` 필드는 대소문자를 구분하지 않으며, 내부에서 자동으로 정규화됩니다.

#### 허용 타입 (SSOT)

| 타입 | 정규화 값 | 설명 |
|------|-----------|------|
| `weapon` | `ItemType.weapon` | 무기 |
| `armor` | `ItemType.armor` | 방어구 |
| `accessory` | `ItemType.accessory` | 장신구 |
| `bag` | `ItemType.bag` | 가방 |
| `misc` | `ItemType.misc` | 기타/알 수 없음 (fallback) |

#### 타입 별칭 (Alias)

레거시 호환 및 문서 불일치 대응을 위해 다음 별칭이 지원됩니다:

| 입력값 | 변환 결과 | 비고 |
|--------|-----------|------|
| `'potion'` | `ItemType.misc` | 아직 미구현 |
| `'food'` | `ItemType.misc` | 아직 미구현 |
| `'consumable'` | `ItemType.misc` | 더 이상 사용하지 않음 |
| `'acc'` | `ItemType.accessory` | 축약형 |
| `'pet'` | `ItemType.misc` | 아직 미구현 |

#### 정규화 예시

| 입력값 | 정규화 결과 | 비고 |
|--------|-------------|------|
| `'weapon'`, `'WEAPON'`, `'Weapon'` | `ItemType.weapon` | 대소문자 무관 |
| `'  armor  '` | `ItemType.armor` | 앞뒤 공백 자동 trim |
| `'potion'` | `ItemType.misc` | alias 적용 (미구현) |
| `'consumable'` | `ItemType.misc` | alias 적용 (더 이상 사용하지 않음) |
| `null` (누락) | `ItemType.misc` | 기본값 |
| `'invalid'` | `ItemType.misc` | dev 빌드에서 경고 로그 |

**코드에서의 사용:**
```dart
// ✅ 권장: enum 기반 비교
if (item.itemType == ItemType.weapon) {
  equipWeapon(item);
}

// ✅ 편의 getter 사용
if (item.isBag) {
  addToBagSlot(item);
}

// ✅ 문자열 비교가 필요할 때
if (item.itemTypeString == 'weapon') {
  // ...
}

// ❌ 지양: properties에서 직접 읽지 말 것 (정규화 안 됨)
if (item.properties['type'] == 'weapon') { ... }
```

**로그:**
- dev/profile 빌드에서 잘못된 type 입력 시 `[ItemType] WARN:` 경고 로그 출력
- alias 적용 시 `[ItemType] INFO:` 알림 로그 출력 (JSON 업데이트 권장)
- release 빌드에서는 조용히 `misc`로 fallback

### 희귀도(rarity) 정규화 규칙

`rarity` 필드는 대소문자를 구분하지 않으며, 내부에서 자동으로 정규화됩니다.

| 입력값 | 정규화 결과 | 비고 |
|--------|-------------|------|
| `'COMMON'`, `'common'`, `'Common'` | `ItemRarity.common` | 대소문자 무관 |
| `'RARE'`, `'rare'`, `'Rare'` | `ItemRarity.rare` | 대소문자 무관 |
| `'EPIC'`, `'epic'`, `'Epic'` | `ItemRarity.epic` | 대소문자 무관 |
| `'LEGENDARY'`, `'legendary'` | `ItemRarity.legendary` | 대소문자 무관 |
| `null` (누락) | `ItemRarity.common` | 기본값 |
| 잘못된 값 | `ItemRarity.common` | dev 빌드에서 경고 로그 |
| `'  rare  '` (공백 포함) | `ItemRarity.rare` | 앞뒤 공백 자동 trim |

**코드에서의 사용:**
```dart
// ✅ 권장: enum 기반 비교
if (item.rarity == ItemRarity.legendary) {
  showSpecialEffect();
}

// ✅ 문자열 비교가 필요할 때
if (item.rarityString == 'LEGENDARY') {
  // ...
}

// ❌ 지양: properties에서 직접 읽지 말 것 (정규화 안 됨)
if (item.properties['rarity'] == 'legendary') { ... }
```

**로그:**
- dev/profile 빌드에서 잘못된 rarity 입력 시 `[ItemRarity] WARN:` 경고 로그 출력
- release 빌드에서는 조용히 `COMMON`으로 fallback

### 무게(weightUnits) 해석 우선순위

무게는 다음 우선순위로 해석됩니다:

| 우선순위 | 소스 | 설명 |
|---------|------|------|
| 1순위 | `properties['weightUnits']` | JSON에 정의된 값 **(권장)** |
| 2순위 | `properties['weight']` | 호환용 (사용 시 경고 출력) |
| 3순위 | `kInventoryItemWeightUnitsById[itemId]` | 레거시 Dart 맵 (`lib/data/inventory_item_weight_units.dart`) |
| 4순위 | 0 | 기본값 (dev/profile 빌드에서 경고) |

**마이그레이션 정책:**
- **신규 아이템**: JSON `properties`에 `weightUnits` 필드를 반드시 추가하세요.
- **기존 아이템**: 레거시 맵에 정의되어 있으면 동작하지만, 점진적으로 JSON으로 이전을 권장합니다.
- **경고 확인**: dev 빌드에서 `[WeightResolver] WARN:` 로그가 뜨면 해당 아이템에 `weightUnits` 추가가 필요합니다.

**예시:**
```json
{
  "id": "dagger",
  "name": "단검",
  "properties": {
    "buyPrice": 3,
    "weightUnits": 4,
    "type": "weapon"
  }
}
```

위 예시에서 `weightUnits: 4`는 무게 2.0을 의미합니다 (4 units × 0.5 = 2.0).

### 2. 전투 속성 (`combat`)

```dart
properties: {
  'combat': {
    'maxHealth': int,             // 최대 체력 보너스
    'accuracy': int,              // 명중률 보너스
    'defenseRate': double,        // 방어율 (0.0 ~ 1.0, 예: 0.05 = 5%)
    'flatDamageReduction': int,   // 피격 시 고정 데미지 감소 (무기/펫 공격에만 적용)
  },
}
```

**주의사항**:
- `attackPower`: 아이템의 `combat` 속성에서 사용되지 않습니다. 세트 효과(시너지)에서만 적용됩니다.
- `flatDamageReduction`: 무기/펫 공격 피격 시에만 적용됩니다. DoT(화상, 중독, 출혈 등)에는 적용되지 않습니다. 여러 아이템 장착 시 중첩됩니다.

### 3. 무기 속성 (`weapon`)

무기 타입 아이템에 필수:

```dart
properties: {
  'weapon': {
    'type': String,                    // 'melee' 또는 'ranged'
    'baseDamage': double,              // 기본 데미지 (단일값, 레거시 호환)
    'damageRange': {                   // 데미지 범위 (optional, v2.0)
      'min': int,                      // 최소 데미지
      'max': int,                      // 최대 데미지
    },
    'staminaCost': double,             // 스태미나 소모량
    'cooldown': double,                // 쿨다운 시간 (초)
    'accuracy': double,                // 명중률 (0.0 ~ 1.0)
    'criticalChance': double,          // 치명타 확률 (0.0 ~ 1.0)
    'criticalMultiplier': double,      // 치명타 배율 (1.0 이상)
  },
}
```

#### 데미지 계산 우선순위

| 우선순위 | 조건 | 동작 |
|---------|------|------|
| 1 | `damageRange` 존재 | min~max 범위에서 랜덤 롤 |
| 2 | `damageRange` 없음 | `baseDamage` 단일값 사용 |

#### 데미지 범위 규칙

- **정수만 허용**: 소수점 입력 시 반올림 + 개발 환경 경고
- **min > max**: 개발 환경 경고 후 swap하여 처리
- **음수**: 0으로 clamp
- **min == max**: 단일값으로 처리 (RNG 호출 생략)
- **UI 표기**: min==max면 "5", min!=max면 "4–5"

#### 데미지 계산 순서

```
(1) 명중 판정 → 실패 시 0 데미지
(2) 기본 데미지 롤 (damageRange 또는 baseDamage)
(3) + 공격력 (user.combatStats.attackPower)
(4) 크리티컬 판정 → 성공 시 배수 적용
(5) 방어/저항/버프/디버프 등 기존 파이프라인
```

#### 예시

```json
// 레거시 (단일값)
"weapon": {
  "type": "melee",
  "baseDamage": 5
}

// 범위 데미지 (4~5)
"weapon": {
  "type": "melee",
  "baseDamage": 4,              // fallback용
  "damageRange": { "min": 4, "max": 5 }
}
```

### 4. 전투 효과 (`effects`)

**중요**: 이 속성이 전투에서 실제로 발동됩니다.

```dart
properties: {
  'effects': [
    {
      'type': String,          // 효과 타입 (예: 'bleeding', 'burn', 'poison')
      'stack': int,            // 스택 수 (기본값: 1)
      'target': String,        // 'enemy' 또는 'self' (기본값: 'enemy')
      'trigger': String,       // 'on_hit' (현재 지원)
      'chance': double,        // 발동 확률 (on_hit에서는 무시됨, 다른 트리거용)
    },
    // 여러 효과를 배열로 추가 가능
  ],
}
```

### 5. 소비품 속성

```dart
// 소비품(consumable) 타입은 더 이상 사용하지 않습니다.
// 이 게임에는 소모 아이템이 없습니다.
```

---

## 전투 효과(Effects) 스키마

### 지원되는 효과 타입

현재 구현된 효과:

#### 디버프 (Debuff) - 적에게 부여

| 타입 | 이름 | 설명 | 스택 효과 | 틱 주기 |
|------|------|------|-----------|---------|
| `bleeding` / `bleed` | 출혈 | 방어 무시 지속 피해 | 스택당 피해 증가 | 3초마다 |
| `burn` | 화상 | 지속 피해 (방어 적용) | 스택당 피해 증가 (스택당 5 피해) | 1초마다 |
| `poison` | 중독 | 지속 피해 | 스택당 피해 증가 | 2초마다 |
| `frost` / `freeze` | 동상 | 쿨다운 감소 속도 저하 | Brawl-style: 1/(1+0.01×stacks) | - |
| `blind` | 실명 | 명중률, 치명타 확률/배율 감소 | 스택당 명중률 -3%, 치명타 -1% | - |
| `weak` / `weakness` | 약화 | 공격력 감소 | 스택당 공격력 -1 | - |

#### 버프 (Buff) - 자신에게 부여

| 타입 | 이름 | 설명 | 스택 효과 | 틱 주기 |
|------|------|------|-----------|---------|
| `haste` | 가속 | 쿨다운 감소 속도 증가 | 스택당 1%씩 증가 | - |
| `regeneration` / `regen` | 회복 | 지속 체력 회복 | 스택당 회복량 증가 | 2초마다 |
| `lifesteal` | 생명력 흡수 | 공격 시 체력 회복 | 스택당 회복량 증가 | - |
| `luck` | 행운 | 명중률 증가 | 스택당 명중률 증가 | - |
| `thorns` | 가시 | 근접 공격 반사 | 스택당 반사 피해 증가 | - |
| `defense` | 방어 | 피해 흡수 | 스택당 흡수량 증가 | - |
| `resistance` | 저항 | 디버프 차단 | 스택당 차단 가능 | - |
| `mana` | 마나 | 마나 스킬 사용 가능 | - | - |

**참고**: 위의 모든 효과 타입은 `EffectProcessor`에서 지원됩니다. 아이템의 `properties['effects']`에 위 타입 중 하나를 지정하면 전투에서 자동으로 적용됩니다.

### 효과별 상세 설명

#### 출혈 (Bleeding)
- **타입**: `'bleeding'` 또는 `'bleed'`
- **효과**: 방어 무시 지속 피해
- **틱**: 3초마다 스택당 1 피해
- **특수 효과**: 출혈 상태의 대상이 치명타를 받을 때 치명타 데미지 배율 증가 (스택당 1%)

#### 화상 (Burn)
- **타입**: `'burn'`
- **효과**: 지속 피해 (방어 적용)
- **틱**: 1초마다 스택당 5 피해

#### 중독 (Poison)
- **타입**: `'poison'`
- **효과**: 지속 피해
- **틱**: 2초마다 스택당 1 피해

#### 동상 (Frost)
- **타입**: `'frost'` 또는 `'freeze'`
- **효과**: 쿨다운 감소 속도 저하
- **계산**: Brawl-style 공식 `1 / (1 + 0.01 × stacks)`
  - 스택당 1%씩 둔화 (절대 0이 되지 않음)
  - 100 스택 = 50% 속도, 200 스택 = 33% 속도

#### 실명 (Blind)
- **타입**: `'blind'`
- **효과**: 명중률, 치명타 확률/배율 감소
- **계산**: 스택당 명중률 -3% (최대 -90%), 치명타 확률/배율 -1%

#### 약화 (Weakness)
- **타입**: `'weak'` 또는 `'weakness'`
- **효과**: 공격력 감소
- **계산**: 스택당 공격력 -1

#### 가속 (Haste)
- **타입**: `'haste'`
- **효과**: 쿨다운 감소 속도 증가
- **계산**: 스택당 1%씩 증가

#### 회복 (Regeneration)
- **타입**: `'regeneration'` 또는 `'regen'`
- **효과**: 지속 체력 회복
- **틱**: 2초마다 스택당 회복

#### 생명력 흡수 (Lifesteal)
- **타입**: `'lifesteal'`
- **효과**: 공격 시 체력 회복
- **발동**: 공격 적중 시

#### 행운 (Luck)
- **타입**: `'luck'`
- **효과**: 명중률 증가

#### 가시 (Thorns)
- **타입**: `'thorns'`
- **효과**: 근접 공격 반사
- **발동**: 근접 공격 받을 시

#### 방어 (Defense)
- **타입**: `'defense'`
- **효과**: 피해 흡수

#### 저항 (Resistance)
- **타입**: `'resistance'`
- **효과**: 디버프 차단

#### 마나 (Mana)
- **타입**: `'mana'`
- **효과**: 마나 스킬 사용 가능

### 효과 필드 상세

```dart
{
  'type': String,        // 필수: 효과 타입
  'stack': int,          // 선택: 스택 수 (기본값: 1)
  'target': String,      // 선택: 'enemy' 또는 'self' (기본값: 'enemy')
  'trigger': String,     // 필수: 'on_hit', 'on_combat_start', 'passive'
  'chance': double,      // 선택: 발동 확률 0.0~1.0 (on_hit에서만 사용, 기본값: 1.0)
  'interval': double,    // 선택: 발동 주기 초 단위 (passive에서만 사용)
}
```

### 트리거(Trigger) 타입

| 트리거 | 설명 | 사용 시점 | 추가 필드 |
|--------|------|-----------|-----------|
| `on_hit` | 적중 시 발동 | 무기 공격이 명중했을 때 | `chance`: 발동 확률 (선택) |
| `on_combat_start` | 전투 시작 시 발동 | 전투 시작 직후 한 번 | - |
| `passive` | 지속 효과 | 전투 중 주기적으로 | `interval`: 발동 주기 (초, 필수) |

**주의**: 
- `trigger: 'on_hit'`는 무기 공격이 **명중**했을 때만 발동됩니다 (미스/회피 시 발동 안 됨)
- `trigger: 'on_combat_start'`는 전투 시작 시 한 번만 발동됩니다 (target: 'self' 권장)
- `trigger: 'passive'`는 전투 중 지속적으로 발동됩니다 (interval 필드로 주기 지정)

### 확률(Chance) 동작 방식

**기본 동작 (chance 필드가 없거나 1.0인 경우):**
- `chance` 필드가 없거나 `chance: 1.0`이면 → **항상 효과가 적용됩니다**
- 아이템이 적중했다면, 효과 스택은 100% 확률로 적용됩니다

**확률 발동 (chance 필드가 0.0~0.99 사이인 경우):**
- `chance: 0.3` (30%): 적중 시 30% 확률로 효과 발동
- `chance: 0.6` (60%): 적중 시 60% 확률로 효과 발동
- `chance: 0.0` (0%): 절대 발동 안 됨

**사용 예시:**
```dart
// 항상 적용 (기본)
'effects': [
  {
    'type': 'poison',
    'stack': 3,
    'trigger': 'on_hit',
    // chance 필드 없음 → 항상 적용
  },
]

// 확률 발동 (특수한 경우)
'effects': [
  {
    'type': 'poison',
    'stack': 3,
    'trigger': 'on_hit',
    'chance': 0.6,  // 60% 확률로 발동
  },
]
```

---

## 아이템 타입별 예시

### 1. 무기 (Weapon) - 출혈 효과 포함

```dart
RewardItemDefinition(
  id: 'steel_sword',
  name: '강철 검',
  description: '날카로운 강철 검 (전투용 무기)',
  baseWidth: 1,
  baseHeight: 1,
  properties: {
    // 기본 속성
    'rarity': 'RARE',
    'type': 'weapon',
    'buyPrice': 150,  // 구입 가격 150 (판매 가격은 자동으로 75)
    
    // 전투 속성
    // 주의: attackPower는 세트 효과(시너지)에서만 적용됩니다.
    // 'combat': {
    //   'maxHealth': 20,  // 필요시 추가 가능
    // },
    
    // 무기 속성
    'weapon': {
      'type': 'melee',
      'baseDamage': 15,
      'staminaCost': 3.0,
      'cooldown': 1.0,
      'accuracy': 0.8,
      'criticalChance': 0.1,
      'criticalMultiplier': 1.5,
    },
    
    // 전투 효과
    'effects': [
      {
        'type': 'bleeding',
        'stack': 1,
        'target': 'enemy',
        'trigger': 'on_hit',
        // chance 필드 없음 → 적중 시 항상 적용 (100%)
      },
    ],
  },
)
```

### 2. 방어구 (Armor)

```dart
RewardItemDefinition(
  id: 'wooden_shield',
  name: '나무 방패',
  description: '튼튼한 나무 방패 (방어 보너스)',
  baseWidth: 1,
  baseHeight: 1,
  properties: {
    'rarity': 'COMMON',
    'type': 'armor',
    'combat': {
      'maxHealth': 20,
      'defenseRate': 0.05,  // 5% 방어
    },
  },
)
```

### 3. 기타 아이템 (Misc)

```dart
RewardItemDefinition(
  id: 'misc_item',
  name: '기타 아이템',
  description: '특별한 분류가 없는 아이템',
  baseWidth: 1,
  baseHeight: 1,
  properties: {
    'rarity': 'COMMON',
    'type': 'misc',
  },
)
```

**참고:** 이 게임에는 소모 아이템(consumable)이 없습니다. 기존에 `consumable` 타입으로 정의된 아이템은 `misc`로 변경되었습니다.

### 4. 고급 무기 - 여러 효과

```dart
RewardItemDefinition(
  id: 'cursed_blade',
  name: '저주받은 검',
  description: '강력하지만 위험한 검',
  baseWidth: 1,
  baseHeight: 1,
  properties: {
    'rarity': 'LEGENDARY',
    'type': 'weapon',
    // attackPower는 세트 효과에서만 적용
    'weapon': {
      'type': 'melee',
      'baseDamage': 30,
      'staminaCost': 4.0,
      'cooldown': 1.2,
      'accuracy': 0.75,
      'criticalChance': 0.2,
      'criticalMultiplier': 2.0,
    },
    'effects': [
      {
        'type': 'bleeding',
        'stack': 2,  // 2스택 출혈
        'target': 'enemy',
        'trigger': 'on_hit',
        // chance 필드 없음 → 적중 시 항상 적용 (100%)
      },
      {
        'type': 'burn',
        'stack': 1,
        'target': 'enemy',
        'trigger': 'on_hit',
        // chance 필드 없음 → 적중 시 항상 적용 (100%)
      },
      {
        'type': 'frost',
        'stack': 1,
        'target': 'enemy',
        'trigger': 'on_hit',
        // chance 필드 없음 → 적중 시 항상 적용 (100%)
      },
    ],
  },
)
```

### 5. 화상 효과 무기

```dart
RewardItemDefinition(
  id: 'flame_sword',
  name: '화염 검',
  description: '불꽃을 내뿜는 검',
  baseWidth: 1,
  baseHeight: 1,
  properties: {
    'rarity': 'EPIC',
    'type': 'weapon',
    // attackPower는 세트 효과에서만 적용
    'weapon': {
      'type': 'melee',
      'baseDamage': 20,
      'staminaCost': 3.0,
      'cooldown': 1.0,
      'accuracy': 0.8,
      'criticalChance': 0.15,
      'criticalMultiplier': 1.8,
    },
    'effects': [
      {
        'type': 'burn',
        'stack': 2,  // 2스택 화상
        'target': 'enemy',
        'trigger': 'on_hit',
        // chance 필드 없음 → 적중 시 항상 적용 (100%)
      },
    ],
  },
)
```

### 6. 가속 효과 무기 (버프)

```dart
RewardItemDefinition(
  id: 'wind_blade',
  name: '바람의 검',
  description: '공격 속도가 빨라지는 검',
  baseWidth: 1,
  baseHeight: 1,
  properties: {
    'rarity': 'RARE',
    'type': 'weapon',
    // attackPower는 세트 효과에서만 적용
    'weapon': {
      'type': 'melee',
      'baseDamage': 18,
      'staminaCost': 2.5,
      'cooldown': 0.8,
      'accuracy': 0.85,
      'criticalChance': 0.12,
      'criticalMultiplier': 1.6,
    },
    'effects': [
      {
        'type': 'haste',
        'stack': 1,  // 1스택 가속
        'target': 'self',  // 자신에게 버프
        'trigger': 'on_hit',
        // chance 필드 없음 → 적중 시 항상 적용 (100%)
      },
    ],
  },
)
```

### 7. 중독 효과 무기

```dart
RewardItemDefinition(
  id: 'venom_dagger',
  name: '독 단검',
  description: '독으로 적을 약화시키는 단검',
  baseWidth: 1,
  baseHeight: 1,
  properties: {
    'rarity': 'RARE',
    'type': 'weapon',
    // attackPower는 세트 효과에서만 적용
    'weapon': {
      'type': 'melee',
      'baseDamage': 12,
      'staminaCost': 2.0,
      'cooldown': 0.7,
      'accuracy': 0.9,
      'criticalChance': 0.15,
      'criticalMultiplier': 1.7,
    },
    'effects': [
      {
        'type': 'poison',
        'stack': 3,  // 3스택 중독
        'target': 'enemy',
        'trigger': 'on_hit',
        // chance 필드 없음 → 적중 시 항상 적용 (100%)
        // 특수한 경우: 'chance': 0.6을 추가하면 60% 확률로 발동
      },
    ],
  },
)
```

### 8. 확률 발동 효과 무기 (특수한 경우)

```dart
RewardItemDefinition(
  id: 'unstable_sword',
  name: '불안정한 검',
  description: '때때로 강력한 효과를 발동하는 검',
  baseWidth: 1,
  baseHeight: 1,
  properties: {
    'rarity': 'EPIC',
    'type': 'weapon',
    // attackPower는 세트 효과에서만 적용
    'weapon': {
      'type': 'melee',
      'baseDamage': 20,
      'staminaCost': 3.0,
      'cooldown': 1.0,
      'accuracy': 0.8,
      'criticalChance': 0.1,
      'criticalMultiplier': 1.5,
    },
    'effects': [
      {
        'type': 'burn',
        'stack': 2,  // 2스택 화상
        'target': 'enemy',
        'trigger': 'on_hit',
        'chance': 0.5,  // 50% 확률로 발동 (특수한 경우)
      },
      {
        'type': 'frost',
        'stack': 1,
        'target': 'enemy',
        'trigger': 'on_hit',
        'chance': 0.3,  // 30% 확률로 발동
      },
    ],
  },
)
```

**참고:**
- `chance` 필드가 없거나 `1.0`이면 항상 적용됩니다 (기본 동작)
- `chance` 필드가 `0.0~0.99` 사이면 해당 확률로 발동됩니다
- 위 예시에서는 적중 시 50% 확률로 화상, 30% 확률로 동상이 발동됩니다

### 9. 전투 시작 효과 + 패시브 효과 (방어구)

```dart
RewardItemDefinition(
  id: 'shabby_robe',
  name: '허름한 로브',
  description: '낡았지만 마법이 깃든 로브',
  baseWidth: 1,
  baseHeight: 1,
  properties: {
    'rarity': 'COMMON',
    'type': 'armor',
    'combat': {
      'maxHealth': 25,  // 최대 체력 +25
    },
    'effects': [
      {
        'type': 'resistance',
        'stack': 2,
        'target': 'self',
        'trigger': 'on_combat_start',  // 전투 시작 시 저항 2스택 획득
      },
      {
        'type': 'mana',
        'stack': 5,
        'target': 'self',
        'trigger': 'on_combat_start',  // 전투 시작 시 마나 5스택 획득
      },
      {
        'type': 'mana',
        'stack': 2,
        'target': 'self',
        'trigger': 'passive',
        'interval': 4.0,  // 4초마다 마나 2스택 획득
      },
    ],
  },
)
```

**참고:**
- `trigger: 'on_combat_start'`는 전투 시작 시 한 번만 발동됩니다
- `trigger: 'passive'`는 전투 중 `interval` 초마다 반복 발동됩니다
- `target: 'self'`는 착용자에게 효과를 적용합니다

---

## 확장 가이드

### 새로운 효과 타입 추가

1. **StatusEffect 클래스 생성** (`lib/combat/status_effect.dart`)
   ```dart
   class NewEffect extends StatusEffect {
     NewEffect({
       required CombatEntity target,
       int initialStacks = 0,
     }) : super(
       id: 'new_effect',
       name: '새 효과',
       type: EffectType.DEBUFF,  // 또는 BUFF
       stacks: initialStacks,
       target: target,
     );
     
     @override
     void tick(double deltaTimeMs) {
       // 틱마다 실행될 로직
     }
   }
   ```

2. **EffectProcessor에 등록** (`lib/combat/effect_processor.dart`)
   ```dart
   switch (effectType.toLowerCase()) {
     case 'new_effect':
       statusEffect = NewEffect(
         target: target,
         initialStacks: stack,
       );
       break;
   }
   ```

3. **아이템에서 사용**
   ```dart
   'effects': [
     {
       'type': 'new_effect',
       'stack': 1,
       'target': 'enemy',
       'trigger': 'on_hit',
       'chance': 0.3,
     },
   ]
   ```

### 새로운 트리거 타입 추가

1. **EffectProcessor에 트리거 처리 추가**
   ```dart
   // trigger 확인
   final trigger = effectData['trigger'] as String?;
   if (trigger == 'on_hit' || trigger == 'on_critical') {
     // 처리 로직
   }
   ```

2. **적절한 위치에서 EffectProcessor 호출**
   - `on_hit`: `Weapon.use()` 내부 (현재 구현됨)
   - `on_critical`: 치명타 발생 시점에 추가 호출 필요

---

## 데이터 타입 요약

| 필드 | 타입 | 필수 | 기본값 | 설명 |
|------|------|------|--------|------|
| `id` | String | ✅ | - | 고유 ID |
| `name` | String | ✅ | - | 표시 이름 |
| `description` | String | ❌ | - | 설명 |
| `baseWidth` | int | ✅ | - | (사용 안 함, 호환성 유지용) |
| `baseHeight` | int | ✅ | - | (사용 안 함, 호환성 유지용) |
| `rarity` | String | ❌ | COMMON | 'COMMON', 'RARE', 'EPIC', 'LEGENDARY' (대소문자 무관, 정규화됨) |
| `type` | String | ❌ | misc | 'weapon', 'armor', 'accessory', 'bag' (대소문자 무관, 정규화됨) |
| `buyPrice` | int | ❌ | 0 | 구입 가격 (판매 가격은 자동으로 구입 가격의 절반) |
| `weightUnits` | int | ❌ | 0* | 무게 (1 unit = 0.5 weight). *우선순위 해석, 위 참조 |
| `combat` | Map | ❌ | - | 전투 스탯 |
| `weapon` | Map | ❌ | - | 무기 속성 (무기 타입 필수) |
| `effects` | List | ❌ | [] | 전투 효과 배열 |

**참고:**
- `buyPrice`: `properties['buyPrice']`에 저장. `InventoryItem.buyPrice` getter로 접근
- 판매 가격: `InventoryItem.sellPrice` getter로 자동 계산 (구입 가격 ÷ 2)
- `weightUnits`: `properties['weightUnits']`에 저장 (권장). `InventoryItem.weightUnits` getter로 접근
- 무게: `InventoryItem.weight` getter로 접근 (weightUnits ÷ 2). 해석 우선순위는 "무게(weightUnits) 해석 우선순위" 섹션 참조
- `rarity`: `InventoryItem.rarity` (enum) 또는 `InventoryItem.rarityString` (대문자 문자열)로 접근. 대소문자 무관, 누락 시 COMMON. 위 "희귀도(rarity) 정규화 규칙" 참조
- `type`: `InventoryItem.itemType` (enum) 또는 `InventoryItem.itemTypeString` (소문자 문자열)로 접근. 대소문자 무관, alias 지원, 누락 시 misc. 위 "타입(type) 정규화 규칙" 참조

### Effects 배열 내부 구조

| 필드 | 타입 | 필수 | 기본값 | 설명 |
|------|------|------|--------|------|
| `type` | String | ✅ | - | 효과 타입 |
| `stack` | int | ❌ | 1 | 스택 수 |
| `target` | String | ❌ | 'enemy' | 'enemy' 또는 'self' |
| `trigger` | String | ✅ | - | 'on_hit', 'on_combat_start', 'passive' |
| `chance` | double | ❌ | 1.0 | 발동 확률 (on_hit에서만 사용) |
| `interval` | double | ❌ | 1.0 | 발동 주기 초 (passive에서만 사용) |

---

## 주의사항

1. **명중 판정**: `trigger: 'on_hit'` 효과는 무기 공격이 **명중**했을 때만 발동됩니다
2. **기본 동작**: `on_hit` 트리거는 기본적으로 항상 효과가 적용됩니다 (`chance` 필드가 없거나 1.0인 경우)
3. **확률 발동**: 특수한 경우를 위해 `chance` 필드를 0.0~0.99 사이로 설정하면 확률 판정이 수행됩니다
3. **스택 중복**: 동일 효과가 이미 적용된 경우 스택이 추가됩니다 (BleedingEffect의 경우)
4. **타입 대소문자**: 효과 타입은 대소문자 구분 없이 처리됩니다 (`toLowerCase()` 사용)
5. **Character 타입**: 효과는 `Character` 타입에만 적용 가능합니다

---

## 참고 파일

- 아이템 정의: `lib/reward/reward_item_factory.dart`
- 효과 처리: `lib/combat/effect_processor.dart`
- 상태 효과: `lib/combat/status_effect.dart`
- 무기 클래스: `lib/combat/item.dart`
- 인벤토리 어댑터: `lib/modules/combat/inventory_adapter.dart`
- 실제 사용 예시: `lib/screens/reward_screen.dart`

---

## 업데이트 이력

- 2024-XX-XX: 초기 문서 작성
  - 기본 구조 정의
  - 전투 효과 스키마 추가
  - 확장 가이드 작성

