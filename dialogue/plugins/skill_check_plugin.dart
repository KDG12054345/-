/// 스킬 체크 플러그인
/// 
/// 선택지에 스킬 체크 확률을 표시하고 판정을 수행합니다.

import 'package:flutter/foundation.dart';
import '../core/dialogue_data.dart';
import '../../core/skill_check/skill_check_calculator.dart';
import '../../core/skill_check/skill_check_models.dart';
import '../../core/character/character_models.dart';
import 'dialogue_plugin.dart';

/// 스킬 체크 플러그인
class SkillCheckPlugin extends SimpleDialoguePlugin {
  final SkillCheckCalculator calculator;
  Player? _currentPlayer;

  /// 스킬 체크 결과 로그
  final List<SkillCheckResult> _results = [];

  SkillCheckPlugin({
    SkillCheckCalculator? calculator,
  })  : calculator = calculator ?? SkillCheckCalculator(),
        super(
          id: 'skill_check',
          name: 'Skill Check Plugin',
          priority: 50, // 선택지 표시 전 우선 실행
        );

  /// 현재 플레이어 설정
  void setPlayer(Player? player) {
    _currentPlayer = player;
    if (enableLogging) {
      debugPrint('[SkillCheckPlugin] Player set: ${player != null ? "Player" : "null"}');
    }
  }

  /// 현재 플레이어 가져오기
  Player? get currentPlayer => _currentPlayer;

  /// 스킬 체크 결과 기록
  List<SkillCheckResult> get results => List.unmodifiable(_results);

  /// 로깅 활성화
  bool enableLogging = kDebugMode;

  @override
  Future<List<DialogueChoice>> beforeChoicesPresent(
    DialoguePluginContext context,
    List<DialogueChoice> choices,
  ) async {
    if (_currentPlayer == null) {
      // 플레이어 없으면 그대로 반환
      return choices;
    }

    // 각 선택지에 스킬 체크 정보 추가
    final enhancedChoices = <DialogueChoice>[];

    for (final choice in choices) {
      final skillCheck = _extractSkillCheckConfig(choice);

      if (skillCheck != null) {
        // 스킬 체크가 있는 선택지
        final displayChance = calculator.getDisplayChanceFromPlayer(
          skillCheck,
          _currentPlayer!,
        );

        // metadata에 스킬 체크 정보 추가
        final newMetadata = Map<String, dynamic>.from(choice.metadata ?? {});
        newMetadata['skill_check'] = {
          'stat': skillCheck.stat,
          'visibility': skillCheck.visibility.toString(),
          'display_chance': displayChance,
        };

        // 선택지 텍스트에 확률 추가
        String enhancedText = choice.text;
        if (displayChance != null && displayChance.isNotEmpty) {
          enhancedText = '${choice.text} [$displayChance]';
        }

        enhancedChoices.add(DialogueChoice(
          id: choice.id,
          text: enhancedText,
          nextScene: choice.nextScene,
          nextNode: choice.nextNode,
          jump: choice.jump,
          effects: choice.effects,
          conditions: choice.conditions,
          enabled: choice.enabled,
          disabledReason: choice.disabledReason,
          isBranchPoint: choice.isBranchPoint,
          metadata: newMetadata,
        ));
      } else {
        // 스킬 체크 없는 선택지는 그대로
        enhancedChoices.add(choice);
      }
    }

    return enhancedChoices;
  }

  @override
  Future<void> onChoiceSelected(
    DialoguePluginContext context,
    DialogueChoice choice,
  ) async {
    if (_currentPlayer == null) return;

    final skillCheck = _extractSkillCheckConfig(choice);
    if (skillCheck == null) return;

    // 스킬 체크 판정
    final isSuccess = calculator.rollForSuccessFromPlayer(
      skillCheck,
      _currentPlayer!,
    );

    // 스탯 값 가져오기
    final statValue = _getPlayerStatValue(_currentPlayer!, skillCheck.stat);

    // 결과 기록
    final result = SkillCheckResult(
      choiceId: choice.id,
      choiceText: choice.text,
      stat: skillCheck.stat,
      playerStatValue: statValue,
      isSuccess: isSuccess,
      timestamp: DateTime.now(),
    );

    _results.add(result);

    // 텔레메트리 로그
    if (enableLogging) {
      final log = calculator.createTelemetryLogFromPlayer(
        choiceId: choice.id,
        config: skillCheck,
        player: _currentPlayer!,
        outcome: isSuccess,
      );
      debugPrint('[SkillCheckPlugin] $log');
    }

    // 성공/실패 로그
    if (isSuccess) {
      debugPrint('[SkillCheckPlugin] ✅ Success: ${choice.text} (${skillCheck.stat})');
    } else {
      debugPrint('[SkillCheckPlugin] ❌ Failure: ${choice.text} (${skillCheck.stat})');
    }

    // TODO: 성공/실패에 따른 후속 처리 (효과 추가 등)
    // 이 부분은 게임 로직에 따라 커스텀 가능
  }

