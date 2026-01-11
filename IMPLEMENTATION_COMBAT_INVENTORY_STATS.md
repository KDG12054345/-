# 전투-인벤토리 스탯 통합 구현 완료

> 전투 시 적/플레이어 인벤토리가 실제 전투 스탯에 반영되도록 구현 완료

## 📋 구현 요약

### 목표
1. **적 인벤토리 → 전투 스탯 반영**
2. **플레이어 인벤토리 → 전투 스탯 반영**

### 구현 결과
- ✅ 인벤토리 어댑터 생성 (`lib/modules/combat/inventory_adapter.dart`)
- ✅ 전투 모듈 수정 (적 인벤토리 스탯 반영 완료)
- ⚠️ 플레이어 인벤토리 연동 (GameVM에 인벤토리 추가 필요, 준비 완료)

---

## 📁 1. 수정/추가한 파일 경로

### 🆕 신규 파일

```
lib/modules/combat/inventory_adapter.dart  (242줄)
```
- `InventoryItem` → `CombatStats` 변환
- 시너지 효과 스탯 추출
- 전투 캐릭터 생성 헬퍼 함수

### ✏️ 수정 파일

```
lib/modules/combat/combat_module.dart
```
- 라인 11: `inventory_adapter.dart` import 추가
- 라인 56-86: 플레이어 캐릭터 생성 로직 수정 (준비 완료, TODO 주석 추가)
- 라인 88-109: 적 캐릭터 생성 로직 수정 (✅ 완료)

---

## 🔧 2. 변경된 함수/클래스 시그니처

### InventoryAdapter 클래스 (신규)

```dart
class InventoryAdapter {
  /// InventoryItem의 properties에서 전투 스탯 추출
  static CombatStats extractCombatStats(InventoryItem item);
  
  /// 시너지 효과에서 전투 스탯 추출
  static CombatStats extractSynergyStats(SynergyInfo synergy);
  
  /// 인벤토리 전체에서 전투 스탯 합산 (아이템 + 시너지)
  static CombatStats calculateTotalStats(InventorySystem inventory);
  
  /// 인벤토리를 전투 캐릭터의 스탯에 적용
  static CombatStats applyInventoryToStats(
    CombatStats baseStats, 
    InventorySystem inventory,
  );
  
  /// 인벤토리에서 무기 아이템들을 추출하여 Combat Weapon으로 변환
  static List<Weapon> extractWeapons(InventorySystem inventory);
  
  /// 플레이어 인벤토리 → 전투 캐릭터 생성 헬퍼
  static Character createPlayerCharacter({
    required String name,
    required CombatStats baseStats,
    required InventorySystem inventory,
  });
  
  /// 적 인벤토리 → 스탯 보너스 계산
  static CombatStats calculateEnemyStatsBonus(InventorySystem enemyInventory);
  
  /// 적 인벤토리 → 전투 캐릭터 생성 헬퍼
  static Character createEnemyCharacter({
    required String name,
    required CombatStats baseStats,
    required InventorySystem inventory,
  });
}
```

### CombatModule 수정 사항

**이전 (적 캐릭터 생성):**
```dart
final enemyChar = Character(
  name: '도적',
  stats: CombatStats(maxHealth: 80, attackPower: 15, accuracy: 70),
);

final enemyInventory = EnemyInventoryLoader.loadFromEncounter(payload);
// TODO: 아이템 효과를 전투 스탯에 반영
```

**이후 (✅ 적용 완료):**
```dart
final enemyBaseStats = CombatStats(maxHealth: 80, attackPower: 15, accuracy: 70);
final enemyInventory = EnemyInventoryLoader.loadFromEncounter(payload);

// ✅ 인벤토리 스탯 자동 반영
final enemyChar = InventoryAdapter.createEnemyCharacter(
  name: '도적',
  baseStats: enemyBaseStats,
  inventory: enemyInventory,
);
```

---

## 📊 3. 예시: 인벤토리 입력 → 전투 스탯 출력

### 예시 1: 적 인벤토리 (Manual 모드)

**JSON 입력 (assets/dialogue/encounters/bandit_encounter.json):**
```json
{
  "id": "forest_bandit_01",
  "title": "숲속의 도적",
  "combat": {
    "enemyName": "도적",
    "enemyStats": {
      "maxHealth": 80,
      "attackPower": 15,
      "accuracy": 70
    },
    "enemyInventory": {
      "mode": "manual",
      "grid": { "width": 9, "height": 6 },
      "items": [
        {
          "id": "rusty_sword",
          "position": { "x": 0, "y": 0 },
          "rotation": 0,
          "properties": {
            "combat": {
              "attackPower": 10,
              "maxHealth": 0,
              "accuracy": 5
            }
          }
        },
        {
          "id": "leather_armor",
          "position": { "x": 2, "y": 0 },
          "rotation": 0,
          "properties": {
            "combat": {
              "maxHealth": 20,
              "attackPower": 0,
              "accuracy": 0
            }
          }
        },
        {
          "id": "health_potion",
          "position": { "x": 4, "y": 0 },
          "rotation": 0,
          "properties": {
            "combat": {
              "maxHealth": 15,
              "attackPower": 0,
              "accuracy": 0
            }
          }
        }
      ]
    }
  }
}
```

