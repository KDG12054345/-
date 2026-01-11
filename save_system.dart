import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'event_system.dart';
import 'branch_system.dart';
import 'core/character/character_models.dart';

/// 저장/불러오기에서 발생하는 오류 코드
enum SaveLoadErrorCode {
  fileNotFound,
  readFailed,
  invalidJson,
}

/// 저장/불러오기 오류 (타입/메시지를 명확히 보장)
class SaveLoadException implements Exception {
  final SaveLoadErrorCode code;
  final String message;
  final Object? cause;

  SaveLoadException(this.code, this.message, {this.cause});

  @override
  String toString() => 'SaveLoadException(code=$code, message=$message, cause=$cause)';
}

/// 저장 데이터를 표현하는 클래스
class SaveData {
  final DateTime timestamp;
  final String currentScene;
  final Map<String, int> stats;
  final List<String> items;  // 📦 보관함 아이템 (배치되지 않은 것들)
  final Map<String, bool> flags;
  final List<Map<String, dynamic>> branchHistory;
  final Map<String, dynamic>? inventory;  // 🎒 인벤토리 그리드 (배치된 아이템들)
  final Map<String, dynamic>? player;     // 🎭 플레이어 캐릭터 정보 (생명력, 정신력, 능력치, 특성)

  const SaveData({
    required this.timestamp,
    required this.currentScene,
    required this.stats,
    required this.items,
    required this.flags,
    required this.branchHistory,
    this.inventory,  // 선택적 필드 (하위 호환성)
    this.player,     // 선택적 필드 (하위 호환성)
  });

  // JSON 직렬화
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'currentScene': currentScene,
      'stats': stats,
      'items': items,
      'flags': flags,
      'branchHistory': branchHistory,
      if (inventory != null) 'inventory': inventory,  // inventory가 있을 때만 포함
      if (player != null) 'player': player,           // player가 있을 때만 포함
    };
  }

  // JSON 역직렬화
  factory SaveData.fromJson(Map<String, dynamic> json) {
    return SaveData(
      timestamp: DateTime.parse(json['timestamp'] as String),
      currentScene: json['currentScene'] as String,
      stats: Map<String, int>.from(json['stats'] as Map),
      items: List<String>.from(json['items'] as List),
      flags: Map<String, bool>.from(json['flags'] as Map),
      branchHistory: List<Map<String, dynamic>>.from(json['branchHistory'] as List),
      inventory: json['inventory'] as Map<String, dynamic>?,  // 선택적 필드 (하위 호환성)
      player: json['player'] as Map<String, dynamic>?,        // 선택적 필드 (하위 호환성)
    );
  }
  
  /// Player 객체를 JSON으로 직렬화하는 헬퍼 메서드
  static Map<String, dynamic> playerToJson(Player player) {
    return {
      'strength': player.strength,
      'agility': player.agility,
      'intelligence': player.intelligence,
      'charisma': player.charisma,
      'vitality': player.vitality,
      'sanity': player.sanity,
      'maxVitality': player.maxVitality,
      'maxSanity': player.maxSanity,
      'traits': player.traits.map((trait) => {
        'id': trait.id,
        'name': trait.name,
        'description': trait.description,
        'oppositeIds': trait.oppositeIds,
        'slotModifier': trait.slotModifier,
        'effectType': trait.effectType.toString(),
        'effectParams': trait.effectParams,
      }).toList(),
    };
  }
  
  /// JSON에서 Player 객체를 복원하는 헬퍼 메서드
  static Player? playerFromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    
    try {
      // traits 복원
      final traitsJson = json['traits'] as List?;
      final traits = traitsJson?.map((traitJson) {
        final effectTypeStr = traitJson['effectType'] as String;
        final effectType = TraitEffectType.values.firstWhere(
          (e) => e.toString() == effectTypeStr,
          orElse: () => TraitEffectType.none,
        );
        
        return Trait(
          id: traitJson['id'] as String,
          name: traitJson['name'] as String,
          description: traitJson['description'] as String,
          oppositeIds: List<String>.from(traitJson['oppositeIds'] as List? ?? []),
          slotModifier: traitJson['slotModifier'] as int? ?? 0,
          effectType: effectType,
          effectParams: traitJson['effectParams'] as Map<String, dynamic>?,
        );
      }).toList() ?? [];
      
      return Player(
        strength: json['strength'] as int,
        agility: json['agility'] as int,
        intelligence: json['intelligence'] as int,
        charisma: json['charisma'] as int,
        vitality: json['vitality'] as int,
        sanity: json['sanity'] as int,
        maxVitality: json['maxVitality'] as int,
        maxSanity: json['maxSanity'] as int,
        traits: traits,
      );
    } catch (e) {
      debugPrint('⚠️ [SaveData] Failed to parse player data: $e');
      return null;
    }
  }
}

