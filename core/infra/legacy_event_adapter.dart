import '../../event_system.dart' as legacy;
import '../state/events.dart';
import '../state/inventory_events.dart';

/// 레거시 GameEvent를 새로운 GEvent 시스템으로 변환하는 어댑터 (단방향)
/// 
/// 마이그레이션 전략:
/// 1. 레거시 코드는 계속 legacy.eventManager.dispatchEvent() 호출
/// 2. LegacyEventAdapter가 레거시 이벤트를 수신하고 새 GEvent로 변환
/// 3. 변환된 이벤트는 GameController.dispatch()로 전달
class LegacyEventAdapter {
  final Function(GEvent) _dispatch;
  bool _isInitialized = false;
  
  LegacyEventAdapter(this._dispatch);
  
  /// 어댑터 초기화 - 레거시 이벤트 리스너 등록
  void initialize() {
    if (_isInitialized) return;
    
    legacy.eventManager.addEventListener(_handleLegacyEvent);
    _isInitialized = true;
    
    print('✅ LegacyEventAdapter initialized - 레거시 이벤트 → GEvent 변환 활성화');
  }
  
  /// 어댑터 정리
  void dispose() {
    if (!_isInitialized) return;
    
    legacy.eventManager.removeEventListener(_handleLegacyEvent);
    _isInitialized = false;
  }
  
  /// 레거시 이벤트를 새 시스템으로 변환
  void _handleLegacyEvent(legacy.GameEvent event) {
    final converted = _convertEvent(event);
    
    if (converted != null) {
      _dispatch(converted);
      print('🔄 Converted legacy event: ${event.type} → ${converted.runtimeType}');
    } else {
      print('⚠️ No conversion for legacy event: ${event.type}');
    }
  }
  
  /// 이벤트 변환 로직
  GEvent? _convertEvent(legacy.GameEvent event) {
    switch (event.type) {
      // 상태 효과 관련
      case legacy.GameEventType.EFFECT_APPLIED:
      case legacy.GameEventType.EFFECT_REMOVED:
      case legacy.GameEventType.EFFECT_STACK_CHANGED:
        // 전투 시스템 이벤트로 변환 (향후 combat_events.dart에 정의 예정)
        return null; // TODO: CombatEffectEvent로 변환
        
      // 체력 변화
      case legacy.GameEventType.HEALTH_CHANGED:
        return null; // TODO: HealthChangedEvent로 변환
        
      // 데미지/힐링
      case legacy.GameEventType.DAMAGE_DEALT:
      case legacy.GameEventType.DAMAGE_TAKEN:
      case legacy.GameEventType.HEAL:
      case legacy.GameEventType.CRITICAL_HIT:
        return null; // TODO: CombatEvent로 변환
        
      // 아이템 관련 (현재는 인벤토리 시스템이 직접 GEvent 사용)
      case legacy.GameEventType.ADD_ITEM:
      case legacy.GameEventType.REMOVE_ITEM:
        // 인벤토리 시스템은 이미 마이그레이션됨
        return null;
        
      // 스탯/플래그 변경 (게임 상태 관련)
      case legacy.GameEventType.CHANGE_STAT:
      case legacy.GameEventType.SET_FLAG:
        // GameState는 이미 새 시스템 사용
        return null;
        
      // 씬 변경
      case legacy.GameEventType.CHANGE_SCENE:
        return null; // TODO: SceneChangeEvent로 변환
        
      // 틱 관련
      case legacy.GameEventType.TICK:
        return null; // 틱은 새 시스템에서 직접 관리
        
      // 기타
      default:
        return null;
    }
  }
  
  /// 수동 변환 헬퍼 (특정 케이스에서 직접 호출)
  static GEvent? tryConvert(legacy.GameEvent event) {
    final adapter = LegacyEventAdapter((_) {});
    return adapter._convertEvent(event);
  }
}

/// 레거시 이벤트 발생 헬퍼 (마이그레이션 중 사용)
/// 
/// 사용 예:
/// ```dart
/// // 기존 코드
/// eventManager.dispatchEvent(GameEvent(type: GameEventType.HEAL, data: {...}));
/// 
/// // 마이그레이션 중 (두 시스템 모두 지원)
/// LegacyEventBridge.dispatch(
///   legacyEvent: GameEvent(type: GameEventType.HEAL, data: {...}),
///   modern: HealEvent(amount: 10, target: player),
/// );
/// ```
class LegacyEventBridge {
  static Function(GEvent)? _modernDispatch;
  
  /// GameController의 dispatch 함수 등록
  static void setModernDispatch(Function(GEvent) dispatch) {
    _modernDispatch = dispatch;
  }
  
  /// 레거시와 모던 이벤트를 동시에 발생 (마이그레이션 중 사용)
  static void dispatch({
    legacy.GameEvent? legacyEvent,
    GEvent? modern,
  }) {
    if (legacyEvent != null) {
      legacy.eventManager.dispatchEvent(legacyEvent);
    }
    
    if (modern != null && _modernDispatch != null) {
      _modernDispatch!(modern);
    }
  }
}
