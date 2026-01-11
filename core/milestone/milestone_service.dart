/// 마일스톤 서비스
/// 
/// XP 마일스톤 교차 검출 및 큐 관리를 담당합니다.
/// 테마(20,40,60,80,100)와 스토리(10,30,50,70,90) 마일스톤을 추적합니다.

import 'dart:collection';
import 'package:flutter/foundation.dart';

/// 마일스톤 타입
enum MilestoneType {
  theme,
  story,
}

/// 마일스톤 정보
class Milestone {
  final int value;
  final MilestoneType type;

  const Milestone(this.value, this.type);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Milestone &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          type == other.type;

  @override
  int get hashCode => value.hashCode ^ type.hashCode;

  @override
  String toString() => 'Milestone($value, ${type.name})';
}

/// 마일스톤 설정
class MilestoneConfig {
  final int milestoneStep;
  final List<int> themeMilestones;
  final List<int> storyMilestones;
  final int chapterEnd;
  final bool resetAtEnd;

  const MilestoneConfig({
    this.milestoneStep = 10,
    this.themeMilestones = const [20, 40, 60, 80, 100],
    this.storyMilestones = const [10, 30, 50, 70, 90],
    this.chapterEnd = 100,
    this.resetAtEnd = true,
  });

  factory MilestoneConfig.fromJson(Map<String, dynamic> json) {
    return MilestoneConfig(
      milestoneStep: json['milestoneStep'] as int? ?? 10,
      // 🆕 XP 통합: chapterMilestones를 themeMilestones로 읽기 (하위 호환)
      themeMilestones: (json['chapterMilestones'] as List<dynamic>? ?? 
                        json['themeMilestones'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [20, 40, 60, 80, 100],
      storyMilestones: (json['storyMilestones'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [10, 30, 50, 70, 90],
      // 🆕 XP 통합: game.end를 chapter.end로도 읽기 (하위 호환)
      chapterEnd: (json['game']?['end'] as int? ?? json['chapter']?['end'] as int?) ?? 100,
      resetAtEnd: (json['game']?['resetAtEnd'] as bool? ?? json['chapter']?['resetAtEnd'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'milestoneStep': milestoneStep,
        'themeMilestones': themeMilestones,
        'storyMilestones': storyMilestones,
        'chapter': {
          'end': chapterEnd,
          'resetAtEnd': resetAtEnd,
        },
      };
}

/// 마일스톤 서비스 - 싱글톤
class MilestoneService {
  static MilestoneService? _instance;
  static MilestoneService get instance => _instance ??= MilestoneService._();

  MilestoneService._() {
    _loadDefaultConfig();
  }

  /// 설정
  MilestoneConfig _config = const MilestoneConfig();

  /// 트리거된 마일스톤 (중복 방지)
  final Set<int> _triggeredTheme = {};
  final Set<int> _triggeredStory = {};

  /// 대기 중인 마일스톤 큐 (오름차순)
  final Queue<Milestone> _queue = Queue<Milestone>();

  /// 터미널 상태 플래그 (100 마일스톤 처리 중)
  bool _terminalPending = false;
  bool _terminalRunning = false;
  bool _endingShown = false;

  /// 설정 로드
  void loadConfig(MilestoneConfig config) {
    _config = config;
    if (kDebugMode) {
      debugPrint('[MilestoneService] Config loaded: theme=${config.themeMilestones}, story=${config.storyMilestones}');
    }
  }

  void _loadDefaultConfig() {
    _config = const MilestoneConfig();
  }

  /// 설정 조회
  MilestoneConfig get config => _config;

  /// XP 교차 마일스톤 계산
  /// 
  /// [prev]: 이전 XP
  /// [now]: 현재 XP
  /// 
  /// Returns: 교차한 마일스톤 리스트 (오름차순, 중복 제거됨)
  List<Milestone> computeCrossed(int prev, int now) {
    if (prev >= now) return [];

    final crossed = <Milestone>[];

    // 테마 마일스톤 체크
    for (final m in _config.themeMilestones) {
      if (prev < m && now >= m && !_triggeredTheme.contains(m)) {
        crossed.add(Milestone(m, MilestoneType.theme));
      }
    }

    // 스토리 마일스톤 체크
    for (final m in _config.storyMilestones) {
      if (prev < m && now >= m && !_triggeredStory.contains(m)) {
        crossed.add(Milestone(m, MilestoneType.story));
      }
    }

    // 오름차순 정렬
    crossed.sort((a, b) => a.value.compareTo(b.value));

    if (kDebugMode && crossed.isNotEmpty) {
      debugPrint('[MilestoneService] Crossed: $prev → $now, milestones: $crossed');
    }

    return crossed;
  }

  /// 마일스톤들을 큐에 추가
  void enqueueAll(List<Milestone> milestones) {
    for (final m in milestones) {
      enqueue(m);
    }
  }

  /// 단일 마일스톤 큐에 추가
  void enqueue(Milestone milestone) {
    // 중복 방지
    if (_queue.contains(milestone)) {
      if (kDebugMode) {
        debugPrint('[MilestoneService] Duplicate milestone ignored: $milestone');
      }
      return;
    }

    _queue.add(milestone);

    // 트리거 기록
    if (milestone.type == MilestoneType.theme) {
      _triggeredTheme.add(milestone.value);
    } else {
      _triggeredStory.add(milestone.value);
    }

    // 100 마일스톤이면 터미널 플래그 설정
    if (milestone.value == _config.chapterEnd && 
        milestone.type == MilestoneType.theme) {
      _terminalPending = true;
    }

    if (kDebugMode) {
      debugPrint('[MilestoneService] Enqueued: $milestone (queue size: ${_queue.length})');
    }
  }

  /// 큐에서 다음 마일스톤 꺼내기
  /// 
  /// Returns: 마일스톤 또는 null (큐가 비었을 때)
  Milestone? dequeue() {
    if (_queue.isEmpty) return null;

    final milestone = _queue.removeFirst();

    // 터미널 마일스톤이면 플래그 업데이트
    if (milestone.value == _config.chapterEnd &&
        milestone.type == MilestoneType.theme) {
      _terminalPending = false;
      _terminalRunning = true;
    }

    if (kDebugMode) {
      debugPrint('[MilestoneService] Dequeued: $milestone (remaining: ${_queue.length})');
    }

    return milestone;
  }

  /// 큐가 비었는지
  bool get isQueueEmpty => _queue.isEmpty;

  /// 큐 크기
  int get queueSize => _queue.length;

  /// 큐 미리보기 (수정하지 않음)
  List<Milestone> peekQueue() => List.unmodifiable(_queue);

  /// 터미널 상태 확인
  bool get isTerminalPending => _terminalPending;
  bool get isTerminalRunning => _terminalRunning;
  bool get isEndingShown => _endingShown;

  /// 터미널 상태 설정
  void markTerminalRunning(bool value) {
    _terminalRunning = value;
    if (kDebugMode) {
      debugPrint('[MilestoneService] Terminal running: $value');
    }
  }

  void markEndingShown(bool value) {
    _endingShown = value;
    if (kDebugMode) {
      debugPrint('[MilestoneService] Ending shown: $value');
    }
  }

  /// 챕터 랩 (리셋 또는 누적)
  void wrapChapter() {
    if (_config.resetAtEnd) {
      // 리셋
      _triggeredTheme.clear();
      _triggeredStory.clear();
      _queue.clear();
      _terminalPending = false;
      _terminalRunning = false;
      _endingShown = false;
      
      if (kDebugMode) {
        debugPrint('[MilestoneService] Chapter wrapped with RESET');
      }
    } else {
      // 누적 (플래그만 초기화)
      _terminalPending = false;
      _terminalRunning = false;
      _endingShown = false;
      
      if (kDebugMode) {
        debugPrint('[MilestoneService] Chapter wrapped with ACCUMULATION');
      }
    }
  }

  /// 특정 마일스톤이 트리거됐는지 확인
  bool isTriggered(int value, MilestoneType type) {
    return type == MilestoneType.theme
        ? _triggeredTheme.contains(value)
        : _triggeredStory.contains(value);
  }

  /// 상태 저장
  Map<String, dynamic> toJson() => {
        'triggeredTheme': _triggeredTheme.toList(),
        'triggeredStory': _triggeredStory.toList(),
        'queue': _queue
            .map((m) => {
                  'value': m.value,
                  'type': m.type.name,
                })
            .toList(),
        'terminalPending': _terminalPending,
        'terminalRunning': _terminalRunning,
        'endingShown': _endingShown,
      };

  /// 상태 복원
  void fromJson(Map<String, dynamic> json) {
    _triggeredTheme.clear();
    _triggeredTheme.addAll(
      (json['triggeredTheme'] as List<dynamic>?)?.map((e) => e as int) ?? [],
    );

    _triggeredStory.clear();
    _triggeredStory.addAll(
      (json['triggeredStory'] as List<dynamic>?)?.map((e) => e as int) ?? [],
    );

    _queue.clear();
    final queueData = json['queue'] as List<dynamic>?;
    if (queueData != null) {
      for (final item in queueData) {
        if (item is Map<String, dynamic>) {
          final value = item['value'] as int;
          final typeName = item['type'] as String;
          final type = typeName == 'theme'
              ? MilestoneType.theme
              : MilestoneType.story;
          _queue.add(Milestone(value, type));
        }
      }
    }

    _terminalPending = json['terminalPending'] as bool? ?? false;
    _terminalRunning = json['terminalRunning'] as bool? ?? false;
    _endingShown = json['endingShown'] as bool? ?? false;

    if (kDebugMode) {
      debugPrint('[MilestoneService] Loaded state: theme=${_triggeredTheme.length}, story=${_triggeredStory.length}, queue=${_queue.length}');
    }
  }

  /// 디버그 정보
  String debugInfo() {
    return '''
MilestoneService Debug:
  Theme triggered: $_triggeredTheme
  Story triggered: $_triggeredStory
  Queue: ${_queue.toList()}
  Terminal: pending=$_terminalPending, running=$_terminalRunning, ending=$_endingShown
''';
  }
}

