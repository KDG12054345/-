import 'package:flutter/material.dart';
import '../../inventory/inventory_system.dart';
import '../../theme/app_theme.dart';

/// (legacy name) 전투 화면용 인벤토리 표시 위젯.
///
/// 기존 9x6 그리드/드래그/회전 기반 UI는 제거되고,
/// 텍스트(리스트) 기반으로 현재 보유 아이템을 표시합니다.
class CombatInventoryGrid extends StatelessWidget {
  final InventorySystem inventorySystem;
  final Color accentColor;
  final bool isEnemy;

  const CombatInventoryGrid({
    super.key,
    required this.inventorySystem,
    required this.accentColor,
    this.isEnemy = false,
    bool enableDragTarget = true, // legacy param ignored
    bool treatExternalDropAsReward = false, // legacy param ignored
  });

  @override
  Widget build(BuildContext context) {
    final items = inventorySystem.items;
    final tier = inventorySystem.encumbranceTier;
    
    // v6.2: 과적 단계별 색상
    final tierColor = switch (tier) {
      EncumbranceTier.normal => Colors.greenAccent,
      EncumbranceTier.uncomfortable => Colors.amberAccent,
      EncumbranceTier.danger => Colors.orange,
      EncumbranceTier.collapse => Colors.redAccent,
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withOpacity(0.35)),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEnemy ? '적 인벤토리' : '인벤토리',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          // v6.2: 슬롯 정보 추가
          Text(
            '슬롯 ${inventorySystem.usedItemSlots}/${inventorySystem.totalItemSlots}',
            style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            '무게 ${inventorySystem.currentWeight.toStringAsFixed(1)} / ${inventorySystem.maxWeight.toStringAsFixed(1)}',
            style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11),
          ),
          const SizedBox(height: 4),
          // v6.2: 과적 단계 색상 표시
          Text(
            inventorySystem.encumbranceSummary,
            style: TextStyle(color: tierColor.withOpacity(0.9), fontSize: 11),
          ),
          const Divider(height: 16),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text(
                      '비어 있음',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          item.name,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          item.id,
                          style: const TextStyle(color: Colors.white38, fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
