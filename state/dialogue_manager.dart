import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

class DialogueChoice {
  final String id;
  final String text;
  final String? next;

  const DialogueChoice({required this.id, required this.text, this.next});

  factory DialogueChoice.fromMap(Map<String, dynamic> m) =>
      DialogueChoice(id: m['id'], text: m['text'], next: m['next']);
}

class DialogueManager with ChangeNotifier {
  Map<String, dynamic> _dialogue = const {};
  String? _currentSceneId;

  // 디버깅용 getter 추가
  String? get currentSceneId => _currentSceneId;
  Map<String, dynamic> get dialogueData => _dialogue;

  Future<void> loadDialogue(String assetPath) async {
    try {
      debugPrint('[DialogueManager] Loading dialogue from: $assetPath');
      final raw = await rootBundle.loadString(assetPath);
      debugPrint('[DialogueManager] Raw JSON length: ${raw.length}');
      _dialogue = json.decode(raw) as Map<String, dynamic>;
      debugPrint('[DialogueManager] Parsed dialogue keys: ${_dialogue.keys}');
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('[DialogueManager] Failed to load dialogue: $e');
      debugPrint('[DialogueManager] Stack trace: $stackTrace');
      rethrow;
    }
  }

  void setScene(String sceneId) {
    debugPrint('[DialogueManager] Setting scene to: $sceneId');
    _currentSceneId = sceneId;
    debugPrint('[DialogueManager] Current scene ID set to: $_currentSceneId');
    notifyListeners();
  }

  String showLine([String? _]) {
    final id = _currentSceneId;
    debugPrint('[DialogueManager] showLine called, current scene: $id');
    if (id == null) {
      debugPrint('[DialogueManager] No current scene set, returning empty string');
      return '';
    }
    final scenes = _dialogue['scenes'] as Map?;
    debugPrint('[DialogueManager] Available scenes: ${scenes?.keys}');
    final scene = scenes?[id] as Map<String, dynamic>?;
    debugPrint('[DialogueManager] Found scene data: $scene');
    final line = (scene?['line'] as String?) ?? '';
    debugPrint('[DialogueManager] Returning line: "$line"');
    return line;
  }

  List<DialogueChoice> getChoices() {
    final id = _currentSceneId;
    debugPrint('[DialogueManager] getChoices called, current scene: $id');
    if (id == null) return const [];
    final scenes = _dialogue['scenes'] as Map?;
    final scene = scenes?[id] as Map<String, dynamic>?;
    final list = (scene?['choices'] as List?) ?? const [];
    debugPrint('[DialogueManager] Found choices list: $list');
    final choices = list
        .map((e) => DialogueChoice.fromMap(e as Map<String, dynamic>))
        .toList();
    debugPrint('[DialogueManager] Parsed ${choices.length} choices');
    return choices;
  }

  void handleChoice(String choiceId) {
    debugPrint('[DialogueManager] Handling choice: $choiceId');
    final choice = getChoices().firstWhere(
      (c) => c.id == choiceId,
      orElse: () => const DialogueChoice(id: 'noop', text: ''),
    );
    final next = choice.next;
    debugPrint('[DialogueManager] Choice leads to: $next');
    if (next == null) return;
    _currentSceneId = next == 'end' ? null : next;
    debugPrint('[DialogueManager] New scene: $_currentSceneId');
    notifyListeners();
  }
}
