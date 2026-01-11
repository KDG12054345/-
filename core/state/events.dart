import 'dart:async';
import '../character/character_models.dart';
import '../infra/command_queue.dart';  // CmdQueue import 추가
import 'game_state.dart';

abstract class GEvent { 
  const GEvent(); 
  @override
  String toString() => runtimeType.toString();
}

// ========== Event Tier System ==========

/// 이벤트 계층 분류
/// - user: 사용자 입력 이벤트 (traceId 생성)
/// - system: 시스템 이벤트 (traceId 상속)
/// - internal: 내부 이벤트 (큐 삽입 금지, 로그/타임라인 제외)
enum EventTier { user, system, internal }

/// GEvent에 tier 속성 추가
extension GEventTier on GEvent {
  EventTier get tier {
    // UserEvent: 사용자 입력
    if (this is StartGame || this is Next || this is Choose) {
      return EventTier.user;
    }
    // InternalEvent: 고빈도 내부 이벤트 (큐 삽입 금지)
    if (this is CombatStateUpdated) {
      return EventTier.internal;
    }
    // SystemEvent: 기본값
    return EventTier.system;
  }
  
  bool get isUserEvent => tier == EventTier.user;
  bool get isSystemEvent => tier == EventTier.system;
  bool get isInternalEvent => tier == EventTier.internal;
}

class Booted extends GEvent { 
  const Booted(); 
  @override
  String toString() => 'Booted()';
}

class StartGame extends GEvent { 
  const StartGame(); 
  @override
  String toString() => 'StartGame()';
}

class Next extends GEvent { 
  const Next(); 
  @override
  String toString() => 'Next()';
}

class Choose extends GEvent { 
  final String id; 
  const Choose(this.id); 
  @override
  String toString() => 'Choose($id)';
}

class EnterCombat extends GEvent { 
  final Object? payload;
  final String? victoryScenePath;  // 승리 후 이동할 인카운터 경로
  final String? defeatScenePath;   // 패배 후 이동할 인카운터 경로
  
  const EnterCombat([
    this.payload,
    this.victoryScenePath,
    this.defeatScenePath,
  ]); 
  
  @override
  String toString() => 'EnterCombat($payload, victory: $victoryScenePath, defeat: $defeatScenePath)';
}

class CombatResult extends GEvent { 
  final Object? result;
  final String? victoryScenePath;  // 승리 후 이동할 인카운터 경로
  final String? defeatScenePath;   // 패배 후 이동할 인카운터 경로
  
  const CombatResult([
    this.result,
    this.victoryScenePath,
    this.defeatScenePath,
  ]); 
  
  @override
  String toString() => 'CombatResult($result)';
}

class EnterReward extends GEvent { 
  final Object? payload; 
  const EnterReward([this.payload]); 
  @override
  String toString() => 'EnterReward($payload)';
}

class ErrorEvt extends GEvent { 
  final String msg; 
  const ErrorEvt(this.msg); 
  @override
  String toString() => 'ErrorEvt($msg)';
}

/// EncounterController가 만든 한 줄 텍스트를 UI로 전달
class EncounterLoaded extends GEvent {
  final String text;
  const EncounterLoaded(this.text);
  @override
  String toString() => 'EncounterLoaded(text: $text)';
}

/// 인카운터 화면 업데이트 (텍스트 + 선택지)
/// - DialogueEngine 기반 인카운터에서 선택지를 UI로 전달하기 위해 사용
class EncounterViewUpdated extends GEvent {
  final String? text;
  final List<ChoiceVM> choices;
  const EncounterViewUpdated({
    this.text,
    this.choices = const [],
  });

  @override
  String toString() => 'EncounterViewUpdated(text: ${text ?? ""}, choices: ${choices.length})';
}

/// 특정 인카운터 로드 요청 (파일 경로 + 씬 ID)
class LoadEncounter extends GEvent {
  final String encounterPath;  // 인카운터 파일 경로
  final String? sceneId;       // 시작할 씬 ID (null이면 start 씬)
  
