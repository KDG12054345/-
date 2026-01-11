import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/game_controller.dart';
import '../core/state/combat_state.dart';
import '../core/state/events.dart'; // CombatResult 이벤트 import
import '../theme/app_theme.dart';
import '../combat/character.dart';
import '../widgets/combat/combat_inventory_grid.dart';
import '../widgets/combat/animated_stat_bar.dart';
import '../widgets/combat/status_effect_display.dart';
import '../widgets/combat/damage_popup.dart';
import '../widgets/combat/combat_effects.dart';
import '../widgets/combat/combat_log_display.dart';
import '../widgets/combat/combat_menu_bar.dart';

class CombatScreen extends StatefulWidget {
  const CombatScreen({super.key});

  @override
  State<CombatScreen> createState() => _CombatScreenState();
}

class _CombatScreenState extends State<CombatScreen> {
  bool _showStartAnimation = true;
  
  @override
  void initState() {
    super.initState();
    // 전투 시작 애니메이션 후 숨김
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _showStartAnimation = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // read (watch 아님) - 슬롯이 갱신 트리거를 담당
    final controller = context.read<GameController>();
    
    // CombatStateSlot 직접 구독
    return ListenableBuilder(
      listenable: controller.combatStateSlot,
      builder: (context, child) {
        final combat = controller.combatStateSlot.current;

        if (combat == null) {
          return Container(
            decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
            child: const Center(
              child: Text('전투 데이터 없음', style: TextStyle(color: Colors.white)),
            ),
          );
        }

        return _buildCombatUI(context, controller, combat);
      },
    );
  }
  
