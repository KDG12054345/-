/// 인카운터 스케줄러
/// 
/// 마일스톤 큐를 기반으로 다음 인카운터를 결정합니다.
/// - 큐에 마일스톤이 있으면: 테마/스토리 인카운터
/// - 큐가 비었으면: 반복 랜덤 인카운터
/// - 터미널(100) 처리 중에는 다른 인카운터 차단

import 'dart:math';
import 'package:flutter/foundation.dart';
import '../milestone/milestone_service.dart';
import '../xp/xp_service.dart';
import '../../services/dialogue_index.dart';

/// 인카운터 선택 결과
class EncounterSelection {
  final String path;
  final String type; // 'theme', 'story', 'repeat'
  final int? milestone; // 테마/스토리의 경우
  final String source; // 디버깅용

  const EncounterSelection({
    required this.path,
    required this.type,
    this.milestone,
    required this.source,
  });

  @override
  String toString() =>
      'EncounterSelection($type${milestone != null ? ' M$milestone' : ''}: $path from $source)';
}

/// 테마 인카운터 설정
class ThemeTrackConfig {
  final Map<String, List<String>> poolByStart; // startThemeKey -> 인카운터 목록
  final String selection; // 'weighted_random', 'sequential' 등

  const ThemeTrackConfig({
    required this.poolByStart,
    this.selection = 'weighted_random',
  });

  factory ThemeTrackConfig.fromJson(Map<String, dynamic> json) {
    final poolData = json['poolByStart'] as Map<String, dynamic>? ?? {};
    final poolByStart = <String, List<String>>{};
    
    poolData.forEach((key, value) {
      if (value is List) {
        poolByStart[key] = value.map((e) => e.toString()).toList();
      }
    });

    return ThemeTrackConfig(
      poolByStart: poolByStart,
      selection: json['selection'] as String? ?? 'weighted_random',
    );
  }
}

/// 스토리 인카운터 설정
class StoryTrackConfig {
  final List<String> sequence; // 순서대로 실행할 인카운터
  final String onMiss; // 'enqueue_next', 'skip' 등

  const StoryTrackConfig({
    required this.sequence,
    this.onMiss = 'enqueue_next',
  });