/// 저장 시스템 관리 클래스
class SaveSystem extends ChangeNotifier {
  final String _saveFilePath;
  
  SaveSystem({required String saveFilePath}) : _saveFilePath = saveFilePath;

  // 안전한 저장 디렉토리 생성 (public으로 변경하여 DialogueManager에서 사용 가능)
  Future<String> getSafeFilePath() async {
    try {
      // Android/iOS에서 앱 문서 디렉토리 사용
      final directory = await getApplicationDocumentsDirectory();
      final saveDir = Directory('${directory.path}/saves');
      
      // 디렉토리가 없으면 생성
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }
      
      return '${saveDir.path}/save.json';
    } catch (e) {
      // 폴백: 임시 디렉토리 사용
      debugPrint('⚠️ 문서 디렉토리 사용 실패, 임시 디렉토리 사용: $e');
      final tempDir = await getTemporaryDirectory();
      return '${tempDir.path}/save.json';
    }
  }

  // 게임 상태 저장
  Future<void> saveGame({
    required GameState gameState,
    required List<BranchPoint> branchHistory,
    required String currentScene,
  }) async {
    final saveData = SaveData(
      timestamp: DateTime.now(),
      currentScene: currentScene,
      stats: gameState.stats,
      items: gameState.items,
      flags: gameState.flags,
      branchHistory: [...branchHistory.map((branch) => branch.gameState)],
    );

    final filePath = await getSafeFilePath();
    final file = File(filePath);
    await file.writeAsString(jsonEncode(saveData.toJson()));
    notifyListeners();
  }

  /// 저장 루트(Map<String,dynamic>)를 그대로 기록합니다.
  /// - DialogueManager가 확장 필드(예: traits/inventory/player 등)를 포함해 구성한 root를 전달할 수 있습니다.
  /// - "스키마 변경 금지" 정책을 깨지 않기 위해, 여기서는 임의로 필드를 추가/삭제하지 않습니다.
  Future<void> writeSaveRoot(Map<String, dynamic> root) async {
    final filePath = await getSafeFilePath();
    final file = File(filePath);
    await file.writeAsString(jsonEncode(root));
    notifyListeners();
  }

  Map<String, dynamic> _toStringKeyedMap(dynamic decoded) {
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      final result = <String, dynamic>{};
      decoded.forEach((k, v) {
        if (k is String) result[k] = v;
      });
      return result;
    }
    return <String, dynamic>{};
  }

  List<String> _coerceStringList(dynamic raw) {
    if (raw is List) {
      return raw.whereType<String>().toList();
    }
    return <String>[];
  }

  Map<String, int> _coerceStats(dynamic raw) {
    if (raw is Map) {
      final result = <String, int>{};
      raw.forEach((k, v) {
        if (k is String && v is num) result[k] = v.toInt();
      });
      return result;
    }
    return <String, int>{};
  }

  Map<String, bool> _coerceFlags(dynamic raw) {
    if (raw is Map) {
      final result = <String, bool>{};
      raw.forEach((k, v) {
        if (k is String && v is bool) result[k] = v;
      });
      return result;
    }
    return <String, bool>{};
  }

  List<Map<String, dynamic>> _coerceBranchHistory(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  DateTime _coerceTimestamp(dynamic raw) {
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  /// 저장 데이터를 "최신/정규화된 루트(Map)"로 반환합니다.
  /// - 기본값 보장: stats={}, flags={}, items=[], traits=[], currentScene=""
  /// - 파싱/읽기 오류 시: SaveLoadException(code,message)로 명확히 실패
  /// - (버전이 존재한다면) 여기서만 마이그레이션 수행해야 합니다. (현재는 TODO)
  Future<Map<String, dynamic>?> loadGameNormalizedRoot() async {
    final filePath = await getSafeFilePath();
    final file = File(filePath);
    if (!await file.exists()) return null;

    dynamic decoded;
    try {
      final jsonString = await file.readAsString();
      decoded = jsonDecode(jsonString);
    } catch (e) {
      throw SaveLoadException(
        SaveLoadErrorCode.readFailed,
        '저장 파일을 읽을 수 없습니다',
        cause: e,
      );
    }

    if (decoded is! Map) {
      throw SaveLoadException(
        SaveLoadErrorCode.invalidJson,
        '저장 파일 형식이 올바르지 않습니다',
        cause: decoded,
      );
    }

    // 키를 String으로 안전 변환(비-문자열 키는 무시)
    final root = _toStringKeyedMap(decoded);

    // TODO(마이그레이션): save versioning이 도입되면 여기에서만 구버전 -> 최신 변환을 수행합니다.

    // 누락 필드 기본값 채움 (하위 호환성)
    root.putIfAbsent('stats', () => <String, dynamic>{});
    root.putIfAbsent('flags', () => <String, dynamic>{});
    root.putIfAbsent('items', () => <dynamic>[]);
    root.putIfAbsent('traits', () => <dynamic>[]); // 구버전 세이브에는 없을 수 있음
    root.putIfAbsent('currentScene', () => '');    // 구버전 세이브에는 없을 수 있음
    root.putIfAbsent('branchHistory', () => <dynamic>[]);
    root.putIfAbsent('timestamp', () => DateTime.now().toIso8601String());

    // NOTE(policy): items는 기본적으로 중복 제거하지 않습니다(스택형 아이템 가능성).
    // TODO(policy): "비-스택(non-stackable)" 정책이 확정되면 그때만 로드 시 dedupe를 고려합니다.

    // 타입이 깨진 경우도 로드가 크래시나지 않도록 보수적으로 정리
    if (root['stats'] is! Map) root['stats'] = <String, dynamic>{};
    if (root['flags'] is! Map) root['flags'] = <String, dynamic>{};
    if (root['items'] is! List) root['items'] = <dynamic>[];
    if (root['traits'] is! List) root['traits'] = <dynamic>[];
    if (root['branchHistory'] is! List) root['branchHistory'] = <dynamic>[];
    if (root['currentScene'] is! String) root['currentScene'] = '';
    if (root['timestamp'] is! String) root['timestamp'] = DateTime.now().toIso8601String();
    if (root.containsKey('inventory') && root['inventory'] != null && root['inventory'] is! Map) {
      root['inventory'] = null;
    }
    if (root.containsKey('player') && root['player'] != null && root['player'] is! Map) {
      root['player'] = null;
    }

    return root;
  }

  // 게임 상태 불러오기
  Future<SaveData?> loadGame() async {
    final root = await loadGameNormalizedRoot();
    if (root == null) return null;

    // SaveData.fromJson은 구버전 누락 필드에서 예외가 날 수 있어, 여기서 안전하게 복원합니다.
    return SaveData(
      timestamp: _coerceTimestamp(root['timestamp']),
      currentScene: (root['currentScene'] is String) ? (root['currentScene'] as String) : '',
      stats: _coerceStats(root['stats']),
      items: _coerceStringList(root['items']),
      flags: _coerceFlags(root['flags']),
      branchHistory: _coerceBranchHistory(root['branchHistory']),
      inventory: (root['inventory'] is Map) ? Map<String, dynamic>.from(root['inventory'] as Map) : null,
      player: (root['player'] is Map) ? Map<String, dynamic>.from(root['player'] as Map) : null,
    );
  }

  // 저장 파일 존재 여부 확인
  Future<bool> hasSaveFile() async {
    final filePath = await getSafeFilePath();
    final file = File(filePath);
    return await file.exists();
  }

  // 저장 파일 삭제
  Future<void> deleteSave() async {
    final filePath = await getSafeFilePath();
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
      notifyListeners();
    }
  }
} 