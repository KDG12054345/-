import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HeartRow extends StatelessWidget {
  final String label;  // 호환성을 위해 유지하지만 표시하지 않음
  final Color color;
  final int current;
  final int max;
  final double iconSize;
  final double minScale;        // 최소 스케일 (기본 0.6)
  final bool enableCompactMode; // 컴팩트 모드 활성화 여부

  const HeartRow({
    super.key,
    required this.label,
    required this.color,
    required this.current,
    required this.max,
    this.iconSize = 16.0,
    this.minScale = 0.6,
    this.enableCompactMode = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return _buildResponsiveHeartRow(constraints.maxWidth);
      },
    );
  }

  Widget _buildResponsiveHeartRow(double availableWidth) {
    final hearts = _calculateHearts();
    
    // 라벨 없이 전체 폭 사용
    final heartAreaWidth = availableWidth;
    
    // 필요한 총 하트 폭 계산 (아이콘 + 간격)
    final heartSpacing = 2.0;
    final requiredWidth = (max * iconSize) + ((max - 1) * heartSpacing);
    
    // 스케일 계산
    double scale = 1.0;
    if (requiredWidth > heartAreaWidth) {
      scale = (heartAreaWidth / requiredWidth).clamp(minScale, 1.0);
    }
    
    // 컴팩트 모드 체크
    if (enableCompactMode && scale < minScale && max > 3) {
      return _buildCompactMode();
    }
    
    // 일반 모드 (스케일 적용) - 하트만 표시
    final scaledIconSize = iconSize * scale;
    final scaledSpacing = heartSpacing * scale;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: hearts.asMap().entries.map((entry) {
        final index = entry.key;
        final heartType = entry.value;
        
        return Padding(
          padding: EdgeInsets.only(
            right: index < hearts.length - 1 ? scaledSpacing : 0,
          ),
          child: Icon(
            _getHeartIcon(heartType),
            size: scaledIconSize,
            color: _getHeartColor(heartType),
          ),
        );
      }).toList(),
    );
  }

  // 컴팩트 모드: "♥×3/5" 형태로 표시 (라벨 없음)
  Widget _buildCompactMode() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.favorite,
          size: iconSize * 0.8, // 약간 작게
          color: color,
        ),
        const SizedBox(width: 2),
        Text(
          '×$current',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (current < max) ...[
          Text(
            '/',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 11,
            ),
          ),
          Text(
            '$max',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }

  List<HeartType> _calculateHearts() {
    List<HeartType> hearts = [];
    
    // 현재 하트들 (꽉찬 하트) - 1:1 매칭
    for (int i = 0; i < current; i++) {
      hearts.add(HeartType.full);
    }
    
    // 빈 하트들 (잃은 생명력/정신력) - 1:1 매칭
    final emptyHearts = max - current;
    for (int i = 0; i < emptyHearts; i++) {
      hearts.add(HeartType.empty);
    }
    
    return hearts;
  }

  IconData _getHeartIcon(HeartType type) {
    switch (type) {
      case HeartType.full:
        return Icons.favorite;
      case HeartType.empty:
        return Icons.favorite_border;
    }
  }

  Color _getHeartColor(HeartType type) {
    switch (type) {
      case HeartType.full:
        return color;
      case HeartType.empty:
        return Colors.grey.shade600;
    }
  }
}

// 반 하트 제거, full과 empty만 사용
enum HeartType { full, empty }
