import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 스탯 배지 위젯 - HeartRow 패턴을 재사용하여 설계
class StatBadge extends StatelessWidget {
  final IconData icon;
  final int value;
  final Color color;
  final String? label;
  final double size;
  final double minScale;        // HeartRow와 동일한 반응형 로직
  final bool enableCompactMode;

  const StatBadge({
    super.key,
    required this.icon,
    required this.value,
    required this.color,
    this.label,
    this.size = 52.0,  // 기존 크기 그대로
    this.minScale = 0.7,
    this.enableCompactMode = true,
  });

  @override
  Widget build(BuildContext context) {
    // HeartRow와 동일한 LayoutBuilder 패턴
    return LayoutBuilder(
      builder: (context, constraints) {
        return _buildResponsiveStatBadge(constraints.maxWidth);
      },
    );
  }

  // HeartRow의 반응형 로직 패턴 재사용
  Widget _buildResponsiveStatBadge(double availableWidth) {
    // 스케일 계산 (HeartRow 로직 재사용)
    double scale = 1.0;
    if (size > availableWidth) {
      scale = (availableWidth / size).clamp(minScale, 1.0);
    }
    
    // 컴팩트 모드 체크 (HeartRow 패턴)
    if (enableCompactMode && scale < minScale) {
      return _buildCompactMode();
    }
    
    // 일반 모드 (기존 스타일 그대로)
    final scaledSize = size * scale;
    final scaledHeight = 20.0 * scale;
    
    return Container(
      width: scaledSize,
      height: scaledHeight,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10 * scale),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 12 * scale, color: color),
          SizedBox(width: 2 * scale),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 10 * scale,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // HeartRow의 컴팩트 모드 패턴 재사용
  Widget _buildCompactMode() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// 스탯 그리드 위젯 - 기존 _buildStatsGrid 로직 재사용
class StatGrid extends StatelessWidget {
  final List<StatData> stats;
  final double spacing;
  final double runSpacing;

  const StatGrid({
    super.key,
    required this.stats,
    this.spacing = 8.0,
    this.runSpacing = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    // 기존 Wrap 레이아웃 그대로 재사용
    return SizedBox(
      width: 120,
      child: Wrap(
        spacing: spacing,
        runSpacing: runSpacing,
        children: stats.map((stat) => StatBadge(
          icon: stat.icon,
          value: stat.value,
          color: stat.color,
          label: stat.label,
        )).toList(),
      ),
    );
  }
}

class StatData {
  final IconData icon;
  final int value;
  final Color color;
  final String label;

  const StatData({
    required this.icon,
    required this.value,
    required this.color,
    required this.label,
  });
}
