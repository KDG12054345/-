import 'package:flutter/foundation.dart';
import '../state/combat_state.dart';

/// Last-Value 슬롯: CombatState를 위한 백프레셔 구현
/// 
/// - FIFO 큐 대신 최신 1개만 유지
/// - sessionId 검증으로 경합/잔상 차단
/// - 종료 후 업데이트 절대 금지
/// - UI가 직접 구독 (ChangeNotifier)
class CombatStateSlot extends ChangeNotifier {
  CombatState? _state;
  String? _sessionId;
  bool _combatEnded = false;
  
  // ========== 불변조건 검사용 메트릭 ==========
  int _updateCountAfterEnd = 0;
  int _discardedBySessionMismatch = 0;
  int _totalUpdates = 0;
  
  // Getters for metrics
  int get updateCountAfterEnd => _updateCountAfterEnd;
  int get discardedBySessionMismatch => _discardedBySessionMismatch;
  int get totalUpdates => _totalUpdates;
  
  /// 현재 전투 상태 (종료 후 null)
  CombatState? get current => _combatEnded ? null : _state;
  
  /// 현재 세션 ID
  String? get sessionId => _sessionId;
  
  /// 전투 종료 여부
  bool get isCombatEnded => _combatEnded;
  
  /// 세션 ID 설정 (EnterCombat 시점에 호출)
  /// 
  /// 새 전투 세션을 시작하고 이전 상태를 초기화합니다.
  void setSessionId(String id) {
    _sessionId = id;
    _combatEnded = false;
    _state = null;
    _updateCountAfterEnd = 0;
    _discardedBySessionMismatch = 0;
    _totalUpdates = 0;
  }
  
  /// 전투 상태 업데이트 (sessionId 검증 포함)
  /// 
  /// - sessionId 불일치 시 즉시 폐기 (DISCARDED)
  /// - 종료 후 호출 시 횟수만 기록하고 무시
  void update(CombatState state, {required String sessionId}) {
    // 1. sessionId 불일치 → 즉시 폐기
    if (sessionId != _sessionId) {
      _discardedBySessionMismatch++;
      print('[CombatStateSlot] DISCARDED: sessionId mismatch '
            '($sessionId != $_sessionId)');
      return;
    }
    
    // 2. 종료 후 → 횟수 기록하고 무시 (절대 금지)
    if (_combatEnded) {
      _updateCountAfterEnd++;
      print('[CombatStateSlot] BLOCKED: update after combat ended '
            '(count: $_updateCountAfterEnd)');
      return;
    }
    
    // 3. 정상 업데이트
    _state = state;
    _totalUpdates++;
    notifyListeners();
  }
  
  /// 전투 종료 표시
  /// 
  /// - 이후 모든 update 호출은 무시됨
  /// - notifyListeners() 호출하지 않음 → 구독 갱신 중지
  void markCombatEnded() {
    _combatEnded = true;
    _state = null;
    // ⚠️ notifyListeners() 호출 금지: 구독 갱신 중지
  }
  
  /// 슬롯 초기화 (세션 ID 없이)
  /// 
  /// 주로 테스트나 특수 상황에서 사용
  void reset() {
    _combatEnded = false;
    _state = null;
    _sessionId = null;
    _updateCountAfterEnd = 0;
    _discardedBySessionMismatch = 0;
    _totalUpdates = 0;
  }
  
  /// 메트릭 요약 문자열
  String getMetricsSummary() {
    return '[CombatStateSlot] Metrics: '
           'totalUpdates=$_totalUpdates, '
           'updateCountAfterEnd=$_updateCountAfterEnd, '
           'discardedBySessionMismatch=$_discardedBySessionMismatch';
  }
  
  @override
  String toString() {
    return 'CombatStateSlot(sessionId: $_sessionId, '
           'ended: $_combatEnded, hasState: ${_state != null})';
  }
}
