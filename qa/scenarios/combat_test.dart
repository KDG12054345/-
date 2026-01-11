import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../harness.dart';

/// 전투 로직 스모크 테스트 (Gate-1)
/// 
/// 이 테스트는 다음을 검증합니다:
/// 1. 게임 초기화 및 전투 진입
/// 2. 전투 상태가 정상적으로 생성되는지
/// 3. 시간 진행 시 HP가 감소하는지
/// 
/// 실행 방법:
/// ```bash
/// flutter test lib/qa/scenarios/combat_test.dart
/// ```
Future<void> main() async {
  // Flutter binding 초기화 (asset 로딩을 위해 필요)
  TestWidgetsFlutterBinding.ensureInitialized();
  
  print('=' * 60);
  print('전투 로직 스모크 테스트 (Gate-1)');
  print('=' * 60);
  
  final harness = HeadlessTestHarness();
  bool testPassed = false;
  String? failureReason;
  
  try {
    // Step 1: Seed 12345로 하네스 초기화
    print('\n[Step 1] 게임 초기화 (Seed: 12345)...');
    await harness.initialize(12345);
    print('✅ 게임 초기화 완료');
    
    // Step 2: forceEnterCombat() 호출
    print('\n[Step 2] 전투 강제 진입...');
    await harness.forceEnterCombat(
      enemyStats: {
        'maxHealth': 100,
        'attackPower': 15,
        'accuracy': 70,
      },
      enemyName: '테스트 적',
      encounterTitle: '스모크 테스트 전투',
    );
    print('✅ 전투 진입 완료');
    
    // Step 3: vm.combat이 null이 아님을 검증
    print('\n[Step 3] 전투 상태 검증...');
    final vm = harness.controller?.vm;
    if (vm == null) {
      failureReason = 'GameController가 null입니다.';
      throw StateError(failureReason);
    }
    
    if (vm.combat == null) {
      failureReason = '전투 상태(combat)가 null입니다.';
      throw StateError(failureReason);
    }
    
    if (!vm.combat!.isActive) {
      failureReason = '전투 상태가 활성화되지 않았습니다.';
      throw StateError(failureReason);
    }
    
    print('✅ 전투 상태 검증 완료');
    print('   - Phase: ${vm.phase}');
    print('   - Combat Active: ${vm.combat!.isActive}');
    print('   - Elapsed: ${vm.combat!.elapsedSeconds}s');
    
    // 초기 HP 저장
    final initialPlayerHp = vm.combat!.player?.currentHealth ?? 0;
    final initialEnemyHp = vm.combat!.enemy?.currentHealth ?? 0;
    
    print('\n[초기 상태]');
    print('   - Player HP: $initialPlayerHp/${vm.combat!.player?.maxHealth ?? 0}');
    print('   - Enemy HP: $initialEnemyHp/${vm.combat!.enemy?.maxHealth ?? 0}');
    
    // Step 4: 100ms 단위로 tick()을 100번 호출 (총 10초 진행)
    print('\n[Step 4] 시간 진행 (100ms × 100회 = 10초)...');
    const int tickCount = 100;
    const int tickMs = 100;
    
    for (int i = 0; i < tickCount; i++) {
      await harness.tick(tickMs);
      
      // 1초마다 진행 상황 출력
      if ((i + 1) % 10 == 0) {
        final currentVm = harness.controller?.vm;
        if (currentVm?.combat != null) {
          final playerHp = currentVm!.combat!.player?.currentHealth ?? 0;
          final enemyHp = currentVm.combat!.enemy?.currentHealth ?? 0;
          final elapsed = currentVm.combat!.elapsedSeconds;
          print('   [${(i + 1) * tickMs / 1000.0}s] Player: $playerHp, Enemy: $enemyHp');
        }
      }
    }
    
    print('✅ 시간 진행 완료');
    
    // Step 5: 10초 후 플레이어나 적의 HP가 감소했는지 확인
    print('\n[Step 5] HP 변화 검증...');
    final finalVm = harness.controller?.vm;
    if (finalVm == null || finalVm.combat == null) {
      failureReason = '전투 상태가 사라졌습니다.';
      throw StateError(failureReason);
    }
    
    final finalPlayerHp = finalVm.combat!.player?.currentHealth ?? 0;
    final finalEnemyHp = finalVm.combat!.enemy?.currentHealth ?? 0;
    
    print('\n[최종 상태]');
    print('   - Player HP: $finalPlayerHp/${finalVm.combat!.player?.maxHealth ?? 0}');
    print('   - Enemy HP: $finalEnemyHp/${finalVm.combat!.enemy?.maxHealth ?? 0}');
    print('   - Elapsed: ${finalVm.combat!.elapsedSeconds}s');
    
    // HP 감소 검증
    final playerHpDecreased = finalPlayerHp < initialPlayerHp;
    final enemyHpDecreased = finalEnemyHp < initialEnemyHp;
    
    if (!playerHpDecreased && !enemyHpDecreased) {
      failureReason = '10초 후에도 플레이어나 적의 HP가 감소하지 않았습니다.';
      failureReason += '\n   - 초기 Player HP: $initialPlayerHp';
      failureReason += '\n   - 최종 Player HP: $finalPlayerHp';
      failureReason += '\n   - 초기 Enemy HP: $initialEnemyHp';
      failureReason += '\n   - 최종 Enemy HP: $finalEnemyHp';
      throw StateError(failureReason);
    }
    
    print('✅ HP 변화 검증 완료');
    if (playerHpDecreased) {
      print('   - Player HP 감소: ${initialPlayerHp} → $finalPlayerHp (${initialPlayerHp - finalPlayerHp} 감소)');
    }
    if (enemyHpDecreased) {
      print('   - Enemy HP 감소: ${initialEnemyHp} → $finalEnemyHp (${initialEnemyHp - finalEnemyHp} 감소)');
    }
    
    // 테스트 성공
    testPassed = true;
    print('\n' + '=' * 60);
    print('✅ 테스트 성공!');
    print('=' * 60);
    
  } catch (e, stackTrace) {
    testPassed = false;
    failureReason = failureReason ?? e.toString();
    
    print('\n' + '=' * 60);
    print('❌ 테스트 실패!');
    print('=' * 60);
    print('\n실패 이유:');
    print(failureReason);
    print('\n예외 정보:');
    print(e);
    print('\n스택 트레이스:');
    print(stackTrace);
    
    // 실패 시 dumpState() 내용 출력
    print('\n' + '-' * 60);
    print('현재 게임 상태 덤프:');
    print('-' * 60);
    try {
      final stateDump = harness.dumpState();
      print(stateDump);
    } catch (dumpError) {
      print('상태 덤프 실패: $dumpError');
    }
    
  } finally {
    // 리소스 정리
    harness.dispose();
  }
  
  // Exit code 설정 (성공: 0, 실패: 1)
  exit(testPassed ? 0 : 1);
}

