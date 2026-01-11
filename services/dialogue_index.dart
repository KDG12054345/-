import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class DialogueIndexEntry {
  final String path;
  final int weight;

  const DialogueIndexEntry({
    required this.path,
    required this.weight,
  });

  factory DialogueIndexEntry.fromMap(Map<String, dynamic> map) {
    return DialogueIndexEntry(
      path: map['path'] as String,
      weight: map['weight'] as int? ?? 10,
    );
  }
}

class DialogueIndex {
  static DialogueIndex? _instance;
  static DialogueIndex get instance => _instance ??= DialogueIndex._();
  DialogueIndex._();

  Map<String, List<DialogueIndexEntry>>? _cache;

  /// index.json 로드 및 파일 목록·기본 가중치 제공
  Future<List<DialogueIndexEntry>> getStartEncounters() async {
    if (_cache != null && _cache!.containsKey('start')) {
      return _cache!['start']!;
    }

    try {
      final jsonString = await rootBundle.loadString('assets/dialogue/start/index.json');
      final data = json.decode(jsonString) as Map<String, dynamic>;
      final files = data['files'] as List<dynamic>? ?? [];
      
      final entries = files
          .whereType<Map<String, dynamic>>()
          .map((file) => DialogueIndexEntry.fromMap(file))
          .toList();

      _cache ??= {};
      _cache!['start'] = entries;
      
      debugPrint('[DialogueIndex] Loaded ${entries.length} start encounters');
      return entries;
    } catch (e) {
      debugPrint('[DialogueIndex] Failed to load start index: $e');
      // 폴백: 기존 파일들을 하드코딩으로 반환
      return [
        const DialogueIndexEntry(path: 'assets/dialogue/start/start_001.json', weight: 10),
      ];
    }
  }

  /// 메인 스토리 인카운터 가져오기
  Future<List<DialogueIndexEntry>> getMainEncounters() async {
    return await _loadIndex('assets/dialogue/main/index.json', 'main');
  }

  /// 카테고리별 랜덤 인카운터 가져오기
  /// [category]: 'trap', 'combat', 'meeting' 등
  Future<List<DialogueIndexEntry>> getRandomEncounters(String category) async {
    return await _loadIndex('assets/dialogue/random/$category/index.json', 'random_$category');
  }

  /// 모든 랜덤 인카운터 카테고리 가져오기
  Future<Map<String, List<DialogueIndexEntry>>> getAllRandomEncounters() async {
    final Map<String, List<DialogueIndexEntry>> result = {};
    
    result['trap'] = await getRandomEncounters('trap');
    result['combat'] = await getRandomEncounters('combat');
    result['meeting'] = await getRandomEncounters('meeting');
    
    return result;
  }

  /// 가중치 기반으로 랜덤 카테고리 선택 후 인카운터 선택
  Future<String?> selectRandomEncounter() async {
    try {
      // 1. 카테고리 선택
      final indexData = await rootBundle.loadString('assets/dialogue/random/index.json');
      final data = json.decode(indexData) as Map<String, dynamic>;
      final categories = data['categories'] as List<dynamic>;
      
      if (categories.isEmpty) {
        debugPrint('[DialogueIndex] No categories found');
        return null;
      }
      
      // 카테고리 가중치 기반 선택
      final selectedCategory = _selectByWeight(categories);
      final categoryId = selectedCategory['id'] as String;
      
      debugPrint('[DialogueIndex] Selected category: $categoryId');
      
      // 2. 선택된 카테고리에서 인카운터 선택
      final encounters = await getRandomEncounters(categoryId);
      
      if (encounters.isEmpty) {
        debugPrint('[DialogueIndex] No encounters in category: $categoryId');
        return null;
      }
      
      final selectedEncounter = _selectEncounterByWeight(encounters);
      
      debugPrint('[DialogueIndex] Selected encounter: ${selectedEncounter.path}');
      return selectedEncounter.path;
    } catch (e) {
      debugPrint('[DialogueIndex] Random selection failed: $e');
      return null;
    }
  }

  /// 특정 카테고리에서만 랜덤 인카운터 선택
  Future<String?> selectRandomEncounterFromCategory(String category) async {
    try {
      final encounters = await getRandomEncounters(category);
      
      if (encounters.isEmpty) {
        debugPrint('[DialogueIndex] No encounters in category: $category');
        return null;
      }
      
      final selected = _selectEncounterByWeight(encounters);
      debugPrint('[DialogueIndex] Selected from $category: ${selected.path}');
      return selected.path;
    } catch (e) {
      debugPrint('[DialogueIndex] Selection from $category failed: $e');
      return null;
    }
  }

  /// 가중치 기반 선택 (범용)
  dynamic _selectByWeight(List<dynamic> items) {
    final random = Random();
    final totalWeight = items.fold<int>(
      0,
      (sum, item) => sum + ((item['weight'] as int?) ?? 10),
    );
    
    if (totalWeight <= 0) return items.first;
    
    int randomValue = random.nextInt(totalWeight);
    
    for (final item in items) {
      randomValue -= (item['weight'] as int?) ?? 10;
      if (randomValue < 0) return item;
    }
    
    return items.last;
  }

  /// DialogueIndexEntry 리스트에서 가중치 기반 선택
  DialogueIndexEntry _selectEncounterByWeight(List<DialogueIndexEntry> entries) {
    final random = Random();
    final totalWeight = entries.fold<int>(0, (sum, entry) => sum + entry.weight);
    
    if (totalWeight <= 0) return entries.first;
    
    int randomValue = random.nextInt(totalWeight);
    
    for (final entry in entries) {
      randomValue -= entry.weight;
      if (randomValue < 0) return entry;
    }
    
    return entries.last;
  }

  /// 공통 index.json 로드 헬퍼 메서드
  Future<List<DialogueIndexEntry>> _loadIndex(String path, String cacheKey) async {
    if (_cache != null && _cache!.containsKey(cacheKey)) {
      return _cache![cacheKey]!;
    }

    try {
      final jsonString = await rootBundle.loadString(path);
      final data = json.decode(jsonString) as Map<String, dynamic>;
      final files = data['files'] as List<dynamic>? ?? [];
      
      final entries = files
          .whereType<Map<String, dynamic>>()
          .map((file) => DialogueIndexEntry.fromMap(file))
          .toList();

      _cache ??= {};
      _cache![cacheKey] = entries;
      
      debugPrint('[DialogueIndex] Loaded ${entries.length} $cacheKey encounters');
      return entries;
    } catch (e) {
      debugPrint('[DialogueIndex] Failed to load $cacheKey index from $path: $e');
      return [];
    }
  }

  /// 캐시 초기화
  void clearCache() {
    _cache = null;
  }
}










