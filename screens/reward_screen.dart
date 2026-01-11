import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/game_controller.dart';
import '../core/state/events.dart';
import '../core/character/character_models.dart';
import '../inventory/inventory_item.dart';
import '../inventory/inventory_system.dart';
import '../reward/reward_item_factory.dart';
import '../theme/app_theme.dart';
import '../services/item_store.dart';

/// 보상 화면 (텍스트형 인벤토리 + 무게 상한)
class RewardScreen extends StatefulWidget {
  const RewardScreen({super.key});

  @override
  State<RewardScreen> createState() => _RewardScreenState();
}

class _RewardScreenState extends State<RewardScreen> {
  List<InventoryItem> _rewardItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeRewardItems();

    // 보상 화면에서는 인벤토리가 잠겨있으면 안 되므로 한번 더 unlock.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final inventory = context.read<InventorySystem>();
      if (inventory.lockSystem.isLocked) {
        inventory.lockSystem.unlock();
      }
    });
  }

  Future<void> _initializeRewardItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // JSON 파일에서 아이템 로드
      final items = await ItemStore.instance.loadAllItems();
      if (mounted) {
        setState(() {
          _rewardItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[RewardScreen] Failed to load items: $e');
      if (mounted) {
        setState(() {
          _rewardItems = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final inventory = context.watch<InventorySystem>();
    final vm = controller.vm;
    final player = vm.player;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildCharacterInfoBox(player),
                const SizedBox(height: 12),
                _buildWeightHeader(inventory),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _buildRewardList(inventory)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildInventoryList(inventory)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildContinueButton(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCharacterInfoBox(Player? player) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentGold.withOpacity(0.3)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
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
                  _buildHeartRow(player?.vitality ?? 4, player?.maxVitality ?? 4, Colors.red),
                  const SizedBox(height: 4),
                  _buildHeartRow(player?.sanity ?? 4, player?.maxSanity ?? 4, Colors.blue),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _buildStatsGrid(player),
          ],
        ),
      ),
    );
  }

  Widget _buildHeartRow(int current, int max, Color color) {
    return Row(
      children: List.generate(
        max,
        (index) => Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Icon(
            Icons.favorite,
            size: 16,
            color: index < current ? color : color.withOpacity(0.3),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(Player? player) {
    if (player == null) {
      return const SizedBox(width: 120);
    }

    final stats = [
      {'icon': Icons.fitness_center, 'value': player.strength, 'color': Colors.red},
      {'icon': Icons.flash_on, 'value': player.agility, 'color': Colors.green},
      {'icon': Icons.psychology, 'value': player.intelligence, 'color': Colors.blue},
      {'icon': Icons.favorite, 'value': player.charisma, 'color': Colors.pink},
    ];

    return SizedBox(
      width: 120,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(stats[0]),
              _buildStatItem(stats[1]),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(stats[2]),
              _buildStatItem(stats[3]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(Map<String, dynamic> stat) {
    return Container(
      width: 52,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.accentGold.withOpacity(0.3)),
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
    );
  }

  Widget _buildWeightHeader(InventorySystem inventory) {
    // v6.2: 과적% 기반 표시
    final overweightPercent = inventory.overweightPercent;
    final tier = inventory.encumbranceTier;
    
    // 무게 바: 0% ~ 150% 범위를 0.0 ~ 1.0으로 매핑
    final barValue = (1.0 + overweightPercent / 100.0).clamp(0.0, 1.5) / 1.5;
    
    // 과적 단계별 색상
    // - Normal (0%): 녹색
    // - Uncomfortable (≤20%): 노란색
    // - Danger (≤50%): 주황색
    // - Collapse (>50%): 빨간색
    final color = switch (tier) {
      EncumbranceTier.normal => Colors.greenAccent,
      EncumbranceTier.uncomfortable => Colors.amberAccent,
      EncumbranceTier.danger => Colors.orange,
      EncumbranceTier.collapse => Colors.redAccent,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '무게 ${inventory.currentWeight.toStringAsFixed(1)} / ${inventory.maxWeight.toStringAsFixed(1)}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: barValue,
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            inventory.encumbranceSummary,
            style: TextStyle(color: color.withOpacity(0.9), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardList(InventorySystem inventory) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '보상',
                  style: TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                onPressed: () => _initializeRewardItems(),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('초기화'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _rewardItems.isEmpty
                    ? const Center(
                        child: Text('보상 아이템이 없습니다', style: TextStyle(color: Colors.white54)),
                      )
                    : ListView.separated(
                        itemCount: _rewardItems.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final item = _rewardItems[idx];
                          return ListTile(
                            dense: true,
                            title: Text(item.name, style: const TextStyle(color: Colors.white)),
                            subtitle: Text(item.description, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            trailing: TextButton(
                              onPressed: () {
                                final ok = inventory.tryAddItem(item.copyWith());
                                if (!ok) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('인벤토리가 잠겨 있어 획득할 수 없습니다.')),
                                  );
                                  return;
                                }
                                setState(() {
                                  _rewardItems.removeAt(idx);
                                });
                              },
                              child: const Text('획득'),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryList(InventorySystem inventory) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('인벤토리', style: TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: inventory.items.isEmpty
                ? const Center(child: Text('비어 있음', style: TextStyle(color: Colors.white54)))
                : ListView.separated(
                    itemCount: inventory.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final item = inventory.items[idx];
                      return ListTile(
                        dense: true,
                        title: Text(item.name, style: const TextStyle(color: Colors.white)),
                        subtitle: Text(item.id, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        trailing: TextButton(
                          onPressed: () {
                            inventory.removeItem(item);
                            setState(() {});
                          },
                          child: const Text('버리기'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => context.read<GameController>().dispatch(const Next()),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue.withOpacity(0.8),
          padding: const EdgeInsets.symmetric(vertical: 16),
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
}
