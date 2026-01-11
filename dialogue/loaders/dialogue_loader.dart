/// 다이얼로그 로더
/// 
/// JSON 파일을 로드하고 파싱, 검증, 정규화를 거쳐
/// DialogueData 객체로 변환하는 완전한 파이프라인을 제공합니다.

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import '../core/dialogue_data.dart';
import 'schema_validator.dart';
import 'schema_normalizer.dart';

/// 로더 에러
class DialogueLoaderError implements Exception {
  final String message;
  final String? path;
  final Object? cause;

  DialogueLoaderError(this.message, {this.path, this.cause});

  @override
  String toString() {
    final buffer = StringBuffer('DialogueLoaderError: $message');
    if (path != null) buffer.write(' at $path');
    if (cause != null) buffer.write(' (cause: $cause)');
    return buffer.toString();
  }
}

/// 로드 옵션
class DialogueLoadOptions {
  /// 검증 활성화 여부
  final bool validate;
  
  /// 정규화 활성화 여부
  final bool normalize;
  
  /// 캐싱 활성화 여부
  final bool cache;
  
  /// 엄격 모드 (경고도 에러로 처리)
  final bool strict;
  
  /// 상세 로깅 활성화
  final bool verbose;

  const DialogueLoadOptions({
    this.validate = true,
    this.normalize = true,
    this.cache = true,
    this.strict = false,
    this.verbose = false,
  });

  /// 기본 옵션
  static const DialogueLoadOptions defaults = DialogueLoadOptions();

  /// 개발 모드 옵션 (상세 로깅, 검증 강화)
  static const DialogueLoadOptions development = DialogueLoadOptions(
    validate: true,
    normalize: true,
    cache: false, // 개발 중에는 캐시 비활성화
    strict: true,
    verbose: true,
  );

  /// 프로덕션 옵션 (성능 최적화)
  static const DialogueLoadOptions production = DialogueLoadOptions(
    validate: true,
    normalize: true,
    cache: true,
    strict: false,
    verbose: false,
  );
}

/// 다이얼로그 로더
class DialogueLoader {
  final SchemaValidator _validator;
  final SchemaNormalizer _normalizer;
  final DialogueLoadOptions options;

  /// 캐시 (파일 경로 -> DialogueData)
  final Map<String, DialogueData> _cache = {};

  DialogueLoader({
    SchemaValidator? validator,
    SchemaNormalizer? normalizer,
    this.options = DialogueLoadOptions.defaults,
  })  : _validator = validator ?? SchemaValidator(),
        _normalizer = normalizer ?? SchemaNormalizer();

  /// 싱글톤 인스턴스
  static DialogueLoader? _instance;
  static DialogueLoader get instance => _instance ??= DialogueLoader();

  /// 다이얼로그 파일 로드
  /// 
  /// [path] - 에셋 경로 (예: 'assets/dialogue/start/start_001.json')
  /// [fileId] - 파일 식별자 (선택적, 경로에서 자동 생성)
  /// 
  /// 반환: DialogueData 객체
  /// 
  /// 예외:
  /// - DialogueLoaderError: 로드 실패
  /// - DialogueValidationError: 검증 실패
  /// - NormalizationError: 정규화 실패
  Future<DialogueData> loadDialogue(String path, {String? fileId}) async {
    final loadStartTime = DateTime.now();

    try {
      // 1. 캐시 확인
      if (options.cache && _cache.containsKey(path)) {
        if (options.verbose) {
          debugPrint('[DialogueLoader] Cache hit: $path');
        }
        return _cache[path]!;
      }

      if (options.verbose) {
        debugPrint('[DialogueLoader] Loading dialogue from: $path');
      }

      // 2. 파일 로드
      final jsonString = await _loadFile(path);
      
      // 3. JSON 파싱
      final Map<String, dynamic> data = await _parseJson(jsonString, path);

      // 4. 검증
      if (options.validate) {
        await _validateData(data, path);
      }

      // 5. 정규화
      final DialogueData dialogueData;
      if (options.normalize) {
        final effectiveFileId = fileId ?? _generateFileId(path);
        dialogueData = await _normalizeData(data, effectiveFileId, path);
      } else {
        throw DialogueLoaderError(
          'Cannot load without normalization (normalization disabled)',
          path: path,
        );
      }

      // 6. 최종 검증
      if (!dialogueData.validate()) {
        throw DialogueLoaderError(
          'Final validation failed after normalization',
          path: path,
        );
      }

      // 7. 캐시 저장
      if (options.cache) {
        _cache[path] = dialogueData;
      }

      // 8. 완료 로깅
      final loadDuration = DateTime.now().difference(loadStartTime);
      if (options.verbose) {
        debugPrint('[DialogueLoader] Successfully loaded $path in ${loadDuration.inMilliseconds}ms');
        debugPrint('[DialogueLoader]   Scenes: ${dialogueData.scenes.length}');
        debugPrint('[DialogueLoader]   Start scene: ${dialogueData.startSceneId}');
      }

      return dialogueData;
      
    } on DialogueLoaderError {
      rethrow;
    } on DialogueValidationError {
      rethrow;
    } on NormalizationError {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('[DialogueLoader] Unexpected error loading $path: $e');
      debugPrint('[DialogueLoader] Stack trace: $stackTrace');
      throw DialogueLoaderError(
        'Unexpected error during load',
        path: path,
        cause: e,
      );
    }
  }