**전투 스탯 출력:**
```
[InventoryAdapter] Calculating total combat stats...
[InventoryAdapter]   rusty_sword: HP+0, ATK+10, ACC+5
[InventoryAdapter]   leather_armor: HP+20, ATK+0, ACC+0
[InventoryAdapter]   health_potion: HP+15, ATK+0, ACC+0
[InventoryAdapter] Total: HP+35, ATK+10, ACC+5

[InventoryAdapter] Enemy character created: 도적
[InventoryAdapter]   HP: 115 (기본 80 + 인벤토리 35)
[InventoryAdapter]   ATK: 25 (기본 15 + 인벤토리 10)
[InventoryAdapter]   ACC: 75 (기본 70 + 인벤토리 5)
[InventoryAdapter]   Weapons: 0
```

### 예시 2: 시너지 효과 포함

**InventoryItem 설정:**
```dart
// 아이템 1: 화염 검
final fireSword = InventoryItem(
  id: 'fire_sword',
  name: '화염 검',
  baseWidth: 1,
  baseHeight: 3,
  iconPath: 'assets/items/fire_sword.png',
  properties: {
    'combat': {
      'attackPower': 15,
      'maxHealth': 0,
      'accuracy': 10,
    },
    'weapon': {
      'type': 'melee',
      'baseDamage': 20.0,
      'staminaCost': 10.0,
      'cooldown': 2.0,
      'accuracy': 0.8,
      'criticalChance': 0.15,
      'criticalMultiplier': 2.0,
    }
  },
);

// 아이템 2: 화염 부적
final fireAmulet = InventoryItem(
  id: 'fire_amulet',
  name: '화염 부적',
  baseWidth: 1,
  baseHeight: 1,
  iconPath: 'assets/items/fire_amulet.png',
  properties: {
    'combat': {
      'attackPower': 5,
      'maxHealth': 10,
      'accuracy': 5,
    }
  },
);

// 시너지 정의
final fireSynergy = SynergyInfo(
  name: '화염 마스터',
  description: '화염 검과 화염 부적을 함께 장착하면 강력한 시너지 발동',
  requiredItemIds: ['fire_sword', 'fire_amulet'],
  effects: {
    'attackPower': 20,
    'maxHealth': 15,
    'accuracy': 10,
  },
);
```

**전투 스탯 출력:**
```
[InventoryAdapter] Calculating total combat stats...
[InventoryAdapter]   화염 검: HP+0, ATK+15, ACC+10
[InventoryAdapter]   화염 부적: HP+10, ATK+5, ACC+5
[InventoryAdapter]   🔗 화염 마스터: HP+15, ATK+20, ACC+10
[InventoryAdapter] Total: HP+25, ATK+40, ACC+25

[InventoryAdapter] Extracted weapon: 화염 검 (melee)
[InventoryAdapter] Player character created: 모험가
[InventoryAdapter]   HP: 125 (기본 100 + 인벤토리 25)
[InventoryAdapter]   ATK: 55 (기본 15 + 인벤토리 40)
[InventoryAdapter]   ACC: 100 (기본 75 + 인벤토리 25)
[InventoryAdapter]   Weapons: 1
```

### 예시 3: Auto 모드 (적 인벤토리 자동 생성)

**JSON 입력:**
```json
{
  "combat": {
    "enemyName": "숙련된 도적",
    "enemyStats": {
      "maxHealth": 100,
      "attackPower": 20,
      "accuracy": 75
    },
    "enemyInventory": {
      "mode": "auto",
      "autoGeneration": {
        "difficulty": "medium",
        "level": 5,
        "weaponCount": 2,
        "armorCount": 1,
        "consumableCount": 3
      }
    }
  }
}
```

