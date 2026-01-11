import 'package:flutter/material.dart';
import '../../combat/status_effect.dart';
import '../../combat/effect_type.dart';

/// 상태 효과 표시 위젯
/// 버프/디버프를 아이콘과 스택 수로 표시합니다.
class StatusEffectDisplay extends StatelessWidget {
  final List<StatusEffect> effects;
  final double iconSize;
  final int maxVisible;
  
  const StatusEffectDisplay({
    super.key,
    required this.effects,
    this.iconSize = 24,
    this.maxVisible = 6,
  });
  
  @override
  Widget build(BuildContext context) {
    if (effects.isEmpty) return const SizedBox.shrink();
    
    // 버프와 디버프 분리
    final buffs = effects.where((e) => e.type == EffectType.BUFF).toList();
    final debuffs = effects.where((e) => e.type == EffectType.DEBUFF).toList();
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 버프 표시
        if (buffs.isNotEmpty)
          _EffectRow(
            effects: buffs,
            iconSize: iconSize,
            maxVisible: maxVisible,
            isDebuff: false,
          ),
        
        if (buffs.isNotEmpty && debuffs.isNotEmpty)
          const SizedBox(height: 4),
        
        // 디버프 표시
        if (debuffs.isNotEmpty)
          _EffectRow(
            effects: debuffs,
            iconSize: iconSize,
            maxVisible: maxVisible,
            isDebuff: true,
          ),
      ],
    );
  }
}

/// 효과 행 위젯 (버프 또는 디버프)
class _EffectRow extends StatelessWidget {
  final List<StatusEffect> effects;
  final double iconSize;
  final int maxVisible;
  final bool isDebuff;
  
  const _EffectRow({
    required this.effects,
    required this.iconSize,
    required this.maxVisible,
    required this.isDebuff,
  });
  
  @override
  Widget build(BuildContext context) {
    final visibleEffects = effects.take(maxVisible).toList();
    final hasMore = effects.length > maxVisible;
    
    return Wrap(
      spacing: 2,
      runSpacing: 2,
      children: [
        ...visibleEffects.map((effect) => _EffectIcon(
          effect: effect,
          size: iconSize,
        )),
        
        // 더 있음 표시
        if (hasMore)
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isDebuff ? Colors.red : Colors.green,
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                '+${effects.length - maxVisible}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: iconSize * 0.3,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 개별 효과 아이콘
class _EffectIcon extends StatelessWidget {
  final StatusEffect effect;
  final double size;
  
  const _EffectIcon({
    required this.effect,
    required this.size,
  });
  
  @override
  Widget build(BuildContext context) {
    final isDebuff = effect.type == EffectType.DEBUFF;
    final borderColor = isDebuff ? Colors.red : Colors.green;
    final bgColor = isDebuff 
        ? Colors.red.withOpacity(0.3) 
        : Colors.green.withOpacity(0.3);
    
    return Tooltip(
      message: _getEffectTooltip(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: borderColor.withOpacity(0.5),
              blurRadius: 4,
            ),
          ],
        ),
        child: Stack(
          children: [
            // 효과 아이콘
            Center(
              child: Icon(
                _getEffectIcon(effect.id),
                size: size * 0.6,
                color: Colors.white,
              ),
            ),
            
            // 스택 수 표시
            if (effect.stacks > 1)
              Positioned(
                right: 1,
                bottom: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    '${effect.stacks}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  /// 효과 ID에 따른 아이콘 반환
  IconData _getEffectIcon(String effectId) {
    switch (effectId.toLowerCase()) {
      case 'burn':
        return Icons.local_fire_department;
      case 'poison':
        return Icons.science;
      case 'frost':
      case 'freeze':
        return Icons.ac_unit;
      case 'bleed':
      case 'bleeding':
        return Icons.water_drop;
      case 'blind':
        return Icons.visibility_off;
      case 'weak':
      case 'weakness':
        return Icons.trending_down;
      case 'defense':
        return Icons.shield;
      case 'regen':
      case 'regeneration':
        return Icons.favorite;
      case 'haste':
        return Icons.flash_on;
      case 'luck':
        return Icons.casino;
      case 'lifesteal':
        return Icons.bloodtype;
      case 'thorns':
        return Icons.grass;
      case 'resistance':
        return Icons.security;
      case 'mana':
        return Icons.auto_awesome;
      default:
        return Icons.help_outline;
    }
  }
  
  /// 효과 툴팁 텍스트 생성
  String _getEffectTooltip() {
    final buffer = StringBuffer();
    buffer.writeln(effect.name);
    
    if (effect.stacks > 0) {
      buffer.writeln('스택: ${effect.stacks}');
    }
    
    // 효과별 설명 추가
    buffer.write(_getEffectDescription(effect.id));
    
    return buffer.toString().trim();
  }
  
  /// 효과 설명 반환
  String _getEffectDescription(String effectId) {
    switch (effectId.toLowerCase()) {
      case 'burn':
        return '화상: 지속 피해';
      case 'poison':
        return '중독: 지속 피해';
      case 'frost':
      case 'freeze':
        return '동상: 쿨다운 감소 속도 저하';
      case 'bleed':
      case 'bleeding':
        return '출혈: 방어 무시 지속 피해';
      case 'blind':
        return '실명: 명중률 및 치명타 감소';
      case 'weak':
      case 'weakness':
        return '약화: 공격력 감소';
      case 'defense':
        return '방어: 피해 흡수';
      case 'regen':
      case 'regeneration':
        return '회복: 지속 체력 회복';
      case 'haste':
        return '가속: 쿨다운 감소 속도 증가';
      case 'luck':
        return '행운: 명중률 증가';
      case 'lifesteal':
        return '생명력 흡수: 공격 시 체력 회복';
      case 'thorns':
        return '가시: 근접 공격 반사';
      case 'resistance':
        return '저항: 디버프 차단';
      case 'mana':
        return '마나: 마나 스킬 사용 가능';
      default:
        return '';
    }
  }
}

