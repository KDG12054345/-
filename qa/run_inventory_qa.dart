/// 인벤토리/가방 시스템 QA 테스트 실행 스크립트 (순수 Dart)
/// 
/// Flutter 의존성 없이 콘솔에서 바로 실행 가능합니다.
/// 
/// 실행 방법:
/// ```bash
/// # 기본 13개 테스트만 실행
/// dart lib/qa/run_inventory_qa.dart
/// 
/// # 전체 테스트 (기존 13개 + 스트레스 + 전투 스냅샷)
/// dart lib/qa/run_inventory_qa.dart --full
/// 
/// # 스트레스 테스트만 실행 (옵션: iterations, seed)
/// dart lib/qa/run_inventory_qa.dart --stress --iterations=200 --seed=54321
/// 
/// # 전투 스냅샷 테스트만 실행
/// dart lib/qa/run_inventory_qa.dart --combat
/// ```
library;

import '../inventory/inventory_system.dart';
import '../inventory/bag.dart';
import 'inventory_diagnostic.dart';
import 'inventory_qa_commands.dart';
import 'inventory_qa_scenarios.dart';

void main(List<String> args) {
  print('');
  print('╔══════════════════════════════════════════════════════════════╗');
  print('║     Fantasy Life - Inventory/Bag System QA Test Runner      ║');
  print('║           (Pure Dart Console - Extended Version)            ║');
  print('╚══════════════════════════════════════════════════════════════╝');
  print('');
  
  // 명령줄 인수 파싱
  final runFull = args.contains('--full');
  final runStressOnly = args.contains('--stress');
  final runCombatOnly = args.contains('--combat');
  
  int stressIterations = 100;
  int stressSeed = 12345;
  
  for (final arg in args) {
    if (arg.startsWith('--iterations=')) {
      stressIterations = int.tryParse(arg.split('=')[1]) ?? 100;
    } else if (arg.startsWith('--seed=')) {
      stressSeed = int.tryParse(arg.split('=')[1]) ?? 12345;
    }
  }
  
  // 테스트용 InventorySystem 생성 (시작 가방 없이)
  final inventory = InventorySystem(
    width: 9,
    height: 6,
    initWithStarterBags: false,
  );
  
  try {
    if (runFull) {
      // 전체 테스트 실행 (기존 13개 + 스트레스 + 전투 스냅샷)
      print('Mode: FULL (기존 13개 + 스트레스 + 전투 스냅샷)');
      print('Stress Config: iterations=$stressIterations, seed=$stressSeed');
      print('');
      
      final scenarios = InventoryQaScenariosExtended(inventory);
      scenarios.qaRunAllInventoryAndCombatSnapshotTests(
        stressIterations: stressIterations,
        stressSeed: stressSeed,
      );
    } else if (runStressOnly) {
      // 스트레스 테스트만 실행
      print('Mode: STRESS TEST ONLY');
      print('Config: iterations=$stressIterations, seed=$stressSeed');
      print('');
      
      final scenarios = InventoryQaScenariosExtended(inventory);
      final result = scenarios.runStressTest_BagSwapLoop(
        iterations: stressIterations,
        seed: stressSeed,
      );
      print(result.toString());
    } else if (runCombatOnly) {
      // 전투 스냅샷 테스트만 실행
      print('Mode: COMBAT SNAPSHOT TESTS ONLY');
      print('');
      
      final scenarios = InventoryQaScenariosExtended(inventory);
      
      print('\n=== CombatSnapshot_Baseline ===');
      final baselineResult = scenarios.runCombatSnapshot_Baseline();
      print(baselineResult.toString());
      
      print('\n=== CombatSnapshot_Immutability ===');
      final immutabilityResult = scenarios.runCombatSnapshot_Immutability();
      print(immutabilityResult.toString());
    } else {
      // 기본: 기존 13개 테스트만 실행
      print('Mode: BASIC (기존 13개 테스트)');
      print('(전체 테스트는 --full 옵션 사용)');
      print('');
      
      final scenarios = InventoryQaScenarios(inventory);
      scenarios.qaRunAllTests();
    }
    
    print('');
    print('═══════════════════════════════════════════════════════════════');
    print('QA 테스트 완료. 위 로그를 검토하여 O/X를 판정하세요.');
    print('═══════════════════════════════════════════════════════════════');
  } finally {
    // 정리
    inventory.dispose();
  }
}

/// 개별 시나리오 실행 (디버깅용)
void runSingleScenario(int scenarioNumber) {
  final inventory = InventorySystem(
    width: 9,
    height: 6,
    initWithStarterBags: false,
  );
  
  try {
    final scenarios = InventoryQaScenarios(inventory);
    
    switch (scenarioNumber) {
      case 1:
        print('시나리오 1: 단일 가방 검증 실행');
        scenarios.runScenario1_SingleBagVerification();
        break;
      case 2:
        print('시나리오 2: 합산 검증 실행');
        scenarios.runScenario2_CombinationVerification();
        break;
      case 3:
        print('시나리오 3: 가방 교체 검증 실행');
        scenarios.runScenario3_BagSwap();
        break;
      case 4:
        print('시나리오 4: 비활성 슬롯 검증 실행');
        scenarios.runScenario4_ItemInInactiveSlot();
        break;
      default:
        print('알 수 없는 시나리오 번호: $scenarioNumber');
    }
  } finally {
    inventory.dispose();
  }
}

/// 인터랙티브 QA 세션 (수동 테스트용)
void interactiveQaSession() {
  print('인터랙티브 QA 세션 시작');
  print('사용 가능한 명령어:');
  print('  reset     - 인벤토리 초기화');
  print('  starter   - 시작 구성으로 초기화');
  print('  +basic    - 기본 가방 장착');
  print('  +large    - 대형 가방 장착');
  print('  +damaged  - 구멍난 가방 장착');
  print('  +pouch    - 파우치 장착');
  print('  +damagedl - 구멍난 대형 가방 장착');
  print('  -bag      - 마지막 가방 해제');
  print('  +a, +b, +c - 테스트 아이템 추가');
  print('  dump      - 진단 출력');
  print('  status    - 간단 상태');
  print('  test      - 전체 테스트 실행');
  print('  quit      - 종료');
  print('');
  
  final inventory = InventorySystem(
    width: 9,
    height: 6,
    initWithStarterBags: false,
  );
  final qa = InventoryQaCommands(inventory);
  
  // 참고: 실제 인터랙티브 입력은 dart:io stdin이 필요하지만
  // 여기서는 예시만 제공
  print('(인터랙티브 모드는 dart:io stdin 사용이 필요합니다)');
  
  inventory.dispose();
}
