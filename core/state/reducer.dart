import 'app_phase.dart';
import 'game_state.dart';
import 'events.dart';
import 'combat_state.dart';
import '../infra/phase_gate.dart';

GameVM reduce(GameVM s, GEvent e) {
  GameVM next = s;

  if (e is ErrorEvt) {
    next = GameVM(phase: AppPhase.error, error: e.msg, player: s.player);
  } else if (e is Booted) {
    next = s.copyWith(phase: AppPhase.startMenu);
  } else if (e is StartGame) {
    // 🎮 게임 시작시 RunState 완전 초기화
    // MetaProfile은 MetaProfileModule에서 관리되므로 여기서는 초기화 안 함
    next = const GameVM(
      phase: AppPhase.inGame_characterCreation,
      loading: true,
      error: null,
      text: null,
      choices: [],
      player: null,
      combat: null,
      playerInventory: null,
      victoryScenePath: null,
      defeatScenePath: null,
      debug: null,
    );
  } else if (e is CharacterCreated) {
    // 🎮 캐릭터 생성 완료시 플레이어 정보와 함께 인카운터 단계로 전환
    next = s.copyWith(
      phase: AppPhase.inGame_encounter, 
      loading: false, 
      error: null,
      player: e.player,  // 생성된 플레이어 정보 저장
    );
  } else if (e is EncounterLoaded) {
    // 인카운터가 로드되면 승리/패배 경로 초기화
    next = s.copyWith(
      text: e.text, 
      choices: const [], // ✅ 인카운터 텍스트 갱신 시 이전 선택지 제거
      loading: false, 
      error: null,
      victoryScenePath: null,
      defeatScenePath: null,
    );
  } else if (e is EncounterViewUpdated) {
    // 인카운터 화면(텍스트/선택지) 업데이트
    // - e.text가 null이면 기존 텍스트 유지 (copyWith의 ?? 처리)
    next = s.copyWith(
      text: e.text,
      choices: e.choices,
      loading: false,
      error: null,
      victoryScenePath: null,
      defeatScenePath: null,
    );
  } else if (e is EnterReward) {
    // 💰 보상 획득 (회복 포함 가능)
    final payload = e.payload as Map<String, dynamic>?;
    final vitalityRestore = payload?['vitalityRestore'] as int? ?? 0;
    final sanityRestore = payload?['sanityRestore'] as int? ?? 0;
    
    // 🆕 보상 화면으로 phase 전환
    if (s.player != null && (vitalityRestore > 0 || sanityRestore > 0)) {
      // 회복 보상이 있으면 적용
      final newVitality = (s.player!.vitality + vitalityRestore).clamp(0, s.player!.maxVitality);
      final newSanity = (s.player!.sanity + sanityRestore).clamp(0, s.player!.maxSanity);
      
      final healedPlayer = s.player!.copyWith(
        vitality: newVitality,
        sanity: newSanity,
      );
      
      next = s.copyWith(
        phase: AppPhase.inGame_reward,
        player: healedPlayer,
        combat: null,  // 전투 상태 클리어
      );
    } else {
      // 회복 보상 없어도 보상 화면으로 전환
      next = s.copyWith(
        phase: AppPhase.inGame_reward,
        combat: null,  // 전투 상태 클리어
      );
    }
  } else if (e is EnterCombat) {
    // ⚔️ 전투 시작 - phase 전환 (실제 상태는 CombatStateUpdated에서 처리)
    next = s.copyWith(phase: AppPhase.inGame_combat, loading: false, error: null);
  } else if (e is CombatStateUpdated) {
    // ⚔️ 전투 상태 업데이트
    final combatState = e.combatState as CombatState;
    next = s.copyWith(combat: combatState);
  } else if (e is HealReward) {
    // 💊 회복 보상 처리
    if (s.player == null) {
      return s; // 플레이어 없으면 변경 없음
    }
    
    // 회복량 적용 (최대치를 초과하지 않도록 clamp)
    final newVitality = (s.player!.vitality + e.vitalityRestore).clamp(0, s.player!.maxVitality);
    final newSanity = (s.player!.sanity + e.sanityRestore).clamp(0, s.player!.maxSanity);
    
    final healedPlayer = s.player!.copyWith(
      vitality: newVitality,
      sanity: newSanity,
    );
    
    next = s.copyWith(player: healedPlayer);
  } else if (e is RestartNewGame) {
    // 🔄 게임오버에서 새 게임 시작
    // StartGame과 동일하게 캐릭터 생성 단계로 전환
    next = s.copyWith(
      phase: AppPhase.inGame_characterCreation,
      loading: true,
      error: null,
      player: null,  // 기존 플레이어 제거
      combat: null,
    );
  } else if (e is RestartFromSave) {
    // 🔄 게임오버에서 저장된 게임 불러오기
    // 실제 로드는 UI 레이어나 별도 모듈에서 처리
    // reducer에서는 로딩 상태로만 전환
    next = s.copyWith(
      loading: true,
      error: null,
    );
  } else if (e is CombatResult) {
    // ⚔️ 전투 종료 - 승리시 보상, 패배시 생명력 패널티
    final result = e.result as Map<String, dynamic>?;
    final won = result?['won'] as bool? ?? false;
    
    if (won) {
      // 승리 → 보상 화면으로 전환하고 승리 경로 저장
      next = s.copyWith(
        phase: AppPhase.inGame_reward,
        combat: null,
        victoryScenePath: e.victoryScenePath,  // 승리 경로 저장
      );
    } else {
      // 패배 처리
      if (s.player == null) {
        // 플레이어 정보 없으면 에러
        next = s.copyWith(error: 'Player data missing during combat result');
      } else {
        // 즉사/광기 체크
        final instantDeath = result?['instantDeath'] as bool? ?? false;
        final instantMadness = result?['instantMadness'] as bool? ?? false;
        
        if (instantDeath || instantMadness) {
          // 즉사 → 생명력 0, 광기 → 정신력 0
          final deadPlayer = s.player!.copyWith(
            vitality: instantDeath ? 0 : s.player!.vitality,
            sanity: instantMadness ? 0 : s.player!.sanity,
          );
          next = s.copyWith(
            phase: AppPhase.inGame_gameOver,
            combat: null,
            player: deadPlayer,
          );
        } else {
          // 일반 패배 → 생명력/정신력 패널티 적용
          final vitalityPenalty = result?['vitalityPenalty'] as int? ?? 1; // 기본 -1
          final sanityPenalty = result?['sanityPenalty'] as int? ?? 0;     // 기본 0
          
          final newVitality = (s.player!.vitality - vitalityPenalty).clamp(0, s.player!.maxVitality);
          final newSanity = (s.player!.sanity - sanityPenalty).clamp(0, s.player!.maxSanity);
          
          final updatedPlayer = s.player!.copyWith(
            vitality: newVitality,
            sanity: newSanity,
          );
          
          if (updatedPlayer.isGameOver) {
            // 생명력 또는 정신력 0 → 게임 오버
            next = s.copyWith(
              phase: AppPhase.inGame_gameOver,
              combat: null,
              player: updatedPlayer,
            );
          } else {
            // 둘 다 남음 → 패배 인카운터로 이동 (경로가 있으면)
            next = s.copyWith(
              phase: AppPhase.inGame_encounter,
              combat: null,
              player: updatedPlayer,
              defeatScenePath: e.defeatScenePath,  // 패배 경로 저장
              victoryScenePath: null,  // 승리 경로는 초기화
            );
          }
        }
      }
    }
  } else {
    return s; // unknown event → no change
  }

  // 같은 상태로의 전환이거나 허용된 전환인 경우만 통과
  if (s.phase == next.phase || canTransition(s.phase, next.phase)) {
    return next;
  } else {
    return s.copyWith(error: 'Invalid phase transition: ${s.phase} -> ${next.phase}');
  }
}
