import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/game_controller.dart';
import '../core/state/events.dart';
import '../core/character/character_models.dart';
import '../theme/app_theme.dart';
import '../dialogue_manager.dart';
import '../app/app_wrapper.dart';

/// 게임오버 화면
/// 
/// 플레이어가 생명력 또는 정신력이 0이 되었을 때 표시되는 화면
/// - 사망 원인 표시
/// - 최종 캐릭터 상태 요약
/// - "다시 시작" 버튼 (저장 삭제 후 시작 화면으로 복귀)
class GameOverScreen extends StatefulWidget {
  const GameOverScreen({super.key});

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen> {
  @override
  void initState() {
    super.initState();
    // 게임 오버 시 자동으로 저장 삭제
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dialogueManager = context.read<DialogueManager>();
      dialogueManager.deleteSave().then((_) {
        debugPrint('✅ [GameOverScreen] 게임 오버 - 저장 자동 삭제 완료');
      }).catchError((e) {
        debugPrint('❌ [GameOverScreen] 저장 삭제 실패: $e');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final vm = controller.vm;
    final player = vm.player;

    // 사망 원인 판별
    final deathReason = _getDeathReason(player);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1a0000), // 어두운 빨강
            Color(0xFF000000), // 검정
          ],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 40),
                
                // 💀 게임오버 타이틀
                const Icon(
                  Icons.sentiment_very_dissatisfied,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 20),
                
                const Text(
                  'GAME OVER',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // 사망 원인
                Text(
                  deathReason,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 32),
                
                // 요약 정보
                _buildSummaryBox(player),
                
                const SizedBox(height: 40),
                
                // 다시 시작 버튼
                _buildRestartButton(context),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 사망 원인 메시지 생성
  String _getDeathReason(Player? player) {
    if (player == null) return '알 수 없는 이유로 사망하였습니다...';
    
    if (player.vitality <= 0 && player.sanity <= 0) {
      return '당신은 육체와 정신이 모두 무너졌습니다...';
    } else if (player.vitality <= 0) {
      return '당신의 생명력이 바닥났습니다...';
    } else if (player.sanity <= 0) {
      return '당신은 광기에 사로잡혔습니다...';
    }
    return '당신의 모험이 끝났습니다...';
  }

  /// 최종 상태 요약 박스
  Widget _buildSummaryBox(Player? player) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          const Text(
            '최종 상태',
            style: TextStyle(
              color: AppTheme.accentGold,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          if (player != null) ...[
            _buildStatRow('생명력', player.vitality, player.maxVitality, Colors.red),
            const SizedBox(height: 8),
            _buildStatRow('정신력', player.sanity, player.maxSanity, Colors.blue),
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 16),
            _buildStatsGrid(player),
          ] else ...[
            const Text(
              '캐릭터 정보 없음',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ],
      ),
    );
  }

  /// 생명력/정신력 하트 표시
  Widget _buildStatRow(String label, int current, int max, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        Row(
          children: List.generate(
            max,
            (index) => Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Icon(
                Icons.favorite,
                size: 20,
                color: index < current ? color : color.withOpacity(0.3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 능력치 그리드 표시
  Widget _buildStatsGrid(Player player) {
    final stats = [
      {'label': '힘', 'value': player.strength, 'icon': Icons.fitness_center, 'color': Colors.red},
      {'label': '민첩', 'value': player.agility, 'icon': Icons.flash_on, 'color': Colors.green},
      {'label': '지능', 'value': player.intelligence, 'icon': Icons.psychology, 'color': Colors.blue},
      {'label': '매력', 'value': player.charisma, 'icon': Icons.favorite, 'color': Colors.pink},
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: stats.map((stat) => _buildStatItem(stat)).toList(),
    );
  }

  /// 개별 능력치 아이템
  Widget _buildStatItem(Map<String, dynamic> stat) {
    return Container(
      width: 80,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: (stat['color'] as Color).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            stat['icon'] as IconData,
            size: 24,
            color: stat['color'] as Color,
          ),
          const SizedBox(height: 4),
          Text(
            stat['label'] as String,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
          const SizedBox(height: 2),
          Text(
            '${stat['value']}',
            style: TextStyle(
              color: stat['color'] as Color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 다시 시작 버튼 (저장 삭제 + 시작 화면으로)
  Widget _buildRestartButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _handleRestart(context),
        icon: const Icon(Icons.refresh, size: 28),
        label: const Text(
          '다시 시작',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppTheme.accentGold.withOpacity(0.6), width: 2),
          ),
        ),
      ),
    );
  }

  /// 다시 시작 처리
  /// 
  /// 1. 저장 파일 삭제 (이미 initState에서 삭제됨)
  /// 2. 시작 화면으로 복귀
  Future<void> _handleRestart(BuildContext context) async {
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    
    try {
      // 시작 화면으로 복귀
      if (context.mounted) {
        appState.returnToStart();
        
        messenger.showSnackBar(
          const SnackBar(
            content: Text('🔄 게임이 초기화되었습니다'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [GameOverScreen] 초기화 실패: $e');
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('⚠️ 초기화 중 오류 발생: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.orange,
          ),
        );
        
        // 오류가 발생해도 시작 화면으로 이동
        appState.returnToStart();
      }
    }
  }
}


