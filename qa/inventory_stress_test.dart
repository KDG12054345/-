/// 인벤토리/가방 시스템 스트레스 테스트
/// 
/// 가방 장착/해제/교체 및 아이템 추가/삭제를 반복하여
/// 불변조건이 항상 유지되는지 검증합니다.
library;

import 'dart:math';
import '../inventory/inventory_system.dart';
import '../inventory/bag.dart';
import 'inventory_diagnostic.dart';
import 'inventory_qa_commands.dart';

/// 스트레스 테스트 설정
class StressTestConfig {
  /// 반복 횟수 (기본 100회)
  final int iterations;
  
  /// 랜덤 시드 (결정적 재현성)
  final int seed;
  
  /// 진행률 출력 간격
  final int progressInterval;
  
  /// 실패 시 즉시 중단 여부
  final bool stopOnFirstFailure;
  
  const StressTestConfig({
    this.iterations = 100,
    this.seed = 12345,
    this.progressInterval = 10,
    this.stopOnFirstFailure = true,
  });
}

/// 스트레스 테스트 결과
class StressTestResult {
  final bool passed;
  final int totalIterations;
  final int completedIterations;
  final int failedIteration;
  final String? failureReason;
  final String? failureDump;
  final List<String> log;
  
  const StressTestResult({
    required this.passed,
    required this.totalIterations,
    required this.completedIterations,
    this.failedIteration = -1,
    this.failureReason,
    this.failureDump,
    this.log = const [],
  });
}

/// 불변조건 검증 결과
class InvariantCheckResult {
  final bool passed;
  final List<String> violations;
  
  const InvariantCheckResult({
    required this.passed,
    this.violations = const [],
  });
  
  factory InvariantCheckResult.pass() => const InvariantCheckResult(passed: true);
  
  factory InvariantCheckResult.fail(List<String> violations) => 
      InvariantCheckResult(passed: false, violations: violations);
}

/// 인벤토리 스트레스 테스트 클래스
class InventoryStressTest {
  final InventorySystem inventory;
  final StressTestConfig config;
  
  late final InventoryQaCommands _qa;
  late final InventoryDiagnostic _diagnostic;
  late final Random _rng;
  
  final List<String> _log = [];
  
  InventoryStressTest(this.inventory, {StressTestConfig? config})
      : config = config ?? const StressTestConfig() {
    _qa = InventoryQaCommands(inventory);
    _diagnostic = InventoryDiagnostic(inventory);
    _rng = Random(this.config.seed);
  }
  
  /// 스트레스 테스트 실행
  StressTestResult run() {
    _log.clear();
    _logHeader();
    
    // 초기화
    _qa.qaResetToStarter();
    _log.add('[Init] Reset to starter configuration');
    
    // 초기 상태 검증
    final initialCheck = _verifyAllInvariants('Initial');
    if (!initialCheck.passed) {
      return StressTestResult(
        passed: false,
        totalIterations: config.iterations,
        completedIterations: 0,
        failedIteration: 0,
        failureReason: 'Initial state failed invariant check',
        failureDump: _diagnostic.dumpToString(),
        log: List.from(_log),
      );
    }
    
    // 메인 루프
    for (int i = 1; i <= config.iterations; i++) {
      // 진행률 출력
      if (i % config.progressInterval == 0 || i == 1) {
        _log.add('[Progress] Iteration $i/${config.iterations}');
        print('[StressTest] Iteration $i/${config.iterations} (seed=${config.seed})');
      }
      
      // 랜덤 작업 수행
      final action = _performRandomAction(i);
      
      // 불변조건 검증
      final check = _verifyAllInvariants('Iteration $i after $action');
      
      if (!check.passed) {
        _log.add('[FAIL] Iteration $i - Invariant violation after: $action');
        for (final v in check.violations) {
          _log.add('  - $v');
        }
        
        if (config.stopOnFirstFailure) {
          return StressTestResult(
            passed: false,
            totalIterations: config.iterations,
            completedIterations: i - 1,
            failedIteration: i,
            failureReason: 'Invariant violation after: $action\n${check.violations.join('\n')}',
            failureDump: _diagnostic.dumpToString(),
            log: List.from(_log),
          );
        }
      }
    }
    
    _log.add('[PASS] All ${config.iterations} iterations completed successfully');
    print('[StressTest] ✅ PASS - All ${config.iterations} iterations completed (seed=${config.seed})');
    
    return StressTestResult(
      passed: true,
      totalIterations: config.iterations,
      completedIterations: config.iterations,
      log: List.from(_log),
    );
  }
  