  factory StoryTrackConfig.fromJson(Map<String, dynamic> json) {
    return StoryTrackConfig(
      sequence: (json['sequence'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      onMiss: json['onMiss'] as String? ?? 'enqueue_next',
    );
  }
}

/// 인카운터 스케줄러 - 싱글톤
class EncounterScheduler {
  static EncounterScheduler? _instance;
  static EncounterScheduler get instance => _instance ??= EncounterScheduler._();

  EncounterScheduler._();

  final MilestoneService _milestoneService = MilestoneService.instance;
  final XpService _xpService = XpService.instance;
  final DialogueIndex _dialogueIndex = DialogueIndex.instance;

  /// 테마/스토리 트랙 설정
  ThemeTrackConfig _themeConfig = const ThemeTrackConfig(poolByStart: {});
  StoryTrackConfig _storyConfig = const StoryTrackConfig(sequence: []);

  /// 현재 시작 테마 키
  String _startThemeKey = 'default';

  /// 설정 로드
  void loadConfig({
    ThemeTrackConfig? themeConfig,
    StoryTrackConfig? storyConfig,
    String? startThemeKey,
  }) {
    if (themeConfig != null) _themeConfig = themeConfig;
    if (storyConfig != null) _storyConfig = storyConfig;
    if (startThemeKey != null) _startThemeKey = startThemeKey;

    if (kDebugMode) {
      debugPrint('[EncounterScheduler] Config loaded: startTheme=$_startThemeKey');
    }
  }

  /// 시작 테마 키 설정
  void setStartThemeKey(String key) {
    _startThemeKey = key;
    if (kDebugMode) {
      debugPrint('[EncounterScheduler] Start theme key: $key');
    }
  }

  /// 다음 슬롯 인카운터 선택
  /// 
  /// Returns: 선택된 인카운터 경로 또는 null
  Future<EncounterSelection?> nextSlot() async {
    // 🚫 터미널 처리 중이면 차단
    if (_milestoneService.isTerminalRunning || _milestoneService.isEndingShown) {
      if (kDebugMode) {
        debugPrint('[EncounterScheduler] Blocked: terminal running or ending shown');
      }
      return null;
    }

    // 🎯 큐에 마일스톤이 있으면 처리
    if (!_milestoneService.isQueueEmpty) {
      final milestone = _milestoneService.dequeue();
      if (milestone == null) return null;

      if (kDebugMode) {
        debugPrint('[EncounterScheduler] Processing milestone: $milestone');
      }

      // 테마 또는 스토리 인카운터 선택
      if (milestone.type == MilestoneType.theme) {
        return await _selectThemeEncounter(milestone.value);
      } else {
        return await _selectStoryEncounter(milestone.value);
      }
    }

    // 🔄 큐가 비었으면 반복 인카운터
    if (kDebugMode) {
      debugPrint('[EncounterScheduler] Queue empty, selecting repeat encounter');
    }
    return await _selectRepeatEncounter();
  }

  /// 테마 인카운터 선택 (= 챕터)
  Future<EncounterSelection?> _selectThemeEncounter(int milestone) async {
    // 시작 테마에 해당하는 풀 조회
    final pool = _themeConfig.poolByStart[_startThemeKey];
    
    if (pool == null || pool.isEmpty) {
      if (kDebugMode) {
        debugPrint('[EncounterScheduler] No theme pool for key: $_startThemeKey');
      }
      // 풀백: 랜덤 인카운터
      return await _selectRepeatEncounter();
    }

    // 풀에서 선택
    final selected = _selectFromPool(pool, _themeConfig.selection);
    
    // 🆕 XP 통합: 경로 구성 (chapter 서브폴더)
    final path = 'assets/dialogue/main/chapter/$selected.json';

    if (kDebugMode) {
      debugPrint('[EncounterScheduler] Selected chapter: $path for M$milestone');
    }

    return EncounterSelection(
      path: path,
      type: 'chapter', // 🆕 theme → chapter
      milestone: milestone,
      source: 'chapter_pool($_startThemeKey)',
    );
  }

  /// 스토리 인카운터 선택
  Future<EncounterSelection?> _selectStoryEncounter(int milestone) async {
    final sequence = _storyConfig.sequence;
    
    if (sequence.isEmpty) {
      if (kDebugMode) {
        debugPrint('[EncounterScheduler] No story sequence configured');
      }
      return await _selectRepeatEncounter();
    }

    // 마일스톤 인덱스 계산 (10->0, 30->1, 50->2, 70->3, 90->4)
    final storyMilestones = _milestoneService.config.storyMilestones;
    final index = storyMilestones.indexOf(milestone);
    
    if (index < 0 || index >= sequence.length) {
      if (kDebugMode) {
        debugPrint('[EncounterScheduler] Story index out of range: $index');
      }
      return await _selectRepeatEncounter();
    }

    final selected = sequence[index];
    // 🆕 XP 통합: 경로 구성 (story 서브폴더)
    final path = 'assets/dialogue/main/story/$selected.json';

    if (kDebugMode) {
      debugPrint('[EncounterScheduler] Selected story: $path for M$milestone');
    }

    return EncounterSelection(
      path: path,
      type: 'story',
      milestone: milestone,
      source: 'story_sequence[$index]',
    );
  }

  /// 반복 랜덤 인카운터 선택
  Future<EncounterSelection?> _selectRepeatEncounter() async {
    final path = await _dialogueIndex.selectRandomEncounter();
    
    if (path == null) {
      if (kDebugMode) {
        debugPrint('[EncounterScheduler] Failed to select repeat encounter');
      }
      return null;
    }

    if (kDebugMode) {
      debugPrint('[EncounterScheduler] Selected repeat: $path');
    }

    return EncounterSelection(
      path: path,
      type: 'repeat',
      source: 'random',
    );
  }

  /// 풀에서 선택 (weighted_random 또는 sequential)
  String _selectFromPool(List<String> pool, String selectionMode) {
    if (pool.isEmpty) {
      throw ArgumentError('Pool cannot be empty');
    }

    if (selectionMode == 'sequential') {
      // 순차 선택 (간단히 첫 번째)
      return pool.first;
    } else {
      // weighted_random (가중치 없으면 균등 랜덤)
      return pool[Random().nextInt(pool.length)];
    }
  }

  /// 상태 저장
  Map<String, dynamic> toJson() => {
        'startThemeKey': _startThemeKey,
      };

  /// 상태 복원
  void fromJson(Map<String, dynamic> json) {
    _startThemeKey = json['startThemeKey'] as String? ?? 'default';
    
    if (kDebugMode) {
      debugPrint('[EncounterScheduler] Loaded: startThemeKey=$_startThemeKey');
    }
  }

  /// 디버그 정보
  String debugInfo() {
    return '''
EncounterScheduler Debug:
  Start Theme Key: $_startThemeKey
  Queue Size: ${_milestoneService.queueSize}
  Terminal: ${_milestoneService.isTerminalRunning}
  Ending Shown: ${_milestoneService.isEndingShown}
  Current XP: ${_xpService.get()}
''';
  }
}

