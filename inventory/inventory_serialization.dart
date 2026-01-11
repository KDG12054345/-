import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'inventory_system.dart';
import 'inventory_item.dart';
import 'vector2_int.dart';

/// 인벤토리를 JSON으로 직렬화/역직렬화하는 유틸리티
class InventorySerialization {
  /// 인벤토리를 JSON으로 직렬화
  /// 
  /// 반환 형식:
  /// ```json
  /// {
  ///   "gridSize": {"w": 9, "h": 6},
  ///   "items": [
  ///     {
  ///       "id": "sword_01",
  ///       "name": "초보자의 검",
  ///       "description": "...",
  ///       "baseWidth": 1,
  ///       "baseHeight": 2,
  ///       "iconPath": "assets/items/sword.png",
  ///       "isRotated": false,
  ///       "position": {"x": 2, "y": 0},
  ///       "properties": {"type": "weapon", "attack": 5}
  ///     }
  ///   ],
  ///   "version": "1.0"
  /// }
  /// ```
  static Map<String, dynamic> inventoryToJson(InventorySystem inventory) {
    try {
      final items = inventory.items.map((item) {
        return {
          'id': item.id,
          'name': item.name,
          'description': item.description,
          'baseWidth': item.baseWidth,
          'baseHeight': item.baseHeight,
          'iconPath': item.iconPath,
          // ✅ SSOT: 0/90/180/270
          'rotationDegrees': item.currentRotation,
          // legacy field (older saves/tests)
          'isRotated': item.isRotated,
          // 텍스트형 인벤토리에서는 position 개념이 없으므로 항상 null로 저장
          'position': null,
          'properties': item.properties,
        };
      }).toList();

      return {
        // legacy 키는 유지하되, 텍스트형에서는 의미상 "표시용" 값만 남긴다.
        'gridSize': {'w': inventory.width, 'h': inventory.height},
        'maxWeightUnits': inventory.maxWeightUnits,
        'items': items,
        'version': '2.0', // 텍스트형 인벤토리 + 무게 시스템
      };
    } catch (e, stackTrace) {
      debugPrint('⚠️ [InventorySerialization] Failed to serialize inventory: $e');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  /// JSON에서 인벤토리를 복원
  /// 
  /// 주의사항:
  /// 1. 기존 인벤토리 내용을 모두 지우고 새로 로드합니다
  /// 2. 아이템 배치 순서: 회전 설정 → 배치 시도
  /// 3. 배치 실패한 아이템은 스킵하고 로그에 기록합니다
  /// 4. 모든 아이템 배치 후 시너지를 한 번에 재계산합니다
  /// 
  /// [json]: inventoryToJson()으로 생성한 JSON 데이터
  /// [inventory]: 복원할 대상 InventorySystem 인스턴스
  /// [throwOnError]: true면 배치 실패 시 예외 발생, false면 로그만 출력
  static void inventoryFromJson(
    Map<String, dynamic> json,
    InventorySystem inventory, {
    bool throwOnError = false,
  }) {
    // 백업 생성 (롤백을 위해)
    Map<String, dynamic>? backup;
    try {
      backup = inventoryToJson(inventory);
    } catch (e) {
      debugPrint('⚠️ [InventorySerialization] Failed to create backup: $e');
    }

    try {
      // 버전 확인
      final version = json['version'] as String?;
      final isLegacyV1 = version == null || version == '1.0';
      final isV2 = version == '2.0';
      if (!isLegacyV1 && !isV2) {
        debugPrint('⚠️ [InventorySerialization] Unknown version: $version, attempting to load anyway...');
      }

      // (v2) 무게 상한 복원
      final dynamic maxWeightUnitsRaw = json['maxWeightUnits'];
      if (maxWeightUnitsRaw is int) {
        inventory.maxWeightUnits = maxWeightUnitsRaw;
      } else if (maxWeightUnitsRaw is num) {
        inventory.maxWeightUnits = maxWeightUnitsRaw.toInt();
      }

      // 1. 기존 인벤토리 초기화
      _clearInventory(inventory);
      debugPrint('[InventorySerialization] 🧹 Cleared inventory');

      // 2. 아이템 복원
      final itemsJson = json['items'] as List?;
      if (itemsJson == null || itemsJson.isEmpty) {
        debugPrint('[InventorySerialization] ✅ No items to restore');
        return;
      }

      int successCount = 0;
      int failCount = 0;
      final List<String> failedItems = [];

      for (final itemJson in itemsJson) {
        final itemData = itemJson as Map<String, dynamic>;
        
        try {
          // 아이템 생성
          final item = _itemFromJson(itemData);

          // 텍스트형 인벤토리: position 무시하고 단순 추가
          item.position = null;
          if (inventory.tryAddItem(item)) {
            successCount++;
          } else {
            failCount++;
            failedItems.add('${item.name} (추가 실패)');
          }
        } catch (e) {
          failCount++;
          final itemName = itemData['name'] ?? itemData['id'] ?? 'unknown';
          failedItems.add('$itemName ($e)');
          debugPrint('⚠️ [InventorySerialization] Failed to restore item $itemName: $e');
          
          if (throwOnError) rethrow;
        }
      }

      // 3. 시너지 재계산 (SynergySystem은 아이템 목록 기반이라 별도 처리 불필요)
      // inventory.synergySystem에 updateAllSynergies가 없다면 자동으로 처리됨
      debugPrint('[InventorySerialization] 🔄 Synergies will be recalculated automatically');

      // 4. 결과 리포트
      debugPrint('[InventorySerialization] ✅ Inventory restored: $successCount succeeded, $failCount failed');
      if (failedItems.isNotEmpty) {
        debugPrint('[InventorySerialization] Failed items: ${failedItems.join(", ")}');
      }
      
      if (throwOnError && failCount > 0) {
        throw StateError('Failed to restore $failCount items');
      }

    } catch (e, stackTrace) {
      debugPrint('⚠️ [InventorySerialization] Critical error during inventory load: $e');
      debugPrint('$stackTrace');
      
      // 롤백 시도
      if (backup != null) {
        debugPrint('[InventorySerialization] 🔄 Attempting rollback...');
        try {
          inventoryFromJson(backup, inventory, throwOnError: false);
          debugPrint('[InventorySerialization] ✅ Rollback successful');
        } catch (rollbackError) {
          debugPrint('⚠️ [InventorySerialization] Rollback failed: $rollbackError');
        }
      }
      
      rethrow;
    }
  }

  /// JSON에서 InventoryItem 생성
  static InventoryItem _itemFromJson(Map<String, dynamic> json) {
    final posJson = json['position'];
    // 텍스트형 인벤토리: position은 항상 null로 취급
    final position = posJson != null && posJson is Map
        ? Vector2Int(posJson['x'] as int, posJson['y'] as int)
        : null;

    final propertiesRaw = json['properties'];
    final properties = propertiesRaw != null && propertiesRaw is Map
        ? Map<String, dynamic>.from(propertiesRaw as Map)
        : <String, dynamic>{};

    // rotation 복원 규칙(호환):
    // 1) json.rotationDegrees (0/90/180/270)
    // 2) json.properties['rotation'] (0/90/180/270 또는 0..3 step)
    // 3) json.isRotated (legacy bool)
    int rotationDeg = 0;
    final dynamic rotDegRaw = json['rotationDegrees'];
    if (rotDegRaw is int) {
      rotationDeg = rotDegRaw;
    } else {
      final dynamic propRot = properties['rotation'];
      if (propRot is int) {
        // step(0..3) or degrees(0/90/180/270) 모두 수용
        if (propRot == 0 || propRot == 90 || propRot == 180 || propRot == 270) {
          rotationDeg = propRot;
        } else {
          rotationDeg = (propRot % 4) * 90;
        }
      } else if (json['isRotated'] == true) {
        rotationDeg = 90;
      }
    }

    return InventoryItem(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      baseWidth: json['baseWidth'] as int,
      baseHeight: json['baseHeight'] as int,
      iconPath: json['iconPath'] as String,
      rotationDegrees: rotationDeg,
      isRotated: json['isRotated'] as bool? ?? false, // legacy input
      position: null, // 텍스트형에서는 저장/복원 시 항상 null
      properties: properties,
    );
  }

  /// 인벤토리 완전 초기화
  static void _clearInventory(InventorySystem inventory) {
    final itemsToRemove = List<InventoryItem>.from(inventory.items);
    for (final item in itemsToRemove) {
      inventory.removeItem(item);
    }
  }

  /// JSON 문자열로 직렬화 (파일 저장용)
  static String inventoryToJsonString(InventorySystem inventory) {
    final json = inventoryToJson(inventory);
    return jsonEncode(json);
  }

  /// JSON 문자열에서 역직렬화
  static void inventoryFromJsonString(
    String jsonString,
    InventorySystem inventory, {
    bool throwOnError = false,
  }) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    inventoryFromJson(json, inventory, throwOnError: throwOnError);
  }
}

