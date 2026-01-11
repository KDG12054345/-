import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DialogueChoice {
  final String id;
  final String text;
  final Map<String, dynamic>? next; // {scene?|end?|jump?{file,scene}}
  final bool enabled;
  final String? disabledReason;
  const DialogueChoice({
    required this.id,
    required this.text,
    this.next,
    this.enabled = true,
    this.disabledReason,
  });
}

class DialogueView {
  final String? text; // say일 때 문단
  final List<DialogueChoice> choices; // choice일 때 버튼들
  final bool isEnd;
  const DialogueView({this.text, this.choices = const [], this.isEnd = false});
}

/// 긴 텍스트를 스트리밍처럼 한 op씩 해석하는 소형 해석기
class SimpleDialogueManagerV2 with ChangeNotifier {
  // ---- 3 포인터 상태 ----
  String _currentFilePath = '';
  String _currentSceneId = '';
  int _opIndex = 0;

  // 씬 맵: sceneId -> ops(List of Map)
  final Map<String, List<Map<String, dynamic>>> _scenes = {};

  // 간단한 게임 상태(예시)
  final Map<String, int> _stats = {};
  final Map<String, bool> _flags = {};
  final List<String> _items = [];

  DialogueView _view = const DialogueView();
  DialogueView get view => _view;
  String get currentSceneId => _currentSceneId;

  // --------- 로딩 & 정규화 ----------
  Future<void> loadFile(String filePath) async {
    if (_currentFilePath == filePath && _scenes.isNotEmpty) return;
    final raw = await rootBundle.loadString(filePath);
    final data = json.decode(raw);
    _scenes.clear();
    _normalizeScenes(data);
    _currentFilePath = filePath;
  }

  void _normalizeScenes(dynamic data) {
    // 허용 스키마:
    // 1) {"scenes":[{"id":"scene_1","ops":[...]}, ...]}
    // 2) {"scene_1":{"ops":[...]}, "scene_2":{"ops":[...]}}
    if (data is Map && data['scenes'] is List) {
      for (final e in (data['scenes'] as List)) {
        if (e is Map && e['id'] is String) {
          final id = e['id'] as String;
          final ops = (e['ops'] as List?) ?? const [];
          _scenes[id] = ops.map((x) => Map<String, dynamic>.from(x as Map)).toList();
        }
      }
      return;
    }
    if (data is Map) {
      for (final entry in data.entries) {
        final key = entry.key.toString();
        final v = entry.value;
        if (v is Map && v['ops'] is List) {
          _scenes[key] = (v['ops'] as List)
              .map((x) => Map<String, dynamic>.from(x as Map))
              .toList();
        } else if (v is Map) {
          // 구형 스키마 호환 최소치: {"line":"...","choices":[...]} 등을 ops로 감쌈
          final ops = <Map<String, dynamic>>[];
          if (v['line'] is String) {
            ops.add({'say': v['line']});
          } else if (v['start'] is Map && (v['start']['text'] is String)) {
            ops.add({'say': v['start']['text']});
          }
          if (v['choices'] is List) {
            ops.add({'choice': v['choices']});
          } else if (v['choices'] is Map) {
            // {"choices": {"c1": {"text":"..","next_scene":".."}, ...}}
            final map = Map<String, dynamic>.from(v['choices'] as Map);
            final list = <Map<String, dynamic>>[];
            for (final e in map.entries) {
              final m = Map<String, dynamic>.from(e.value as Map);
              m['id'] = e.key;
              list.add(m);
            }
            ops.add({'choice': list});
          }
          if (ops.isNotEmpty) _scenes[key] = ops;
        }
      }
    }
  }

  // ---------- 진행 제어 ----------
  void setScene(String sceneId) {
    _currentSceneId = sceneId;
    _opIndex = 0;
    _view = const DialogueView();
    notifyListeners();
  }

