import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class AutosaveMeta {
  final String runId;
  final int commitIndex;
  final String lastEventId;
  final int seed;
  final DateTime timestamp;

  const AutosaveMeta({
    required this.runId,
    required this.commitIndex,
    required this.lastEventId,
    required this.seed,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'runId': runId,
        'commitIndex': commitIndex,
        'lastEventId': lastEventId,
        'seed': seed,
        'timestamp': timestamp.toIso8601String(),
      };

  static AutosaveMeta fromJson(Map<String, dynamic> json) {
    return AutosaveMeta(
      runId: json['runId'] as String,
      commitIndex: (json['commitIndex'] as num).toInt(),
      lastEventId: json['lastEventId'] as String,
      seed: (json['seed'] as num).toInt(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

class AutosaveSystem {
  final String directoryPath;
  final String baseName;

  AutosaveSystem({
    this.directoryPath = 'saves',
    this.baseName = 'autosave.json',
  });

  String get _primaryPath => '$directoryPath/$baseName';
  String get _bak1Path => '$directoryPath/autosave.bak1.json';
  String get _bak2Path => '$directoryPath/autosave.bak2.json';
  String get _tmpPath => '$directoryPath/.autosave.tmp';

  static int _fnv1a32(String input) {
    const int prime = 0x01000193;
    int hash = 0x811C9DC5;
    final bytes = utf8.encode(input);
    for (final b in bytes) {
      hash ^= b;
      hash = (hash * prime) & 0xFFFFFFFF;
    }
    return hash;
  }

  Map<String, dynamic> _envelope({
    required Map<String, dynamic> data,
    required AutosaveMeta meta,
  }) {
    final envelope = <String, dynamic>{
      'meta': meta.toJson(),
      'data': data,
    };
    final preHash = jsonEncode({'meta': envelope['meta'], 'data': envelope['data']});
    final hash = _fnv1a32(preHash);
    envelope['hash'] = hash.toRadixString(16).padLeft(8, '0');
    return envelope;
  }

  bool _verifyEnvelope(Map<String, dynamic> env) {
    try {
      final meta = env['meta'] as Map<String, dynamic>;
      final data = env['data'];
      final hashStr = env['hash'] as String;
      final preHash = jsonEncode({'meta': meta, 'data': data});
      final expect = _fnv1a32(preHash).toRadixString(16).padLeft(8, '0');
      return expect == hashStr;
    } catch (_) {
      return false;
    }
  }

  void _ensureDir() {
    final dir = Directory(directoryPath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }

  void saveSync({
    required Map<String, dynamic> data,
    required AutosaveMeta meta,
  }) {
    _ensureDir();
    final env = _envelope(data: data, meta: meta);
    final jsonStr = jsonEncode(env);

    File(_tmpPath).writeAsStringSync(jsonStr, flush: true);

    final bak2 = File(_bak2Path);
    final bak1 = File(_bak1Path);
    final primary = File(_primaryPath);
    if (bak2.existsSync()) {
      try { bak2.deleteSync(); } catch (_) {}
    }
    if (bak1.existsSync()) {
      try { bak1.renameSync(_bak2Path); } catch (_) {}
    }
    if (primary.existsSync()) {
      try { primary.renameSync(_bak1Path); } catch (_) {}
    }

    final tmp = File(_tmpPath);
    if (File(_primaryPath).existsSync()) {
      try { File(_primaryPath).deleteSync(); } catch (_) {}
    }
    tmp.renameSync(_primaryPath);
  }

  Map<String, dynamic>? _tryLoadFile(String path) {
    final f = File(path);
    if (!f.existsSync()) return null;
    try {
      final content = f.readAsStringSync();
      final env = jsonDecode(content) as Map<String, dynamic>;
      if (_verifyEnvelope(env)) {
        return env;
      }
    } catch (e, s) {
      debugPrint('[AutosaveSystem] load failed for $path: $e');
      debugPrint('$s');
    }
    return null;
  }

  ({AutosaveMeta meta, Map<String, dynamic> data})? loadLatest() {
    final candidates = [_primaryPath, _bak1Path, _bak2Path];
    for (final p in candidates) {
      final env = _tryLoadFile(p);
      if (env != null) {
        final meta = AutosaveMeta.fromJson(env['meta'] as Map<String, dynamic>);
        final data = env['data'] as Map<String, dynamic>;
        return (meta: meta, data: data);
      }
    }
    return null;
  }

  void deleteAll() {
    for (final p in [_primaryPath, _bak1Path, _bak2Path, _tmpPath]) {
      final f = File(p);
      if (f.existsSync()) {
        try { f.deleteSync(); } catch (_) {}
      }
    }
  }
}
