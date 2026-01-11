import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../app/app_wrapper.dart';
import '../core/game_controller.dart';  // 🆕 추가
import '../core/state/events.dart';     // 🆕 추가

class StartScreen extends StatefulWidget {
  final VoidCallback onStartGame;
  final ThemeConfig themeConfig;

  const StartScreen({
    super.key,
    required this.onStartGame,
    required this.themeConfig,
  });

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    
    return Scaffold(
      body: Container(
        decoration: widget.themeConfig.backgroundImagePath.isNotEmpty
            ? BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(widget.themeConfig.backgroundImagePath),
                  fit: BoxFit.cover,
                ),
              )
            : const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Stack(
            children: [
              // 배경 별들 효과
              _buildStarryBackground(),
              
              // 메인 콘텐츠
              Column(
                children: [
                  // 상단 중앙 타이틀
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _fadeAnimation,
                        builder: (context, child) {
                          return FadeTransition(
                            opacity: _fadeAnimation,
                            child: ScaleTransition(
                              scale: _scaleAnimation,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // 게임 타이틀
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: widget.themeConfig.accentColor.withOpacity(0.5),
                                        width: 2,
                                      ),
                                      boxShadow: AppTheme.glowShadow,
                                    ),
                                    child: Text(
                                      'Fantasy Life',
                                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                        fontSize: widget.themeConfig.titleSize,
                                        color: widget.themeConfig.accentColor,
                                        fontFamily: widget.themeConfig.fontFamily,
                                      ),
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 20),
                                  
                                  // 부제목
                                  Text(
                                    '모험이 시작됩니다',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.white.withOpacity(0.8),
                                      fontWeight: FontWeight.w300,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  
                  // 중간 여백
                  const Expanded(flex: 1, child: SizedBox()),
                  
                  // 하단 중앙 시작 버튼
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _fadeAnimation,
                        builder: (context, child) {
                          return FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 게임 시작 버튼
                                Container(
                                  width: 280,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(30),
                                    gradient: AppTheme.buttonGradient,
                                    boxShadow: AppTheme.buttonShadow,
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(30),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(30),
                                      onTap: () => _handleStartGame(context),  // 🔧 변경
                                      child: const Center(
                                        child: Text(
                                          '게임 시작',
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1a0d2e),
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 30),
                                
                                // 추가 메뉴 버튼들
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildMenuButton('저장된 게임', Icons.save, () {}),
                                    const SizedBox(width: 20),
                                    _buildMenuButton('설정', Icons.settings, () {
                                      appState.navigateToScreen(AppScreen.settings);
                                    }),
                                    const SizedBox(width: 20),
                                    _buildMenuButton('제작진', Icons.info_outline, () {
                                      appState.navigateToScreen(AppScreen.credits);
                                    }),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // �� 추가: 게임 시작 처리 메서드
  void _handleStartGame(BuildContext context) {
    // 1. GameController에 StartGame 이벤트 dispatch (새 게임 시작)
    final gameController = context.read<GameController>();
    gameController.dispatch(const StartGame());
    
    // 2. 게임 화면으로 전환
    widget.onStartGame();
    
    debugPrint('✅ [StartScreen] 새 게임 시작');
  }

  Widget _buildStarryBackground() {
    return Positioned.fill(
      child: CustomPaint(
        painter: StarryBackgroundPainter(),
      ),
    );
  }

  Widget _buildMenuButton(String text, IconData icon, VoidCallback onTap) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Colors.white.withOpacity(0.8),
                size: 28,
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StarryBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    // 별들을 랜덤하게 배치
    for (int i = 0; i < 100; i++) {
      final x = (i * 37) % size.width;
      final y = (i * 73) % size.height;
      final starSize = ((i * 13) % 3 + 1).toDouble();
      
      canvas.drawCircle(Offset(x, y), starSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
