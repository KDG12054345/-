/// 다이얼로그 위젯
/// 
/// 대화 텍스트와 화자 이름을 표시합니다.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dialogue_provider.dart';

/// 다이얼로그 텍스트 위젯
class DialogueWidget extends StatelessWidget {
  /// 텍스트 스타일
  final TextStyle? textStyle;
  
  /// 화자 스타일
  final TextStyle? speakerStyle;
  
  /// 패딩
  final EdgeInsets? padding;
  
  /// 배경색
  final Color? backgroundColor;
  
  /// 테두리 반경
  final double? borderRadius;
  
  /// 화자와 텍스트 사이 간격
  final double? spacing;
  
  /// 타이핑 효과 활성화
  final bool enableTypingEffect;
  
  /// 타이핑 효과 속도 (글자당 밀리초)
  final int typingSpeed;
  
  /// 커스텀 빌더
  final Widget Function(BuildContext, String? speaker, String? text)? builder;

  const DialogueWidget({
    super.key,
    this.textStyle,
    this.speakerStyle,
    this.padding,
    this.backgroundColor,
    this.borderRadius,
    this.spacing,
    this.enableTypingEffect = false,
    this.typingSpeed = 50,
    this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DialogueProvider>(
      builder: (context, provider, child) {
        final view = provider.currentView;
        
        // 텍스트가 없으면 빈 위젯
        if (view == null || !view.hasText) {
          return const SizedBox.shrink();
        }

        // 커스텀 빌더 사용
        if (builder != null) {
          return builder!(context, view.speaker, view.text);
        }

        // 기본 UI
        return _buildDefaultUI(context, view.speaker, view.text);
      },
    );
  }

  /// 기본 UI 빌드
  Widget _buildDefaultUI(BuildContext context, String? speaker, String? text) {
    final theme = Theme.of(context);
    
    return Container(
      padding: padding ?? const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.cardColor,
        borderRadius: BorderRadius.circular(borderRadius ?? 8.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 화자 이름
          if (speaker != null && speaker.isNotEmpty) ...[
            Text(
              speaker,
              style: speakerStyle ??
                  theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
            ),
            SizedBox(height: spacing ?? 8.0),
          ],
          
          // 대화 텍스트
          if (text != null && text.isNotEmpty)
            enableTypingEffect
                ? _TypingText(
                    text: text,
                    style: textStyle ?? theme.textTheme.bodyLarge,
                    speed: typingSpeed,
                  )
                : Text(
                    text,
                    style: textStyle ?? theme.textTheme.bodyLarge,
                  ),
        ],
      ),
    );
  }
}

/// 타이핑 효과 텍스트
class _TypingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int speed;

  const _TypingText({
    required this.text,
    this.style,
    this.speed = 50,
  });

  @override
  State<_TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<_TypingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _characterCount;

  @override
  void initState() {
    super.initState();
    _initAnimation();
  }

  @override
  void didUpdateWidget(_TypingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller.reset();
      _initAnimation();
      _controller.forward();
    }
  }

  void _initAnimation() {
    final duration = Duration(milliseconds: widget.text.length * widget.speed);
    
    _controller = AnimationController(
      duration: duration,
      vsync: this,
    );

    _characterCount = StepTween(
      begin: 0,
      end: widget.text.length,
    ).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _characterCount,
      builder: (context, child) {
        final text = widget.text.substring(0, _characterCount.value);
        return Text(
          text,
          style: widget.style,
        );
      },
    );
  }
}

/// 간단한 다이얼로그 텍스트 위젯 (스타일링 최소화)
class SimpleDialogueWidget extends StatelessWidget {
  const SimpleDialogueWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DialogueProvider>(
      builder: (context, provider, child) {
        final view = provider.currentView;
        
        if (view == null || !view.hasText) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (view.speaker != null && view.speaker!.isNotEmpty)
                Text(
                  view.speaker!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              if (view.speaker != null && view.speaker!.isNotEmpty)
                const SizedBox(height: 8),
              if (view.text != null)
                Text(
                  view.text!,
                  style: const TextStyle(fontSize: 14),
                ),
            ],
          ),
        );
      },
    );
  }
}

