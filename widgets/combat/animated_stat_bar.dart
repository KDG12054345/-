import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 애니메이션이 적용된 스탯 바 위젯
/// HP, 스태미나 등의 실시간 변화를 부드럽게 표시합니다.
class AnimatedStatBar extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double current;
  final double max;
  final double width;
  final double height;
  final bool showText;
  final bool showPercentage;
  final Duration animationDuration;
  
  const AnimatedStatBar({
    super.key,
    required this.icon,
    required this.color,
    required this.current,
    required this.max,
    this.width = 120,
    this.height = 16,
    this.showText = true,
    this.showPercentage = false,
    this.animationDuration = const Duration(milliseconds: 300),
  });
  
  @override
  State<AnimatedStatBar> createState() => _AnimatedStatBarState();
}

class _AnimatedStatBarState extends State<AnimatedStatBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousValue = 0;
  
  @override
  void initState() {
    super.initState();
    _previousValue = widget.current;
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _animation = Tween<double>(
      begin: _previousValue,
      end: widget.current,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
  }
  
  @override
  void didUpdateWidget(AnimatedStatBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.current != widget.current) {
      _previousValue = oldWidget.current;
      _animation = Tween<double>(
        begin: _previousValue,
        end: widget.current,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ));
      _controller
        ..reset()
        ..forward();
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(widget.icon, size: 14, color: widget.color),
        const SizedBox(width: 4),
        SizedBox(
          width: widget.width,
          height: widget.height,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final currentValue = _animation.value;
              final percentage = widget.max > 0 
                  ? (currentValue / widget.max).clamp(0.0, 1.0) 
                  : 0.0;
              
              return Stack(
                children: [
                  // 배경
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.color.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  
                  // 손실된 부분 표시 (데미지 플래시)
                  if (_previousValue > currentValue)
                    FractionallySizedBox(
                      widthFactor: (_previousValue / widget.max).clamp(0.0, 1.0),
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  
                  // 채워진 부분 (실제 값)
                  FractionallySizedBox(
                    widthFactor: percentage,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.color,
                            widget.color.withOpacity(0.7),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: widget.color.withOpacity(0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // 텍스트
                  if (widget.showText)
                    Center(
                      child: Text(
                        widget.showPercentage
                            ? '${(percentage * 100).toInt()}%'
                            : '${currentValue.toInt()}/${widget.max.toInt()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(blurRadius: 2, color: Colors.black),
                            Shadow(blurRadius: 4, color: Colors.black),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 쿨다운 표시 위젯
class CooldownIndicator extends StatelessWidget {
  final double remaining;
  final double total;
  final double size;
  final Color color;
  
  const CooldownIndicator({
    super.key,
    required this.remaining,
    required this.total,
    this.size = 40,
    this.color = Colors.blue,
  });
  
  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? (remaining / total).clamp(0.0, 1.0) : 0.0;
    
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 원형 진행바
          CustomPaint(
            size: Size(size, size),
            painter: _CooldownPainter(
              percentage: percentage,
              color: color,
            ),
          ),
          
          // 남은 시간 텍스트
          if (remaining > 0)
            Text(
              remaining.toStringAsFixed(1),
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.3,
                fontWeight: FontWeight.bold,
                shadows: const [
                  Shadow(blurRadius: 2, color: Colors.black),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 쿨다운 원형 진행바 페인터
class _CooldownPainter extends CustomPainter {
  final double percentage;
  final Color color;
  
  _CooldownPainter({
    required this.percentage,
    required this.color,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // 배경 원
    final bgPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);
    
    // 쿨다운 진행 (시계방향)
    if (percentage > 0) {
      final progressPaint = Paint()
        ..color = color.withOpacity(0.6)
        ..style = PaintingStyle.fill;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // 12시 방향부터 시작
        2 * math.pi * percentage,
        true,
        progressPaint,
      );
    }
    
    // 테두리
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, borderPaint);
  }
  
  @override
  bool shouldRepaint(_CooldownPainter oldDelegate) {
    return oldDelegate.percentage != percentage;
  }
}