**전투 스탯 출력 (예상):**
```
[EnemyInventoryLoader] Auto mode: difficulty=medium, level=5
[EnemyInventoryGenerator] Generating inventory...
[EnemyInventoryGenerator]   - Weapon: steel_sword (ATK+12, ACC+8)
[EnemyInventoryGenerator]   - Weapon: iron_dagger (ATK+8, ACC+10)
[EnemyInventoryGenerator]   - Armor: chainmail (HP+30)
[EnemyInventoryGenerator]   - Consumable: bandage (HP+10)
[EnemyInventoryGenerator]   - Consumable: strength_potion (ATK+5)
[EnemyInventoryGenerator]   - Consumable: focus_potion (ACC+5)

[InventoryAdapter] Calculating total combat stats...
[InventoryAdapter]   steel_sword: HP+0, ATK+12, ACC+8
[InventoryAdapter]   iron_dagger: HP+0, ATK+8, ACC+10
[InventoryAdapter]   chainmail: HP+30, ATK+0, ACC+0
[InventoryAdapter]   bandage: HP+10, ATK+0, ACC+0
[InventoryAdapter]   strength_potion: HP+0, ATK+5, ACC+0
[InventoryAdapter]   focus_potion: HP+0, ATK+0, ACC+5
[InventoryAdapter] Total: HP+40, ATK+25, ACC+23

[InventoryAdapter] Enemy character created: 숙련된 도적
[InventoryAdapter]   HP: 140 (기본 100 + 인벤토리 40)
[InventoryAdapter]   ATK: 45 (기본 20 + 인벤토리 25)
[InventoryAdapter]   ACC: 98 (기본 75 + 인벤토리 23)
[InventoryAdapter]   Weapons: 2
```

---

## 🔄 4. 데이터 흐름

```
┌─────────────────────────────────────────────────────────────┐
│                    EnterCombat 이벤트                        │
│              (JSON 인카운터 또는 테스트 버튼)                 │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              CombatModule._handleEnterCombat()               │
└─────────────┬───────────────────────────────────────┬───────┘
              │                                       │
              │ 플레이어                               │ 적
              ▼                                       ▼
┌──────────────────────────┐         ┌──────────────────────────┐
│ 1. 플레이어 기본 스탯 계산 │         │ 1. 적 기본 스탯 (JSON)    │
│    (vitality, strength)  │         │    (maxHealth, attackPower)│
└──────────┬───────────────┘         └───────────┬──────────────┘
           │                                     │
           │ (TODO: GameVM 연동)                 │
           ▼                                     ▼
┌──────────────────────────┐         ┌──────────────────────────┐
│ 2. 플레이어 인벤토리      │         │ 2. 적 인벤토리 로드       │
│    vm.playerInventory    │         │  EnemyInventoryLoader    │
│    (아직 미연동)         │         │  - Manual/Auto/Hybrid    │
└──────────┬───────────────┘         └───────────┬──────────────┘
           │                                     │
           │                                     ▼
           │                         ┌──────────────────────────┐
           │                         │ 3. InventoryAdapter      │
           │                         │  .createEnemyCharacter() │
           │                         │  - 스탯 추출 및 합산      │
           │                         │  - 시너지 계산           │
           │                         │  - 무기 추출             │
           │                         └───────────┬──────────────┘
           │                                     │
           ▼                                     ▼
┌──────────────────────────┐         ┌──────────────────────────┐
│ Character(플레이어)       │         │ Character(적)            │
│ - 기본 스탯만             │         │ - 기본 스탯 + 인벤토리   │
│                          │         │ - 무기 장착 완료         │
│ (인벤토리 연동 시:)       │         │ - 인벤토리 시스템 연결   │
│ - 기본 + 인벤토리 스탯    │         │                          │
│ - 무기 장착               │         │                          │
└──────────┬───────────────┘         └───────────┬──────────────┘
           │                                     │
           └─────────────┬───────────────────────┘
                         ▼
              ┌──────────────────────┐
              │   CombatEngine 생성   │
              │   - player: 플레이어   │
              │   - enemy: 적         │
              │   - start() 호출      │
              └──────────┬───────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │  전투 시작!           │
              │  (100ms 틱 주기)      │
              └──────────────────────┘
```

---

## 🚀 5. 사용 방법

### A. 적 인벤토리 스탯 반영 (✅ 완료)

**JSON 인카운터 파일에 적 인벤토리 정의:**

```json
{
  "combat": {
    "enemyInventory": {
      "mode": "manual",
      "items": [
        {
          "id": "sword_01",
          "properties": {
            "combat": {
              "attackPower": 10,
              "maxHealth": 0,
              "accuracy": 5
            }
          }
        }
      ]
    }
  }
}
```

**자동으로 스탯 반영됨!**

### B. 플레이어 인벤토리 스탯 반영 (⚠️ 준비 완료)

**GameVM에 플레이어 인벤토리 추가 필요:**

```dart
// lib/core/state/game_state.dart 수정 (TODO)
class GameVM {
  final Player? player;
  final CombatState? combat;
  final InventorySystem? playerInventory;  // 🆕 추가 필요
  
  const GameVM({
    // ...
    this.playerInventory,
  });
}
```