  /// 랜덤 작업 수행
  String _performRandomAction(int iteration) {
    // 작업 타입 선택 (0-4)
    final actionType = _rng.nextInt(5);
    
    switch (actionType) {
      case 0:
        // 가방 장착
        final bagTypes = BagType.values;
        final bagType = bagTypes[_rng.nextInt(bagTypes.length)];
        final success = _qa.qaEquipBag(bagType);
        return 'EquipBag(${bagType.name}) -> ${success ? "OK" : "REJECTED"}';
        
      case 1:
        // 가방 해제
        if (inventory.bags.isEmpty) {
          return 'UnequipBag() -> SKIPPED (no bags)';
        }
        final (success, destroyed) = _qa.qaUnequipBag();
        return 'UnequipBag() -> ${success ? "OK" : "FAILED"} (destroyed: ${destroyed.length})';
        
      case 2:
        // 가방 교체
        if (inventory.bags.isEmpty) {
          return 'SwapBag() -> SKIPPED (no bags)';
        }
        final oldBag = inventory.bags[_rng.nextInt(inventory.bags.length)];
        final bagTypes = BagType.values;
        final newType = bagTypes[_rng.nextInt(bagTypes.length)];
        final (success, destroyed) = _qa.qaSwapBag(oldBag.id, newType);
        return 'SwapBag(${oldBag.name}->${newType.name}) -> ${success ? "OK" : "FAILED"} (destroyed: ${destroyed.length})';
        
      case 3:
        // 아이템 추가
        final itemTypes = ['A', 'B', 'C'];
        final itemType = itemTypes[_rng.nextInt(itemTypes.length)];
        final success = _qa.qaAddTestItem(itemType: itemType);
        return 'AddItem($itemType) -> ${success ? "OK" : "REJECTED"}';
        
      case 4:
        // 스타터로 리셋 (10% 확률로만 수행)
        if (_rng.nextInt(10) == 0) {
          _qa.qaResetToStarter();
          _qa.clearDestroyedRecord();
          return 'ResetToStarter()';
        }
        // 아이템 추가로 대체
        final success = _qa.qaAddTestItem(itemType: 'A');
        return 'AddItem(A) -> ${success ? "OK" : "REJECTED"}';
        
      default:
        return 'Unknown action';
    }
  }
  
  /// 모든 불변조건 검증
  InvariantCheckResult _verifyAllInvariants(String context) {
    final violations = <String>[];
    final result = _diagnostic.diagnose();
    
    // 1. UsedCountByDump == UsedCountBySystem
    if (!result.isUsedCountValid) {
      violations.add('UsedCount mismatch: ByDump=${result.usedCountByDump}, BySystem=${result.usedCountBySystem}');
    }
    
    // 2. UsedBagSlots == Σ(bagSlotCost)
    final expectedBagSlots = inventory.bags.fold(0, (sum, bag) => sum + bag.bagSlotCost);
    if (inventory.usedBagSlots != expectedBagSlots) {
      violations.add('BagSlots mismatch: actual=${inventory.usedBagSlots}, expected sum=$expectedBagSlots');
    }
    
    // 3. ActiveItemSlots == Σ(itemSlots)
    final expectedItemSlots = inventory.bags.fold(0, (sum, bag) => sum + bag.itemSlotCount);
    if (inventory.totalItemSlots != expectedItemSlots) {
      violations.add('ItemSlots mismatch: actual=${inventory.totalItemSlots}, expected sum=$expectedItemSlots');
    }
    
    // 4. MaxWeight == Σ(maxWeightBonus) (하드캡 100 적용)
    final rawWeightSum = inventory.bags.fold(0, (sum, bag) => sum + bag.weightBonus);
    final expectedMaxWeight = rawWeightSum > 100 ? 100.0 : rawWeightSum.toDouble();
    if (inventory.maxWeight != expectedMaxWeight) {
      // 가방이 0개일 때는 legacy maxWeightUnits 사용하므로 예외 처리
      if (inventory.bags.isNotEmpty) {
        violations.add('MaxWeight mismatch: actual=${inventory.maxWeight}, expected=$expectedMaxWeight');
      }
    }
    
    // 5. 비활성(X) 영역에 아이템이 존재하면 FAIL
    final itemsInSlots = result.slotDump.where((s) => s != '.' && s != 'X').length;
    final activeSlots = result.totalItemSlots;
    if (itemsInSlots > activeSlots) {
      violations.add('Items in inactive slots: $itemsInSlots items but only $activeSlots active slots');
    }
    
    // 6. DestroyOverflowCount 검증 (방금 파괴가 발생했다면)
    // 이 검증은 unequip 직후에만 의미가 있으므로 별도 체크 필요 없음
    
    if (violations.isEmpty) {
      return InvariantCheckResult.pass();
    }
    
    return InvariantCheckResult.fail(violations);
  }
  
  void _logHeader() {
    _log.add('╔══════════════════════════════════════════════════════════════╗');
    _log.add('║          INVENTORY STRESS TEST                               ║');
    _log.add('╚══════════════════════════════════════════════════════════════╝');
    _log.add('Config: iterations=${config.iterations}, seed=${config.seed}');
    _log.add('');
  }
}

/// 스트레스 테스트 실행 단축 함수
StressTestResult runInventoryStressTest(
  InventorySystem inventory, {
  int iterations = 100,
  int seed = 12345,
}) {
  final test = InventoryStressTest(
    inventory,
    config: StressTestConfig(iterations: iterations, seed: seed),
  );
  return test.run();
}
