/// 선택지 위젯
/// 
/// 다이얼로그 선택지 목록을 표시하고 선택을 처리합니다.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dialogue_provider.dart';
import '../core/dialogue_data.dart';

/// 선택지 목록 위젯
class ChoiceWidget extends StatelessWidget {
  /// 선택지 간 간격
  final double spacing;
  
  /// 패딩
  final EdgeInsets? padding;
  
  /// 선택지 스타일
  final TextStyle? choiceStyle;
  
  /// 비활성화된 선택지 스타일
  final TextStyle? disabledStyle;
  
  /// 선택지 배경색
  final Color? choiceColor;
  
  /// 비활성화된 선택지 배경색
  final Color? disabledColor;
  
  /// 테두리 반경
  final double? borderRadius;
  
  /// 커스텀 선택지 빌더
  final Widget Function(BuildContext, DialogueChoice, VoidCallback?)? choiceBuilder;
  
  /// 선택 전 콜백
  final Future<bool> Function(DialogueChoice)? onBeforeSelect;
  
  /// 선택 후 콜백
  final void Function(DialogueChoice)? onAfterSelect;

  const ChoiceWidget({
    super.key,
    this.spacing = 8.0,
    this.padding,
    this.choiceStyle,
    this.disabledStyle,
    this.choiceColor,
    this.disabledColor,
    this.borderRadius,
    this.choiceBuilder,
    this.onBeforeSelect,
    this.onAfterSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DialogueProvider>(
      builder: (context, provider, child) {
        final choices = provider.currentChoices;
        
        // 선택지가 없으면 빈 위젯
        if (choices.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: padding ?? const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < choices.length; i++) ...[
                if (i > 0) SizedBox(height: spacing),
                _buildChoice(context, provider, choices[i]),
              ],
            ],
          ),
        );
      },
    );
  }

  /// 선택지 빌드
  Widget _buildChoice(
    BuildContext context,
    DialogueProvider provider,
    DialogueChoice choice,
  ) {
    final isEnabled = choice.enabled;
    
    final onTap = isEnabled
        ? () => _handleChoice(context, provider, choice)
        : null;

    // 커스텀 빌더 사용
    if (choiceBuilder != null) {
      return choiceBuilder!(context, choice, onTap);
    }

    // 기본 UI
    return _buildDefaultChoice(context, choice, onTap, isEnabled);
  }

  /// 기본 선택지 UI
  Widget _buildDefaultChoice(
    BuildContext context,
    DialogueChoice choice,
    VoidCallback? onTap,
    bool isEnabled,
  ) {
    final theme = Theme.of(context);
    
    return Material(
      color: isEnabled
          ? (choiceColor ?? theme.primaryColor.withOpacity(0.1))
          : (disabledColor ?? Colors.grey.withOpacity(0.1)),
      borderRadius: BorderRadius.circular(borderRadius ?? 8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius ?? 8.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  choice.text,
                  style: isEnabled
                      ? (choiceStyle ?? theme.textTheme.bodyLarge)
                      : (disabledStyle ??
                          theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.grey,
                          )),
                ),
              ),
              if (!isEnabled && choice.disabledReason != null)
                Tooltip(
                  message: choice.disabledReason!,
                  child: Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 선택지 처리
  Future<void> _handleChoice(
    BuildContext context,
    DialogueProvider provider,
    DialogueChoice choice,
  ) async {
    try {
      // 선택 전 콜백
      if (onBeforeSelect != null) {
        final shouldProceed = await onBeforeSelect!(choice);
        if (!shouldProceed) return;
      }

      // 선택 처리
      await provider.selectChoice(choice.id);

      // 선택 후 콜백
      onAfterSelect?.call(choice);
    } catch (e) {
      // 에러 표시 (선택적)
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('선택 처리 중 오류: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// 간단한 선택지 위젯 (스타일링 최소화)
class SimpleChoiceWidget extends StatelessWidget {
  const SimpleChoiceWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DialogueProvider>(
      builder: (context, provider, child) {
        final choices = provider.currentChoices;
        
        if (choices.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final choice in choices)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ElevatedButton(
                    onPressed: choice.enabled
                        ? () => provider.selectChoice(choice.id)
                        : null,
                    child: Text(choice.text),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 리스트 타일 스타일 선택지 위젯
class ListTileChoiceWidget extends StatelessWidget {
  final Widget? leading;
  final Widget? trailing;

  const ListTileChoiceWidget({
    super.key,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DialogueProvider>(
      builder: (context, provider, child) {
        final choices = provider.currentChoices;
        
        if (choices.isEmpty) {
          return const SizedBox.shrink();
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: choices.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final choice = choices[index];
            return ListTile(
              enabled: choice.enabled,
              leading: leading,
              trailing: trailing ??
                  (choice.enabled
                      ? const Icon(Icons.arrow_forward_ios, size: 16)
                      : null),
              title: Text(choice.text),
              subtitle: !choice.enabled && choice.disabledReason != null
                  ? Text(
                      choice.disabledReason!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    )
                  : null,
              onTap: choice.enabled
                  ? () => provider.selectChoice(choice.id)
                  : null,
            );
          },
        );
      },
    );
  }
}

/// 번호가 매겨진 선택지 위젯
class NumberedChoiceWidget extends StatelessWidget {
  final TextStyle? numberStyle;
  final Color? numberColor;

  const NumberedChoiceWidget({
    super.key,
    this.numberStyle,
    this.numberColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Consumer<DialogueProvider>(
      builder: (context, provider, child) {
        final choices = provider.currentChoices;
        
        if (choices.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < choices.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Material(
                    color: choices[i].enabled
                        ? theme.primaryColor.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.0),
                    child: InkWell(
                      onTap: choices[i].enabled
                          ? () => provider.selectChoice(choices[i].id)
                          : null,
                      borderRadius: BorderRadius.circular(8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            // 번호
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: choices[i].enabled
                                    ? (numberColor ?? theme.primaryColor)
                                    : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${i + 1}',
                                style: numberStyle ??
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // 텍스트
                            Expanded(
                              child: Text(
                                choices[i].text,
                                style: TextStyle(
                                  color: choices[i].enabled
                                      ? theme.textTheme.bodyLarge?.color
                                      : Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