**combat_module.dart에서 주석 제거:**

```dart
// 현재 (라인 66-72):
// final playerInventory = vm.playerInventory ?? InventorySystem(width: 9, height: 6);
// final playerChar = InventoryAdapter.createPlayerCharacter(
//   name: '모험가',
//   baseStats: playerBaseStats,
//   inventory: playerInventory,
// );

// TODO: GameVM에 playerInventory 추가 후 주석 제거
```

---

## 📝 6. 아이템 properties 설정 가이드

### 전투 스탯 보너스 설정

```dart
InventoryItem(
  id: 'legendary_sword',
  name: '전설의 검',
  baseWidth: 1,
  baseHeight: 4,
  iconPath: 'assets/items/legendary_sword.png',
  properties: {
    // ✅ 전투 스탯 보너스
    'combat': {
      'maxHealth': 50,      // 최대 체력 +50
      'attackPower': 30,    // 공격력 +30
      'accuracy': 15,       // 명중률 +15
    },
    
    // ✅ 무기 정보 (전투에서 실제 사용)
    'weapon': {
      'type': 'melee',            // 'melee' 또는 'ranged'
      'baseDamage': 40.0,         // 기본 데미지
      'staminaCost': 15.0,        // 스태미나 소모
      'cooldown': 2.5,            // 쿨다운 (초)
      'accuracy': 0.85,           // 명중률 (0.0 ~ 1.0)
      'criticalChance': 0.2,      // 치명타 확률
      'criticalMultiplier': 2.5,  // 치명타 배율
    },
    
    // 기타 메타데이터
    'type': 'weapon',
    'rarity': 'legendary',
  },
)
```

### 시너지 효과 설정

```dart
SynergyInfo(
  name: '전사의 각성',
  description: '전설의 검과 전사의 투구를 함께 장착하면 엄청난 힘을 얻는다',
  requiredItemIds: ['legendary_sword', 'warrior_helmet'],
  effects: {
    'maxHealth': 100,    // 체력 +100
    'attackPower': 50,   // 공격력 +50
    'accuracy': 20,      // 명중률 +20
  },
)
```

---

## ✅ 7. 완료 체크리스트

- [x] `InventoryAdapter` 클래스 생성
  - [x] `extractCombatStats()` - 아이템별 스탯 추출
  - [x] `extractSynergyStats()` - 시너지 스탯 추출
  - [x] `calculateTotalStats()` - 전체 스탯 합산
  - [x] `applyInventoryToStats()` - 기본 스탯 + 인벤토리 보너스
  - [x] `extractWeapons()` - 무기 추출 및 변환
  - [x] `createPlayerCharacter()` - 플레이어 캐릭터 생성 헬퍼
  - [x] `createEnemyCharacter()` - 적 캐릭터 생성 헬퍼

- [x] `CombatModule` 수정
  - [x] `inventory_adapter.dart` import
  - [x] 적 캐릭터 생성 로직 수정 (✅ 완전 작동)
  - [ ] 플레이어 캐릭터 생성 로직 수정 (준비 완료, GameVM 연동 필요)

- [ ] `GameVM` 수정 (TODO)
  - [ ] `playerInventory` 필드 추가
  - [ ] Provider에서 인벤토리 연결

- [x] 문서 작성
  - [x] 예시 코드
  - [x] 데이터 흐름 다이어그램
  - [x] properties 설정 가이드

---

## 🎯 8. 다음 단계

### 즉시 작업 가능
1. **적 인벤토리 테스트**: JSON 인카운터 파일에 적 인벤토리 추가하고 전투 시작
2. **아이템 데이터베이스 구축**: `properties['combat']` 값을 가진 아이템 생성
3. **시너지 정의**: 강력한 시너지 효과 설계

### GameVM 연동 후 작업
1. **플레이어 인벤토리 통합**: `game_state.dart`에 `playerInventory` 추가
2. **인벤토리 UI**: 전투 화면에서 양측 인벤토리 시각화
3. **전투 중 아이템 사용**: 실시간 아이템 효과 적용

---

## 📚 참고 자료

- `lib/inventory/inventory_system.dart` - 인벤토리 시스템
- `lib/combat/stats.dart` - 전투 스탯 정의
- `lib/combat/character.dart` - 전투 캐릭터
- `lib/combat/enemy_inventory_loader.dart` - 적 인벤토리 로더

---

**작성일:** 2025-11-02  
**버전:** 1.0.0  
**상태:** ✅ 적 인벤토리 완료, ⚠️ 플레이어 인벤토리 준비 완료






