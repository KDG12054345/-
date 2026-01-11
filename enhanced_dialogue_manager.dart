import 'dialogue_manager.dart';
import 'core/skill_check/skill_check_calculator.dart';
import 'core/skill_check/skill_check_models.dart';
import 'core/character/character_models.dart';

/// 확장된 선택지 클래스 (Choice를 상속)
class EnhancedChoice extends Choice {
  final String? displayChance;
  final SkillCheckConfig? skillCheck;

  const EnhancedChoice({
    required super.id,
    required super.text,
    required super.isEnabled,
    super.conditions,
    super.metadata,
    this.displayChance,
    this.skillCheck,
  });
}

class EnhancedDialogueManager extends DialogueManager {
  final SkillCheckCalculator _skillCheckCalculator;
  Player? _currentPlayer; // 현재 플레이어 정보 캐시

  EnhancedDialogueManager({
    super.eventSystem,
    super.branchSystem,
    super.saveSystem,
    SkillCheckCalculator? skillCheckCalculator,
  }) : _skillCheckCalculator = skillCheckCalculator ?? SkillCheckCalculator();

  /// 현재 플레이어 설정
  void setCurrentPlayer(Player? player) {
    _currentPlayer = player;
  }

  /// 현재 플레이어 가져오기
  Player? getCurrentPlayer() {
    return _currentPlayer;
  }

  /// 현재 노드 접근 (DialogueManager의 private 메서드 재구현)
  Map<String, dynamic>? getCurrentNode() {
    // DialogueManager가 공식 확장 포인트(getCurrentSceneRaw)를 제공하므로,
    // 우회/추정 로직(텍스트/상태 추정)을 사용하지 않습니다.
    return super.getCurrentSceneRaw();
  }

  @override
  List<Choice> getChoices() {
    // 기존 선택지 가져오기
    final baseChoices = super.getChoices();
    
    // 현재 플레이어가 없으면 기존 선택지 그대로 반환
    final player = getCurrentPlayer();
    if (player == null) {
      return baseChoices;
    }
    
    // 스킬 체크 확률 정보 추가
    return baseChoices.map((choice) => _enhanceChoiceWithSkillCheck(choice, player)).toList();
  }

  Choice _enhanceChoiceWithSkillCheck(Choice baseChoice, Player player) {
    // ✅ 텍스트 기반 추정 금지: metadata(또는 원본 choice raw 데이터)만 사용
    final skillCheck = _extractSkillCheckFromMetadata(baseChoice.metadata);
    
    if (skillCheck != null) {
      final displayChance = _skillCheckCalculator.getDisplayChanceFromPlayer(skillCheck, player);
      
      return EnhancedChoice(
        id: baseChoice.id,
        text: baseChoice.text,
        isEnabled: baseChoice.isEnabled,
        conditions: baseChoice.conditions,
        metadata: baseChoice.metadata,
        displayChance: displayChance,
        skillCheck: skillCheck,
      );
    }
    
    return baseChoice;
  }

  SkillCheckConfig? _extractSkillCheckFromMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) return null;
    final raw = metadata['skill_check'];
    if (raw is! Map) return null;

    final stat = raw['stat'];
    if (stat is! String || stat.isEmpty) return null;

    final visibilityRaw = raw['visibility'];
    final visibility = _parseVisibility(visibilityRaw);

    return SkillCheckConfig(
      stat: stat,
      visibility: visibility,
    );
  }

  SkillCheckVisibility _parseVisibility(dynamic raw) {
    if (raw == null) return SkillCheckVisibility.estimate;
    final str = raw.toString().toLowerCase();
    switch (str) {
      case 'exact':
      case 'skillicheckvisibility.exact':
        return SkillCheckVisibility.exact;
      case 'estimate':
      case 'skillicheckvisibility.estimate':
        return SkillCheckVisibility.estimate;
      case 'hidden':
      case 'skillicheckvisibility.hidden':
        return SkillCheckVisibility.hidden;
      default:
        return SkillCheckVisibility.estimate;
    }
  }

  /// 스킬 체크를 포함한 선택지 처리
  void handleChoiceWithSkillCheck(String choiceId) {
    final choices = getChoices();
    final selectedChoice = choices.firstWhere(
      (choice) => choice.id == choiceId,
      orElse: () => choices.first,
    );

    if (selectedChoice is EnhancedChoice && 
        selectedChoice.skillCheck != null && 
        _currentPlayer != null) {
      
      // 스킬 체크 판정
      final isSuccess = _skillCheckCalculator.rollForSuccessFromPlayer(
        selectedChoice.skillCheck!, 
        _currentPlayer!,
      );

      // 텔레메트리 로그
      final telemetryLog = _skillCheckCalculator.createTelemetryLogFromPlayer(
        choiceId: choiceId,
        config: selectedChoice.skillCheck!,
        player: _currentPlayer!,
        outcome: isSuccess,
      );
      print('[SkillCheck] $telemetryLog');

      // 성공/실패에 따른 처리 (임시로 콘솔 출력)
      if (isSuccess) {
        print('🎉 스킬 체크 성공! (${selectedChoice.skillCheck!.stat})');
      } else {
        print('💥 스킬 체크 실패! (${selectedChoice.skillCheck!.stat})');
      }
    }

    // 기존 선택지 처리 로직 호출
    super.handleChoice(choiceId);
  }
}