  /// 전투 UI 빌드 (슬롯에서 combat 상태를 받아 렌더링)
  Widget _buildCombatUI(BuildContext context, GameController controller, CombatState combat) {
    return CombatEffectsManager(
      child: DamagePopupManager(
        child: Container(
          decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
          child: SafeArea(
            child: Stack(
              fit: StackFit.expand, // 중요: Stack이 부모 크기에 맞춰 확장되도록 명시
              children: [
                // 메인 콘텐츠를 Positioned.fill로 감싸서 명시적인 제약 제공
                Positioned.fill(
                  child: Column(
                    children: [
                      // 상단 헤더
                      _buildHeader(context, combat),
                      
                      const SizedBox(height: 8),
                      
                      // 상단: 플레이어와 적 정보 (초상화, HP/스테미나, 버프/디버프)
                      _buildTopCombatants(context, combat),
                      
                      const SizedBox(height: 8),
                      
                      // 중간: 인벤토리 영역 (왼쪽/오른쪽)
                      Expanded(
                        child: _buildInventoryRow(context, combat),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // 하단: 전투 로그
                      const CombatLogDisplay(height: 120),
                      
                      const SizedBox(height: 8),
                      
                      // 맨 아래: 메뉴바
                      const CombatMenuBar(),
                      
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                
                // 전투 시작 애니메이션
                if (_showStartAnimation)
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: false,
                      child: CombatStartAnimation(
                        onComplete: () {
                          if (mounted) {
                            setState(() {
                              _showStartAnimation = false;
                            });
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 테스트용 버튼들
  Widget _buildTestButtons(BuildContext context, CombatState combat) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                // 데미지 팝업 테스트
                final popupManager = DamagePopupManager.of(context);
                final effectsManager = CombatEffectsManager.of(context);
                
                popupManager?.showDamage(
                  damage: 100,
                  position: const Offset(200, 300),
                  isCritical: true,
                );
                
                effectsManager?.triggerShake();
                effectsManager?.triggerFlash(color: Colors.red);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.withOpacity(0.8),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('이펙트 테스트', style: TextStyle(fontSize: 10)),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                // 전투 종료 (승리)
                context.read<GameController>().dispatch(
                  const CombatResult({'result': 'victory'}),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.withOpacity(0.8),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('승리', style: TextStyle(fontSize: 10)),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                // 전투 종료 (패배)
                context.read<GameController>().dispatch(
                  const CombatResult({'result': 'defeat'}),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.8),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('패배', style: TextStyle(fontSize: 10)),
            ),
          ),
        ],
      ),
    );
  }

  /// 상단 헤더 (타이틀, 컨트롤 버튼들)
  Widget _buildHeader(BuildContext context, CombatState combat) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        border: Border(
          bottom: BorderSide(color: AppTheme.accentGold.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          // 인카운터 타이틀
          Text(
            combat.encounterTitle ?? '전투',
            style: const TextStyle(
              color: AppTheme.accentGold,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const Spacer(),
          
          // 경과 시간
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _getTimerColor(combat.elapsedSeconds),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _formatTime(combat.elapsedSeconds),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // 전체화면 버튼
          IconButton(
            icon: const Icon(Icons.fullscreen, color: Colors.white),
            onPressed: () {},
            tooltip: '전체화면',
          ),
          
          // 속도 조절 버튼
          IconButton(
            icon: const Icon(Icons.speed, color: Colors.white),
            onPressed: () {},
            tooltip: '속도: 1x',
          ),
          
          // 로그 버튼
          PopupMenuButton(
            icon: const Icon(Icons.article, color: Colors.white),
            tooltip: '전투 로그',
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'log',
                child: Text('전투 로그 보기'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 인벤토리 섹션
  Widget _buildInventorySection({
    required BuildContext context,
    required String title,
    required Color color,
    Character? character,
    required bool isEnemy,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: character?.inventorySystem != null
                ? CombatInventoryGrid(
                    inventorySystem: character!.inventorySystem,
                    accentColor: color,
                    isEnemy: isEnemy,
                  )
                : _buildPlaceholderGrid(color),
          ),
        ],
      ),
    );
  }
  
  /// 플레이스홀더 그리드 (인벤토리가 없을 때)
  Widget _buildPlaceholderGrid(Color color) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = (constraints.maxWidth - 8 * 1) / 9;
        final cellHeight = (constraints.maxHeight - 5 * 1) / 6;
        final aspectRatio = cellWidth / cellHeight;
        
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 9,
            crossAxisSpacing: 1,
            mainAxisSpacing: 1,
            childAspectRatio: aspectRatio,
          ),
          itemCount: 54,
          itemBuilder: (context, index) {
            return Container(
              decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                border: Border.all(
                  color: color.withOpacity(0.2),
                  width: 0.5,
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 상단 전투원 정보 영역 (초상화, HP/스테미나, 버프/디버프)
  Widget _buildTopCombatants(BuildContext context, CombatState combat) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentGold.withOpacity(0.3), width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 왼쪽: 플레이어 정보
          Expanded(
            child: _buildTopCombatant(
              character: combat.player!,
              isPlayer: true,
            ),
          ),
          
          // 중앙 구분선
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: AppTheme.accentGold.withOpacity(0.3),
          ),
          
          // 오른쪽: 적 정보
          Expanded(
            child: _buildTopCombatant(
              character: combat.enemy!,
              isPlayer: false,
            ),
          ),
        ],
      ),
    );
  }

  /// 상단 전투원 정보 (초상화, HP/스테미나, 버프/디버프)
  Widget _buildTopCombatant({
    required Character character,
    required bool isPlayer,
  }) {
    final maxHp = character.maxHealth;
    final currentHp = character.currentHealth;
    final maxStamina = character.maxStamina;
    final currentStamina = character.currentStamina;
    
    final color = isPlayer ? Colors.blue : Colors.red;
    
    // 상태 효과 리스트
    final statusEffects = character.statusEffects.values.toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 초상화와 HP/스테미나를 가로로 배치
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 초상화
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(
                isPlayer ? Icons.person : Icons.dangerous,
                size: 36,
                color: color,
              ),
            ),
            
            const SizedBox(width: 8),
            
            // HP/스테미나 바
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 이름
                  Text(
                    character.name,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // HP 바
                  AnimatedStatBar(
                    icon: Icons.favorite,
                    color: Colors.red,
                    current: currentHp.toDouble(),
                    max: maxHp.toDouble(),
                    width: double.infinity,
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // 스태미나 바
                  AnimatedStatBar(
                    icon: Icons.flash_on,
                    color: Colors.yellow,
                    current: currentStamina,
                    max: maxStamina,
                    width: double.infinity,
                  ),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // 버프/디버프 창
        if (statusEffects.isNotEmpty)
          Flexible(
            child: StatusEffectDisplay(
              effects: statusEffects,
              iconSize: 20,
              maxVisible: 6,
            ),
          ),
      ],
    );
  }

  /// 인벤토리 행 (왼쪽/오른쪽)
  Widget _buildInventoryRow(BuildContext context, CombatState combat) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 왼쪽: 플레이어 인벤토리
        Expanded(
          child: _buildInventorySection(
            context: context,
            title: '내 인벤토리',
            color: Colors.blue,
            character: combat.player,
            isEnemy: false,
          ),
        ),
        
        const SizedBox(width: 8),
        
        // 오른쪽: 적 인벤토리
        Expanded(
          child: _buildInventorySection(
            context: context,
            title: '적 인벤토리',
            color: Colors.red,
            character: combat.enemy,
            isEnemy: true,
          ),
        ),
      ],
    );
  }



  /// 시간 포맷 (초 → MM:SS)
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// 타이머 색상 (90초 이후 경고)
  Color _getTimerColor(int seconds) {
    if (seconds >= 90) {
      return Colors.red.withOpacity(0.8);
    } else if (seconds >= 60) {
      return Colors.orange.withOpacity(0.8);
    } else {
      return Colors.blue.withOpacity(0.8);
    }
  }
}