  /// 여러 다이얼로그 파일을 배치 로드
  /// 
  /// [paths] - 로드할 파일 경로 목록
  /// 
  /// 반환: 경로 -> DialogueData 맵
  /// 
  /// 참고: 하나가 실패해도 나머지는 계속 로드 시도
  Future<Map<String, DialogueData>> loadMultiple(List<String> paths) async {
    final results = <String, DialogueData>{};
    final errors = <String, Object>{};

    for (final path in paths) {
      try {
        final data = await loadDialogue(path);
        results[path] = data;
      } catch (e) {
        errors[path] = e;
        debugPrint('[DialogueLoader] Failed to load $path: $e');
      }
    }

    if (errors.isNotEmpty && options.strict) {
      throw DialogueLoaderError(
        'Failed to load ${errors.length} of ${paths.length} files',
      );
    }

    return results;
  }

  /// 다이얼로그 미리 로드 (프리로딩)
  /// 
  /// [paths] - 프리로드할 파일 경로 목록
  /// 
  /// 캐시에 저장만 하고 결과는 반환하지 않음
  Future<void> preload(List<String> paths) async {
    if (!options.cache) {
      debugPrint('[DialogueLoader] Preload called but cache is disabled');
      return;
    }

    debugPrint('[DialogueLoader] Preloading ${paths.length} dialogue files...');
    
    final preloadStart = DateTime.now();
    await loadMultiple(paths);
    final preloadDuration = DateTime.now().difference(preloadStart);

    debugPrint('[DialogueLoader] Preload completed in ${preloadDuration.inMilliseconds}ms');
    debugPrint('[DialogueLoader] Cache size: ${_cache.length}');
  }

  /// 캐시 클리어
  void clearCache([String? path]) {
    if (path != null) {
      _cache.remove(path);
      if (options.verbose) {
        debugPrint('[DialogueLoader] Cleared cache for: $path');
      }
    } else {
      final count = _cache.length;
      _cache.clear();
      if (options.verbose) {
        debugPrint('[DialogueLoader] Cleared entire cache ($count entries)');
      }
    }
  }

  /// 캐시 상태 조회
  Map<String, String> getCacheInfo() {
    return {
      'size': _cache.length.toString(),
      'enabled': options.cache.toString(),
      'keys': _cache.keys.join(', '),
    };
  }

  // ========== 내부 메서드 ==========

  /// 파일 로드
  Future<String> _loadFile(String path) async {
    try {
      return await rootBundle.loadString(path);
    } catch (e) {
      throw DialogueLoaderError(
        'Failed to load file from assets',
        path: path,
        cause: e,
      );
    }
  }

  /// JSON 파싱
  Future<Map<String, dynamic>> _parseJson(String jsonString, String path) async {
    try {
      final decoded = json.decode(jsonString);
      
      if (decoded is! Map<String, dynamic>) {
        throw DialogueLoaderError(
          'JSON root must be an object, got ${decoded.runtimeType}',
          path: path,
        );
      }

      return decoded;
    } on FormatException catch (e) {
      throw DialogueLoaderError(
        'Invalid JSON syntax',
        path: path,
        cause: e,
      );
    } catch (e) {
      throw DialogueLoaderError(
        'Failed to parse JSON',
        path: path,
        cause: e,
      );
    }
  }

  /// 데이터 검증
  Future<void> _validateData(Map<String, dynamic> data, String path) async {
    if (options.verbose) {
      debugPrint('[DialogueLoader] Validating: $path');
    }

    final result = _validator.validate(data, path);

    if (!result.isValid) {
      // 에러 출력
      result.printAll();
      throw DialogueValidationError(
        'Validation failed with ${result.errors.length} error(s)',
        path: path,
      );
    }

    // 경고가 있고 엄격 모드면 에러로 처리
    if (result.warnings.isNotEmpty && options.strict) {
      result.printAll();
      throw DialogueValidationError(
        'Validation warnings in strict mode (${result.warnings.length} warning(s))',
        path: path,
      );
    }

    // 경고만 있으면 로깅
    if (result.warnings.isNotEmpty && options.verbose) {
      for (final warning in result.warnings) {
        debugPrint('[DialogueLoader] WARNING: $warning');
      }
    }
  }

  /// 데이터 정규화
  Future<DialogueData> _normalizeData(
    Map<String, dynamic> data,
    String fileId,
    String path,
  ) async {
    if (options.verbose) {
      debugPrint('[DialogueLoader] Normalizing: $path');
    }

    try {
      return _normalizer.normalize(data, fileId, path);
    } catch (e) {
      throw DialogueLoaderError(
        'Normalization failed',
        path: path,
        cause: e,
      );
    }
  }

  /// 파일 경로에서 ID 생성
  String _generateFileId(String path) {
    // 'assets/dialogue/start/start_001.json' -> 'start_001'
    final parts = path.split('/');
    final filename = parts.last;
    final nameWithoutExt = filename.replaceAll(RegExp(r'\.[^.]+$'), '');
    return nameWithoutExt;
  }
}

/// 편의 함수: 싱글톤 로더로 파일 로드
Future<DialogueData> loadDialogue(String path, {String? fileId}) {
  return DialogueLoader.instance.loadDialogue(path, fileId: fileId);
}

/// 편의 함수: 여러 파일 배치 로드
Future<Map<String, DialogueData>> loadDialogues(List<String> paths) {
  return DialogueLoader.instance.loadMultiple(paths);
}

/// 편의 함수: 캐시 클리어
void clearDialogueCache([String? path]) {
  DialogueLoader.instance.clearCache(path);
}