  void next() {
    if (_currentSceneId.isEmpty) {
      _view = const DialogueView(isEnd: true);
      notifyListeners();
      return;
    }
    final ops = _scenes[_currentSceneId];
    if (ops == null || _opIndex >= ops.length) {
      _view = const DialogueView(isEnd: true);
      notifyListeners();
      return;
    }
    // 자동 진행 루프: say/choice에서만 멈춤
    while (_opIndex < ops.length) {
      final op = ops[_opIndex];
      _opIndex++;
      if (op.containsKey('say')) {
        final text = op['say']?.toString() ?? '';
        _view = DialogueView(text: text, choices: const [], isEnd: false);
        notifyListeners();
        return;
      }
      if (op.containsKey('choice')) {
        final raw = op['choice'];
        final list = <DialogueChoice>[];
        if (raw is List) {
          for (final c in raw) {
            if (c is Map) {
              final m = Map<String, dynamic>.from(c);
              // next_scene -> scene 맵핑
              if (m['next'] is Map == false && m['next_scene'] != null) {
                m['next'] = {'scene': m['next_scene']};
              }
              list.add(DialogueChoice(
                id: (m['id'] ?? m['key'] ?? m['text'] ?? '').toString(),
                text: (m['text'] ?? '').toString(),
                next: (m['next'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)),
                enabled: (m['enabled'] is bool) ? m['enabled'] as bool : true,
                disabledReason: m['disabled_reason']?.toString(),
              ));
            }
          }
        }
        _view = DialogueView(text: null, choices: list, isEnd: false);
        notifyListeners();
        return;
      }
      if (op.containsKey('effect')) {
        _applyEffect(Map<String, dynamic>.from(op['effect'] as Map));
        continue; // 자동 진행
      }
      if (op.containsKey('jump')) {
        final j = Map<String, dynamic>.from(op['jump'] as Map);
        final file = j['file']?.toString();
        final scene = j['scene']?.toString();
        if (file != null && scene != null) {
          _jump(file, scene);
          continue; // 새 씬에서 다시 진행
        }
      }
      if (op['end'] == true) {
        _view = const DialogueView(isEnd: true);
        notifyListeners();
        return;
      }
      // 알 수 없는 op는 스킵
    }
    // ops 끝
    _view = const DialogueView(isEnd: true);
    notifyListeners();
  }

  void choose(String choiceId) {
    final choice = view.choices.where((c) => c.id == choiceId).firstOrNull;
    if (choice == null || choice.enabled == false) return;
    final n = choice.next ?? const {};
    if (n['end'] == true) {
      _currentSceneId = '';
      _view = const DialogueView(isEnd: true);
      notifyListeners();
      return;
    }
    if (n['jump'] is Map) {
      final j = Map<String, dynamic>.from(n['jump'] as Map);
      final file = j['file']?.toString();
      final scene = j['scene']?.toString();
      if (file != null && scene != null) {
        _jump(file, scene);
        next(); // 새 씬에서 진행
        return;
      }
    }
    final scene = (n['scene'] ?? n['next_scene'])?.toString();
    if (scene != null) {
      setScene(scene);
      next();
      return;
    }
  }

  // ---------- 내부 유틸 ----------
  void _applyEffect(Map<String, dynamic> e) {
    // 예시: {"stat":{"hp":-5}, "flag":{"met_guard":true}, "item":{"add":"열쇠"}}
    if (e['stat'] is Map) {
      (e['stat'] as Map).forEach((k, v) {
        final key = k.toString();
        final delta = (v is num) ? v.toInt() : 0;
        _stats[key] = (_stats[key] ?? 0) + delta;
      });
    }
    if (e['flag'] is Map) {
      (e['flag'] as Map).forEach((k, v) {
        _flags[k.toString()] = v == true;
      });
    }
    if (e['item'] is Map) {
      final m = Map<String, dynamic>.from(e['item'] as Map);
      if (m['add'] is String) _items.add(m['add'] as String);
      if (m['remove'] is String) _items.remove(m['remove'] as String);
    }
  }

  void _jump(String file, String scene) {
    _currentFilePath = file;
    _currentSceneId = scene;
    _opIndex = 0;
    _view = const DialogueView();
    // 파일 지연 로딩
    loadFile(file);
  }

  Map<String, dynamic> toSaveState() => {
        'file': _currentFilePath,
        'scene': _currentSceneId,
        'opIndex': _opIndex,
        'stats': Map<String, int>.from(_stats),
        'flags': Map<String, bool>.from(_flags),
        'items': List<String>.from(_items),
      };

  void fromSaveState(Map<String, dynamic> m) {
    _currentFilePath = (m['file'] ?? '').toString();
    _currentSceneId = (m['scene'] ?? '').toString();
    _opIndex = (m['opIndex'] is int) ? m['opIndex'] as int : 0;
    _stats
      ..clear()
      ..addAll((m['stats'] as Map?)?.cast<String, int>() ?? {});
    _flags
      ..clear()
      ..addAll((m['flags'] as Map?)?.cast<String, bool>() ?? {});
    _items
      ..clear()
      ..addAll((m['items'] as List?)?.cast<String>() ?? const []);
    _view = const DialogueView();
    notifyListeners();
  }
}

// firstOrNull 확장 (Dart 표준에 없음)
extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}






