  /// 선택지에서 스킬 체크 설정 추출
  SkillCheckConfig? _extractSkillCheckConfig(DialogueChoice choice) {
    // metadata에서 추출
    if (choice.metadata != null && choice.metadata!.containsKey('skill_check')) {
      final data = choice.metadata!['skill_check'];
      if (data is Map) {
        final stat = data['stat'] as String?;
        final visibilityStr = data['visibility'] as String?;

        if (stat != null) {
          final visibility = _parseVisibility(visibilityStr);
          return SkillCheckConfig(
            stat: stat,
            visibility: visibility,
          );
        }
      }
    }

    // 텍스트 패턴에서 추론 (fallback)
    return _inferSkillCheckFromText(choice.text);
  }

  /// 텍스트에서 스킬 체크 추론
  SkillCheckConfig? _inferSkillCheckFromText(String text) {
    final lowerText = text.toLowerCase();

    // 패턴 매칭
    if (lowerText.contains('힘') || lowerText.contains('밀어') || lowerText.contains('위협')) {
      return const SkillCheckConfig(
        stat: 'strength',
        visibility: SkillCheckVisibility.estimate,
      );
    } else if (lowerText.contains('설득') || lowerText.contains('대화') || lowerText.contains('말')) {
      return const SkillCheckConfig(
        stat: 'charisma',
        visibility: SkillCheckVisibility.exact,
      );
    } else if (lowerText.contains('도망') || lowerText.contains('빠르게') || lowerText.contains('피하')) {
      return const SkillCheckConfig(
        stat: 'agility',
        visibility: SkillCheckVisibility.estimate,
      );
    } else if (lowerText.contains('분석') || lowerText.contains('생각') || lowerText.contains('판단')) {
      return const SkillCheckConfig(
        stat: 'intelligence',
        visibility: SkillCheckVisibility.exact,
      );
    }

    return null;
  }

  /// 가시성 문자열 파싱
  SkillCheckVisibility _parseVisibility(String? str) {
    if (str == null) return SkillCheckVisibility.estimate;

    switch (str.toLowerCase()) {
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

  /// 통계 조회
  Map<String, dynamic> getStatistics() {
    final totalChecks = _results.length;
    final successCount = _results.where((r) => r.isSuccess).length;
    final failureCount = totalChecks - successCount;

    final statBreakdown = <String, Map<String, int>>{};
    for (final result in _results) {
      statBreakdown[result.stat] ??= {'total': 0, 'success': 0, 'failure': 0};
      statBreakdown[result.stat]!['total'] = statBreakdown[result.stat]!['total']! + 1;
      if (result.isSuccess) {
        statBreakdown[result.stat]!['success'] = statBreakdown[result.stat]!['success']! + 1;
      } else {
        statBreakdown[result.stat]!['failure'] = statBreakdown[result.stat]!['failure']! + 1;
      }
    }

    return {
      'totalChecks': totalChecks,
      'successCount': successCount,
      'failureCount': failureCount,
      'successRate': totalChecks > 0 ? successCount / totalChecks : 0.0,
      'statBreakdown': statBreakdown,
    };
  }

  /// 로그 클리어
  void clearResults() {
    _results.clear();
  }

  /// 플레이어의 스탯 값 가져오기
  int _getPlayerStatValue(Player player, String stat) {
    switch (stat.toLowerCase()) {
      case 'strength':
        return player.strength;
      case 'agility':
        return player.agility;
      case 'intelligence':
        return player.intelligence;
      case 'charisma':
        return player.charisma;
      default:
        return 0;
    }
  }
}

/// 스킬 체크 결과
class SkillCheckResult {
  final String choiceId;
  final String choiceText;
  final String stat;
  final int playerStatValue;
  final bool isSuccess;
  final DateTime timestamp;

  const SkillCheckResult({
    required this.choiceId,
    required this.choiceText,
    required this.stat,
    required this.playerStatValue,
    required this.isSuccess,
    required this.timestamp,
  });

  @override
  String toString() {
    final result = isSuccess ? 'SUCCESS' : 'FAILURE';
    return 'SkillCheckResult($result: $choiceText, $stat=$playerStatValue)';
  }
}

