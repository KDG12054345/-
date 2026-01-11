import 'package:flutter/material.dart';

/// 전투 로그 디스플레이 위젯
/// 
/// 전투 중 발생한 이벤트들을 시간순으로 표시합니다.
class CombatLogDisplay extends StatelessWidget {
  final double height;
  
  const CombatLogDisplay({
    super.key,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              const Icon(
                Icons.article,
                size: 16,
                color: Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                '전투 로그',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 4),
          
          // 로그 내용
          Expanded(
            child: SingleChildScrollView(
              reverse: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLogEntry('전투 시작!', Colors.yellow),
                  _buildLogEntry('플레이어가 공격을 준비합니다.', Colors.blue),
                  _buildLogEntry('적이 공격을 준비합니다.', Colors.red),
                  // TODO: 실제 전투 로그 시스템과 연동
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLogEntry(String message, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        message,
        style: TextStyle(
          color: color.withOpacity(0.8),
          fontSize: 11,
        ),
      ),
    );
  }
}


