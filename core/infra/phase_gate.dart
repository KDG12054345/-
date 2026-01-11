import '../state/app_phase.dart';

// 허용되는 단계 전환 맵
final Map<AppPhase, Set<AppPhase>> kAllowed = {
  AppPhase.startMenu: {
    AppPhase.inGame_characterCreation,  // 게임 시작 → 캐릭터 생성
    AppPhase.error
  },
  AppPhase.inGame_characterCreation: {  // 새로 추가된 캐릭터 생성 단계
    AppPhase.inGame_encounter,          // 캐릭터 생성 완료 → 인카운터
    AppPhase.error,
  },
  AppPhase.inGame_encounter: {
    AppPhase.inGame_combat,
    AppPhase.inGame_reward,
    AppPhase.inGame_gameOver,    // 이벤트로 인한 즉시 사망
    AppPhase.startMenu,
    AppPhase.error,
  },
  AppPhase.inGame_combat: {
    AppPhase.inGame_reward,      // 승리
    AppPhase.inGame_encounter,   // 패배 후 복귀
    AppPhase.inGame_gameOver,    // 생명력 0
    AppPhase.error
  },
  AppPhase.inGame_reward: {
    AppPhase.inGame_encounter,
    AppPhase.startMenu,
    AppPhase.error,
  },
  AppPhase.inGame_gameOver: {
    AppPhase.startMenu,              // 타이틀로 (미래 확장용)
    AppPhase.inGame_characterCreation,  // 새 게임 시작
    AppPhase.inGame_encounter,       // 저장에서 다시 시작
    AppPhase.error,
  },
  AppPhase.boot: {
    AppPhase.startMenu, 
    AppPhase.error
  },
  AppPhase.error: {
    AppPhase.startMenu
  },
};

bool canTransition(AppPhase from, AppPhase to) =>
    (kAllowed[from] ?? const {}).contains(to);
