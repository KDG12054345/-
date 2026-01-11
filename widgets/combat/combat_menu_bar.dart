import 'package:flutter/material.dart';

/// 전투 화면 하단 메뉴바
/// 
/// 아이템 사용, 도망가기 등의 액션 버튼들을 표시합니다.
class CombatMenuBar extends StatelessWidget {
  const CombatMenuBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMenuButton(
            icon: Icons.shopping_bag,
            label: '아이템',
            onPressed: () {
              // TODO: 아이템 사용 UI 구현
            },
          ),
          _buildMenuButton(
            icon: Icons.shield,
            label: '방어',
            onPressed: () {
              // TODO: 방어 액션 구현
            },
          ),
          _buildMenuButton(
            icon: Icons.run_circle,
            label: '도망',
            onPressed: () {
              // TODO: 도망가기 구현
            },
          ),
          _buildMenuButton(
            icon: Icons.settings,
            label: '설정',
            onPressed: () {
              // TODO: 전투 설정 UI 구현
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