  const LoadEncounter(this.encounterPath, [this.sceneId]);
  
  @override
  String toString() => 'LoadEncounter($encounterPath${sceneId != null ? ", scene: $sceneId" : ""})';
}

/// 캐릭터 생성 완료 이벤트
class CharacterCreated extends GEvent {
  final Player player;
  
  const CharacterCreated(this.player);
  
  @override
  String toString() => 'CharacterCreated(${player.traits.length} traits)';
}

// ========== XP Milestone System Events ==========

/// 인카운터 종료 이벤트 (XP 정산 트리거)
class EncounterEnded extends GEvent {
  final String encounterId;
  final Map<String, dynamic> outcome;
  
  const EncounterEnded(this.encounterId, this.outcome);
  
  @override
  String toString() => 'EncounterEnded($encounterId, outcome: $outcome)';
}

/// 다음 인카운터 슬롯 열림 (스케줄러 트리거)
class SlotOpened extends GEvent {
  const SlotOpened();
  
  @override
  String toString() => 'SlotOpened()';
}

/// 마일스톤 도달 이벤트 (디버깅/로깅용)
class MilestoneReached extends GEvent {
  final int milestone;
  final String type; // 'theme' or 'story'
  
  const MilestoneReached(this.milestone, this.type);
  
  @override
  String toString() => 'MilestoneReached($milestone, type: $type)';
}

/// 엔딩 표시 요청 이벤트
class ShowEnding extends GEvent {
  final String endingId;
  final Map<String, dynamic> context;
  
  const ShowEnding(this.endingId, this.context);
  
  @override
  String toString() => 'ShowEnding($endingId)';
}

/// 챕터 랩(wrap) 완료 이벤트
class ChapterWrapped extends GEvent {
  final int chapter;
  final bool wasReset;
  
  const ChapterWrapped(this.chapter, this.wasReset);
  
  @override
  String toString() => 'ChapterWrapped(chapter: $chapter, reset: $wasReset)';
}

/// 전투 상태 업데이트 이벤트 (내부용)
class CombatStateUpdated extends GEvent {
  final dynamic combatState; // CombatState 타입 (순환 import 방지)
  
  const CombatStateUpdated(this.combatState);
  
  @override
  String toString() => 'CombatStateUpdated($combatState)';
}

/// 회복 보상 이벤트 (생명력/정신력 회복)
class HealReward extends GEvent {
  final int vitalityRestore;
  final int sanityRestore;
  
  const HealReward({
    this.vitalityRestore = 0,
    this.sanityRestore = 0,
  });
  
  @override
  String toString() => 'HealReward(vitality: +$vitalityRestore, sanity: +$sanityRestore)';
}

// ========== Game Over & Restart Events ==========

/// 게임오버 화면에서 새 게임 시작 이벤트
/// 
/// - 새로운 캐릭터 생성
/// - 인벤토리 초기화
/// - 모든 시스템 리셋
class RestartNewGame extends GEvent {
  const RestartNewGame();
  
  @override
  String toString() => 'RestartNewGame()';
}

/// 게임오버 화면에서 저장된 게임 불러오기 이벤트
/// 
/// - DialogueManager를 통해 저장 데이터 로드
/// - Player 정보 복원
/// - 인벤토리 복원
/// - CharacterCreated 이벤트를 통해 모든 모듈 동기화
class RestartFromSave extends GEvent {
  const RestartFromSave();
  
  @override
  String toString() => 'RestartFromSave()';
}

// ========== Meta Profile Events ==========

/// 메타 플래그 언락 이벤트
/// 
/// 인카운터 결과로 메타 진행도를 업데이트할 때 사용합니다.
/// 이 플래그는 다음 회차에서 새로운 인카운터를 언락하는 데 사용됩니다.
class UnlockMetaFlag extends GEvent {
  final String flag;
  
  const UnlockMetaFlag(this.flag);
  
  @override
  String toString() => 'UnlockMetaFlag($flag)';
}
