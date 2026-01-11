import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../reward/reward_item_factory.dart';
import '../inventory/inventory_item.dart';

/// 아이템 데이터 로드 오류
class ItemLoadError extends Error {
  final String message;
  ItemLoadError(this.message);
  
  @override
  String toString() => 'ItemLoadError: $message';
}

/// 아이템 데이터 저장소 (JSON 로드)
class ItemStore {
  static ItemStore? _instance;
  static ItemStore get instance => _instance ??= ItemStore._();
  ItemStore._();

  final Map<String, Map<String, dynamic>> _cache = {};
  List<InventoryItem>? _allItemsCache;

  /// index.json에서 모든 아이템 목록 로드
  Future<List<InventoryItem>> loadAllItems() async {
    if (_allItemsCache != null) {
      return _allItemsCache!;
    }

    try {
      final jsonString = await rootBundle.loadString('assets/items/index.json');
      final data = json.decode(jsonString) as Map<String, dynamic>;
      final itemFiles = data['items'] as List<dynamic>? ?? [];
      
      final items = <InventoryItem>[];
      
      for (final itemFile in itemFiles) {
        if (itemFile is! String) continue;
        
        try {
          final item = await loadItem(itemFile);
          items.add(item);
        } catch (e) {
          debugPrint('[ItemStore] Failed to load item $itemFile: $e');
          // 개별 아이템 로드 실패는 무시하고 계속 진행
        }
      }
      
      _allItemsCache = items;
      debugPrint('[ItemStore] Loaded ${items.length} items');
      return items;
    } catch (e) {
      debugPrint('[ItemStore] Failed to load items index: $e');
      throw ItemLoadError('Failed to load items index: $e');
    }
  }

  /// 개별 아이템 JSON 파일 로드
  Future<InventoryItem> loadItem(String filename) async {
    final path = 'assets/items/$filename';
    
    // 캐시에서 확인
    if (_cache.containsKey(path)) {
      return _createInventoryItemFromJson(_cache[path]!);
    }

    try {
      final jsonString = await rootBundle.loadString(path);
      final data = json.decode(jsonString) as Map<String, dynamic>;
      
      // 캐시에 저장
      _cache[path] = data;
      
      return _createInventoryItemFromJson(data);
    } catch (e) {
      debugPrint('[ItemStore] Failed to load item from $path: $e');
      throw ItemLoadError('Failed to load item from $path: $e');
    }
  }

  /// JSON 데이터를 InventoryItem으로 변환
  InventoryItem _createInventoryItemFromJson(Map<String, dynamic> json) {
    // 필수 필드 검증
    if (json['id'] == null || json['name'] == null) {
      throw ItemLoadError('Item JSON must have "id" and "name" fields');
    }

    final definition = RewardItemDefinition(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      baseWidth: (json['baseWidth'] as num?)?.toInt() ?? 1,
      baseHeight: (json['baseHeight'] as num?)?.toInt() ?? 1,
      properties: json['properties'] as Map<String, dynamic>? ?? {},
    );

    return RewardItemFactory.createInventoryItemFromReward(definition);
  }

  /// 캐시 초기화
  void clearCache() {
    _cache.clear();
    _allItemsCache = null;
  }
}
