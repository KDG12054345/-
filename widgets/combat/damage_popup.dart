import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 데미지 숫자 팝업 위젯
/// 전투 시 데미지를 숫자로 표시하며 위로 떠오르며 사라집니다.
class DamagePopup extends StatefulWidget {
  final int damage;
  final bool isCritical;
  final bool isHeal;
  final Offset position;
  final VoidCallback? onComplete;
  
  const DamagePopup({
    super.key,
    required this.damage,
    this.isCritical = false,
    this.isHeal = false,
    required this.position,
    this.onComplete,
  });
  
  @override
  State<DamagePopup> createState() => _DamagePopupState();
}

class _DamagePopupState extends State<DamagePopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    // 페이드 아웃 애니메이션
    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_controller);
    
    // 슬라이드 애니메이션 (위로 떠오름)
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -100),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    
    // 스케일 애니메이션 (크리티컬 시 펀치감)
    if (widget.isCritical) {
      _scaleAnimation = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: 0.5, end: 1.5)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 30,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.5, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 70,
        ),
      ]).animate(_controller);
    } else {
      _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );
    }
    
    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx - 40,
      top: widget.position.dy - 40,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: _slideAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: child,
              ),
            ),
          );
        },
        child: _buildDamageText(),
      ),
    );
  }
  
  Widget _buildDamageText() {
    final color = widget.isHeal
        ? Colors.green
        : widget.isCritical
            ? Colors.orange
            : Colors.white;
    
    final fontSize = widget.isCritical ? 32.0 : 24.0;
    final prefix = widget.isHeal ? '+' : '-';
    
    return Text(
      '$prefix${widget.damage}',
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            blurRadius: 8,
            color: Colors.black.withOpacity(0.8),
          ),
          Shadow(
            blurRadius: 4,
            color: color.withOpacity(0.5),
          ),
        ],
      ),
    );
  }
}

/// 데미지 팝업 관리자
/// 여러 데미지 팝업을 관리하고 표시합니다.
class DamagePopupManager extends StatefulWidget {
  final Widget child;
  
  const DamagePopupManager({
    super.key,
    required this.child,
  });
  
  @override
  State<DamagePopupManager> createState() => DamagePopupManagerState();
  
  /// 하위 위젯에서 접근할 수 있는 static 메서드
  static DamagePopupManagerState? of(BuildContext context) {
    return context.findAncestorStateOfType<DamagePopupManagerState>();
  }
}

class DamagePopupManagerState extends State<DamagePopupManager> {
  final List<_PopupEntry> _popups = [];
  int _nextId = 0;
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ..._popups.map((entry) => entry.popup),
      ],
    );
  }
  
  /// 데미지 팝업 표시
  void showDamage({
    required int damage,
    required Offset position,
    bool isCritical = false,
    bool isHeal = false,
  }) {
    final id = _nextId++;
    
    // 랜덤한 좌우 오프셋 추가 (겹침 방지)
    final random = math.Random();
    final offsetX = position.dx + (random.nextDouble() - 0.5) * 40;
    final offsetY = position.dy + (random.nextDouble() - 0.5) * 20;
    final adjustedPosition = Offset(offsetX, offsetY);
    
    final popup = DamagePopup(
      damage: damage,
      isCritical: isCritical,
      isHeal: isHeal,
      position: adjustedPosition,
      onComplete: () => _removePopup(id),
    );
    
    setState(() {
      _popups.add(_PopupEntry(id: id, popup: popup));
    });
  }
  
  void _removePopup(int id) {
    setState(() {
      _popups.removeWhere((entry) => entry.id == id);
    });
  }
}

class _PopupEntry {
  final int id;
  final Widget popup;
  
  _PopupEntry({required this.id, required this.popup});
}

