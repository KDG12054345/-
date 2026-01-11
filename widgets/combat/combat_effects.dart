import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 타격 플래시 효과
/// 피격 시 화면이나 대상이 번쩍이는 효과
class HitFlash extends StatefulWidget {
  final Widget child;
  final bool isActive;
  final Color flashColor;
  final Duration duration;
  
  const HitFlash({
    super.key,
    required this.child,
    this.isActive = false,
    this.flashColor = Colors.white,
    this.duration = const Duration(milliseconds: 200),
  });
  
  @override
  State<HitFlash> createState() => _HitFlashState();
}

class _HitFlashState extends State<HitFlash>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }
  
  @override
  void didUpdateWidget(HitFlash oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isActive && !oldWidget.isActive) {
      _controller.forward(from: 0.0);
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final opacity = 1.0 - _animation.value;
        return Stack(
          children: [
            child!,
            if (widget.isActive && opacity > 0)
              Positioned.fill(
                child: Container(
                  color: widget.flashColor.withOpacity(opacity * 0.6),
                ),
              ),
          ],
        );
      },
      child: widget.child,
    );
  }
}

/// 화면 쉐이크 효과
/// 강한 타격이나 크리티컬 시 화면을 흔듭니다.
class ScreenShake extends StatefulWidget {
  final Widget child;
  final bool isActive;
  final double intensity;
  final Duration duration;
  
  const ScreenShake({
    super.key,
    required this.child,
    this.isActive = false,
    this.intensity = 10.0,
    this.duration = const Duration(milliseconds: 300),
  });
  
  @override
  State<ScreenShake> createState() => _ScreenShakeState();
}

class _ScreenShakeState extends State<ScreenShake>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final math.Random _random = math.Random();
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
  }
  
  @override
  void didUpdateWidget(ScreenShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isActive && !oldWidget.isActive) {
      _controller.forward(from: 0.0);
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_controller.value == 0.0) {
          return child!;
        }
        
        // 진폭이 시간에 따라 감소
        final amplitude = widget.intensity * (1.0 - _controller.value);
        final offsetX = (_random.nextDouble() - 0.5) * 2 * amplitude;
        final offsetY = (_random.nextDouble() - 0.5) * 2 * amplitude;
        
        return Transform.translate(
          offset: Offset(offsetX, offsetY),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// 아이템 사용 효과
/// 아이템 사용 시 간단한 이펙트를 표시합니다.
class ItemUseEffect extends StatefulWidget {
  final Offset position;
  final Color color;
  final IconData icon;
  final VoidCallback? onComplete;
  
  const ItemUseEffect({
    super.key,
    required this.position,
    this.color = Colors.blue,
    this.icon = Icons.auto_awesome,
    this.onComplete,
  });
  
  @override
  State<ItemUseEffect> createState() => _ItemUseEffectState();
}

class _ItemUseEffectState extends State<ItemUseEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotationAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    // 스케일 애니메이션 (작은 것에서 크게)
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    
    // 페이드 애니메이션
    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 70,
      ),
    ]).animate(_controller);
    
    // 회전 애니메이션
    _rotationAnimation = Tween<double>(begin: 0.0, end: math.pi * 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
    
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
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform.rotate(
                angle: _rotationAnimation.value,
                child: Icon(
                  widget.icon,
                  size: 80,
                  color: widget.color,
                  shadows: [
                    Shadow(
                      blurRadius: 20,
                      color: widget.color.withOpacity(0.8),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 이펙트 관리자
/// 전투 화면의 모든 시각 효과를 관리합니다.
class CombatEffectsManager extends StatefulWidget {
  final Widget child;
  
  const CombatEffectsManager({
    super.key,
    required this.child,
  });
  
  @override
  State<CombatEffectsManager> createState() => CombatEffectsManagerState();
  
  static CombatEffectsManagerState? of(BuildContext context) {
    return context.findAncestorStateOfType<CombatEffectsManagerState>();
  }
}

class CombatEffectsManagerState extends State<CombatEffectsManager> {
  final Map<Key, Widget> _effects = {};
  bool _isShaking = false;
  bool _isFlashing = false;
  Color _flashColor = Colors.white;
  
  @override
  Widget build(BuildContext context) {
    return ScreenShake(
      isActive: _isShaking,
      child: HitFlash(
        isActive: _isFlashing,
        flashColor: _flashColor,
        child: Stack(
          children: [
            widget.child,
            ..._effects.values,
          ],
        ),
      ),
    );
  }
  
  /// 화면 쉐이크 트리거
  void triggerShake({double intensity = 10.0}) {
    setState(() {
      _isShaking = true;
    });
    
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        setState(() {
          _isShaking = false;
        });
      }
    });
  }
  
  /// 플래시 효과 트리거
  void triggerFlash({Color color = Colors.white}) {
    setState(() {
      _isFlashing = true;
      _flashColor = color;
    });
    
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        setState(() {
          _isFlashing = false;
        });
      }
    });
  }
  
  /// 아이템 사용 이펙트 표시
  void showItemEffect({
    required Offset position,
    Color color = Colors.blue,
    IconData icon = Icons.auto_awesome,
  }) {
    final effectKey = UniqueKey();
    final effect = ItemUseEffect(
      key: effectKey,
      position: position,
      color: color,
      icon: icon,
      onComplete: () {
        if (mounted) {
          setState(() {
            _effects.remove(effectKey);
          });
        }
      },
    );
    
    setState(() {
      _effects[effectKey] = effect;
    });
  }
  
  void _removeEffect(Widget effect) {
    setState(() {
      _effects.removeWhere((key, value) => value == effect);
    });
  }
}

/// 전투 시작 애니메이션
class CombatStartAnimation extends StatefulWidget {
  final VoidCallback? onComplete;
  
  const CombatStartAnimation({
    super.key,
    this.onComplete,
  });
  
  @override
  State<CombatStartAnimation> createState() => _CombatStartAnimationState();
}

class _CombatStartAnimationState extends State<CombatStartAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.5, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    
    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_controller);
    
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Center(
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.withOpacity(0.8),
                      Colors.orange.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.6),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Text(
                  'FIGHT!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

