/// 다이얼로그 스크린
/// 
/// DialogueWidget과 ChoiceWidget을 통합한 전체 화면 위젯입니다.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dialogue_provider.dart';
import 'dialogue_widget.dart';
import 'choice_widget.dart';

/// 다이얼로그 스크린
/// 
/// 대화 텍스트, 선택지, 진행 버튼을 모두 포함한 완전한 UI입니다.
class DialogueScreen extends StatelessWidget {
  /// 배경색
  final Color? backgroundColor;
  
  /// 앱바 표시 여부
  final bool showAppBar;
  
  /// 앱바 제목
  final String? appBarTitle;
  
  /// 디버그 정보 표시 여부
  final bool showDebugInfo;
  
  /// 진행 버튼 텍스트
  final String continueButtonText;
  
  /// 종료 시 콜백
  final VoidCallback? onDialogueEnd;
  
  /// 에러 시 콜백
  final void Function(Object error)? onError;
  
  /// 커스텀 레이아웃 빌더
  final Widget Function(
    BuildContext context,
    Widget dialogueWidget,
    Widget choiceWidget,
    Widget? continueButton,
  )? layoutBuilder;

  const DialogueScreen({
    super.key,
    this.backgroundColor,
    this.showAppBar = true,
    this.appBarTitle,
    this.showDebugInfo = false,
    this.continueButtonText = '계속',
    this.onDialogueEnd,
    this.onError,
    this.layoutBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: showAppBar
          ? AppBar(
              title: Text(appBarTitle ?? '다이얼로그'),
              actions: [
                if (showDebugInfo)
                  IconButton(
                    icon: const Icon(Icons.bug_report),
                    onPressed: () => _showDebugInfo(context),
                  ),
              ],
            )
          : null,
      body: Consumer<DialogueProvider>(
        builder: (context, provider, child) {
          // 로딩 중
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // 에러
          if (provider.error != null) {
            onError?.call(provider.error!);
            return _buildErrorUI(context, provider.error!);
          }

          // 종료됨
          if (provider.isEnded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onDialogueEnd?.call();
            });
            return _buildEndedUI(context);
          }

          // 실행 중
          if (provider.isRunning) {
            return _buildDialogueUI(context, provider);
          }

          // 기본 (준비 안 됨)
          return _buildInitialUI(context);
        },
      ),
    );
  }

  /// 다이얼로그 UI
  Widget _buildDialogueUI(BuildContext context, DialogueProvider provider) {
    final dialogueWidget = const DialogueWidget();
    final choiceWidget = const ChoiceWidget();
    final continueButton = provider.canContinue
        ? _buildContinueButton(context, provider)
        : null;

    // 커스텀 레이아웃
    if (layoutBuilder != null) {
      return layoutBuilder!(
        context,
        dialogueWidget,
        choiceWidget,
        continueButton,
      );
    }

    // 기본 레이아웃
    return Column(
      children: [
        // 대화 영역 (스크롤 가능)
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                dialogueWidget,
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        // 하단 영역 (선택지 또는 계속 버튼)
        if (provider.hasChoices)
          choiceWidget
        else if (continueButton != null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: continueButton,
          ),
      ],
    );
  }

  /// 계속 버튼
  Widget _buildContinueButton(BuildContext context, DialogueProvider provider) {
    return ElevatedButton(
      onPressed: () => provider.advance(),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
      ),
      child: Text(continueButtonText),
    );
  }

  /// 초기 UI (로드 전)
  Widget _buildInitialUI(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '다이얼로그를 시작하세요',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// 종료 UI
  Widget _buildEndedUI(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Colors.green[400],
          ),
          const SizedBox(height: 16),
          Text(
            '대화가 종료되었습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// 에러 UI
  Widget _buildErrorUI(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              '오류가 발생했습니다',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// 디버그 정보 표시
  void _showDebugInfo(BuildContext context) {
    final provider = context.read<DialogueProvider>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('디버그 정보'),
        content: SingleChildScrollView(
          child: Text(
            provider.getDebugInfo(),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }
}

/// 컴팩트 다이얼로그 스크린 (앱바 없음, 최소 UI)
class CompactDialogueScreen extends StatelessWidget {
  final VoidCallback? onDialogueEnd;

  const CompactDialogueScreen({
    super.key,
    this.onDialogueEnd,
  });

  @override
  Widget build(BuildContext context) {
    return DialogueScreen(
      showAppBar: false,
      onDialogueEnd: onDialogueEnd,
      layoutBuilder: (context, dialogue, choices, continueBtn) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              dialogue,
              const SizedBox(height: 16),
              if (continueBtn != null)
                continueBtn
              else
                choices,
            ],
          ),
        );
      },
    );
  }
}

/// 전체 화면 다이얼로그 (배경 이미지 지원)
class FullscreenDialogueScreen extends StatelessWidget {
  final String? backgroundImage;
  final Color? overlayColor;
  final VoidCallback? onDialogueEnd;

  const FullscreenDialogueScreen({
    super.key,
    this.backgroundImage,
    this.overlayColor,
    this.onDialogueEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 배경 이미지
          if (backgroundImage != null)
            Positioned.fill(
              child: Image.asset(
                backgroundImage!,
                fit: BoxFit.cover,
              ),
            ),

          // 오버레이
          if (overlayColor != null)
            Positioned.fill(
              child: Container(color: overlayColor),
            ),

          // 다이얼로그 UI
          SafeArea(
            child: DialogueScreen(
              showAppBar: false,
              onDialogueEnd: onDialogueEnd,
            ),
          ),
        ],
      ),
    );
  }
}

/// 다이얼로그 빌더 헬퍼
/// 
/// DialogueProvider와 DialogueScreen을 쉽게 통합합니다.
class DialogueBuilder extends StatelessWidget {
  final String dialoguePath;
  final String? fileId;
  final String? startScene;
  final VoidCallback? onDialogueEnd;
  final void Function(Object error)? onError;
  final Widget Function(BuildContext, DialogueProvider)? builder;

  const DialogueBuilder({
    super.key,
    required this.dialoguePath,
    this.fileId,
    this.startScene,
    this.onDialogueEnd,
    this.onError,
    this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => DialogueProvider()
        ..loadAndStart(dialoguePath, fileId: fileId, fromScene: startScene),
      child: builder != null
          ? Consumer<DialogueProvider>(builder: (ctx, provider, _) => builder!(ctx, provider))
          : DialogueScreen(
              onDialogueEnd: onDialogueEnd,
              onError: onError,
            ),
    );
  }
}

