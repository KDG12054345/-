/// 인벤토리/가방 시스템 QA 모듈
/// 
/// 기존 인벤토리 로직을 절대 수정하지 않고,
/// 테스트와 진단을 위한 기능만 제공합니다.
/// 
/// ## 사용 예시
/// 
/// ```dart
/// import 'package:your_app/qa/inventory_qa.dart';
/// 
/// void main() {
///   final inventory = InventorySystem(...);
///   
///   // 진단 출력
///   dumpInventoryDiagnostic(inventory);
///   
///   // QA 명령어 사용
///   final qa = InventoryQaCommands(inventory);
///   qa.qaResetInventory();
///   qa.qaEquipBag(BagType.basic);
///   qa.qaAddTestItem(itemType: 'A');
///   qa.qaDump();
///   
///   // 기본 테스트 실행 (13개)
///   qaRunAllInventoryBagTests(inventory);
///   
///   // 전체 테스트 실행 (기본 + 스트레스 + 전투 스냅샷)
///   qaRunAllInventoryAndCombatSnapshotTests(inventory);
///   
///   // 전투 스냅샷 진단
///   dumpCombatSnapshotDiagnostic(inventory);
/// }
/// ```
library inventory_qa;

export 'inventory_diagnostic.dart';
export 'inventory_qa_commands.dart';
export 'inventory_qa_scenarios.dart';
export 'inventory_stress_test.dart';
export 'combat_snapshot_diagnostic.dart';
