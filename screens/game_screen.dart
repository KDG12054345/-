import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/game_controller.dart';
import '../core/state/events.dart';
import '../core/state/app_phase.dart';
import '../theme/app_theme.dart';
import '../core/character/character_models.dart';
import '../dialogue_manager.dart'; // 올바른 경로
import '../enhanced_dialogue_manager.dart'; // 올바른 경로
import 'combat_screen.dart'; // 전투 화면 import

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final vm = controller.vm;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: _buildContent(context, vm),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, vm) {
    // 에러 상태
    if (vm.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '에러: ${vm.error}',
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                context.read<GameController>().dispatch(const StartGame());
              },
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    // 로딩 상태
    if (vm.loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.accentGold),
            SizedBox(height: 16),
            Text(
              '게임을 로딩하고 있습니다...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    // startMenu 상태 (이론적으로는 여기 올 수 없음)
    if (vm.phase == AppPhase.startMenu) {
      return Center(
        child: ElevatedButton(
          onPressed: () {
            context.read<GameController>().dispatch(const StartGame());
          },
          child: const Text('게임 시작'),
        ),
      );
    }

    // ⚔️ 전투 화면
    if (vm.phase == AppPhase.inGame_combat) {
      return const CombatScreen();
    }

    // 실제 게임 화면
    return Padding(
      padding: const EdgeInsets.all(16.0), // 누락된 padding 추가
      child: Column(
        children: [
          // 캐릭터 정보 영역
          _buildCharacterInfoArea(vm), // vm 매개변수 추가
          
          const SizedBox(height: 16),
          
          // 스토리 영역
          Expanded(
            child: _buildStoryArea(context, vm),
          ),
          
          const SizedBox(height: 16),
          
          // ⚔️ 테스트: 전투 시작 버튼
          _buildTestCombatButton(context),
        ],
      ),
    );
  }

  /// 테스트용 전투 시작 버튼
  Widget _buildTestCombatButton(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton.icon(
        onPressed: () {
          context.read<GameController>().dispatch(
            const EnterCombat({'title': '숲속의 도적', 'enemyName': '도적'}),
          );
        },
        icon: const Icon(Icons.sports_kabaddi), // 전투 아이콘 대체
        label: const Text('⚔️ 전투 테스트'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.withOpacity(0.8),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppTheme.accentGold),
          ),
        ),
      ),
    );
  }

  Widget _buildCharacterInfoArea(vm) { // vm 매개변수 추가
    final player = vm.player; // vm에서 직접 플레이어 데이터 가져오기
    
    return Container(
      height: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentGold.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // 캐릭터 초상화
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.accentGold, width: 2),
            ),
            child: const Icon(
              Icons.person,
              size: 48,
              color: AppTheme.accentGold,
            ),
          ),
          
          const SizedBox(width: 12),
          
          // 캐릭터 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '모험가',
                  style: TextStyle(
                    color: AppTheme.accentGold,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // 체력 하트만 표시 (텍스트 제거)
                _buildHeartRow(player?.vitality ?? 4, player?.maxVitality ?? 4, Colors.red),
                const SizedBox(height: 4),
                // 정신력 하트만 표시 (텍스트 제거)  
                _buildHeartRow(player?.sanity ?? 4, player?.maxSanity ?? 4, Colors.blue),
              ],
            ),
          ),
          
          const SizedBox(width: 12),
          
          // 스탯 그리드 (실제 플레이어 데이터 사용)
          _buildStatsGrid(player),
        ],
      ),
    );
  }

  Widget _buildHeartRow(int current, int max, Color color) {
    return Row(
      children: List.generate(max, (index) => Padding(
        padding: const EdgeInsets.only(right: 2),
        child: Icon(
          Icons.favorite,
          size: 16,
          color: index < current ? color : color.withOpacity(0.3),
        ),
      )),
    );
  }

  Widget _buildStatsGrid(Player? player) {
    if (player == null) {
      // 플레이어 데이터가 없을 때 기본값
      final stats = [
        {'icon': Icons.fitness_center, 'value': '?', 'color': Colors.red},
        {'icon': Icons.flash_on, 'value': '?', 'color': Colors.green},
        {'icon': Icons.psychology, 'value': '?', 'color': Colors.blue},
        {'icon': Icons.favorite, 'value': '?', 'color': Colors.pink},
      ];
      
      return SizedBox(
        width: 120,
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: stats.map((stat) => Container(
            width: 52,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: (stat['color'] as Color).withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  stat['icon'] as IconData,
                  size: 10,
                  color: stat['color'] as Color,
                ),
                const SizedBox(width: 2),
                Text(
                  stat['value'].toString(),
                  style: TextStyle(
                    color: stat['color'] as Color,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          )).toList(),
        ),
      );
    }

    // 실제 플레이어 데이터 사용
    final stats = [
      {'icon': Icons.fitness_center, 'value': player.strength, 'color': Colors.red},
      {'icon': Icons.flash_on, 'value': player.agility, 'color': Colors.green},
      {'icon': Icons.psychology, 'value': player.intelligence, 'color': Colors.blue},
      {'icon': Icons.favorite, 'value': player.charisma, 'color': Colors.pink},
    ];

    return SizedBox(
      width: 120,
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: stats.map((stat) => Container(
          width: 52,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: (stat['color'] as Color).withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                stat['icon'] as IconData,
                size: 10,
                color: stat['color'] as Color,
              ),
              const SizedBox(width: 2),
              Text(
                stat['value'].toString(),
                style: TextStyle(
                  color: stat['color'] as Color,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildStoryArea(BuildContext context, vm) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentGold.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    // ✅ 하드코딩 제거: vm.text가 null이면 빈 문자열 또는 로딩 메시지
                    vm.text ?? '',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      height: 1.6,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.left,
                  ),
                  const SizedBox(height: 20),
                  // 선택지 목록 추가
                  _buildChoicesList(context, vm),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoicesList(BuildContext context, vm) {
    // 추후 DialogueManager에서 실제 선택지를 가져올 예정
    // 현재는 JSON 파일이 없으므로 빈 상태 표시
    
    try {
      // TODO: DialogueManager가 Provider에 등록되면 활성화
      // final dialogueManager = context.watch<DialogueManager>();
      // final choices = dialogueManager.getChoices();
      
      // if (choices.isNotEmpty) {
      //   return Column(
      //     crossAxisAlignment: CrossAxisAlignment.stretch,
      //     children: choices.map((choice) => _buildChoiceButton(context, choice)).toList(),
      //   );
      // }
      
      // JSON 파일이 로드되기 전까지는 기본 계속하기 버튼만 표시
      return _buildContinueButton(context);
      
    } catch (e) {
      debugPrint('DialogueManager 접근 실패: $e');
      return _buildContinueButton(context);
    }
  }

  Widget _buildContinueButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => context.read<GameController>().dispatch(const Next()),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue.withOpacity(0.8),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: AppTheme.accentGold.withOpacity(0.5)),
          ),
        ),
        child: const Text(
          '계속하기',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceButton(BuildContext context, Choice choice) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton(
        onPressed: choice.isEnabled ? () => _handleChoice(context, choice.id) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: choice.isEnabled 
              ? AppTheme.primaryBlue.withOpacity(0.8)
              : Colors.grey.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: choice.isEnabled 
                  ? AppTheme.accentGold.withOpacity(0.5)
                  : Colors.grey.withOpacity(0.3),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                choice.text,
                style: TextStyle(
                  color: choice.isEnabled 
                      ? AppTheme.textPrimary
                      : Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // 확률 정보 표시 (EnhancedChoice인 경우)
            if (choice is EnhancedChoice && choice.displayChance != null) ...[
              const SizedBox(width: 8),
              _buildChanceIndicator(choice.displayChance!),
            ],
            // 비활성화된 선택지 표시
            if (!choice.isEnabled) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.lock,
                color: Colors.grey,
                size: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChanceIndicator(String chance) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getChanceColor(chance),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppTheme.accentGold.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Text(
        chance,
        style: const TextStyle(
          color: AppTheme.accentGold,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getChanceColor(String chance) {
    // 데이터 기반 색상 결정
    if (chance.contains('%')) {
      final percent = int.tryParse(chance.replaceAll('%', '')) ?? 50;
      if (percent < 30) return Colors.red.withOpacity(0.2);
      if (percent < 70) return Colors.orange.withOpacity(0.2);
      return Colors.green.withOpacity(0.2);
    }
    
    switch (chance) {
      case '매우 낮음': return Colors.red.withOpacity(0.2);
      case '낮음': return Colors.orange.withOpacity(0.2);
      case '보통': return Colors.yellow.withOpacity(0.2);
      case '높음': return Colors.lightGreen.withOpacity(0.2);
      case '매우 높음': return Colors.green.withOpacity(0.2);
      default: return Colors.grey.withOpacity(0.2);
    }
  }


  void _handleChoice(BuildContext context, String choiceId) {
    debugPrint('선택된 선택지: $choiceId');
    
    // TODO: DialogueManager 연결 후 활성화
    // try {
    //   final dialogueManager = context.read<DialogueManager>();
    //   dialogueManager.handleChoice(choiceId);
    // } catch (e) {
    //   debugPrint('DialogueManager 처리 실패: $e');
    //   // 폴백: GameController 이벤트 발송
    //   context.read<GameController>().dispatch(const Next());
    // }
    
    // 임시로 GameController 이벤트 발송
    context.read<GameController>().dispatch(const Next());
  }
}
