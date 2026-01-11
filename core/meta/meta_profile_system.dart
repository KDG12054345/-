/// MetaProfile 저장/로드 시스템
///
/// MetaProfile을 디스크에 저장하고 로드합니다.
/// AutosaveSystem과 유사한 구조이지만, 별도의 meta.json 파일을 사용합니다.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'meta_profile.dart';

class MetaProfileSystem {
  final String directoryPath;
  final String fileName;
  
  String? _resolvedPath;
  bool _isDirty = false;  // 저장되지 않은 변경사항이 있는지
  
  MetaProfileSystem({
    this.directoryPath = 'saves',
    this.fileName = 'meta.json',
  });
  
  /// 앱 전용 디렉토리 경로 가져오기
  Future<String> get _savesDirectory async {
    if (_resolvedPath != null) return _resolvedPath!;
    
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      _resolvedPath = '${appDir.path}/$directoryPath';
      return _resolvedPath!;
    } catch (e) {
      // fallback to current directory
      debugPrint('[MetaProfileSystem] Failed to get app directory: $e');
      _resolvedPath = directoryPath;
      return _resolvedPath!;
    }
  }
  
  /// 메타 파일 경로
  Future<String> get _metaPath async => '${await _savesDirectory}/$fileName';
  
  /// 백업 파일 경로
  Future<String> get _bakPath async => '${await _savesDirectory}/$fileName.bak';
  
  /// 임시 파일 경로
  Future<String> get _tmpPath async => '${await _savesDirectory}/.$fileName.tmp';
  
  /// 디렉토리 생성
  Future<void> _ensureDir() async {
    final dirPath = await _savesDirectory;
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      debugPrint('[MetaProfileSystem] Created directory: $dirPath');
    }
  }
  
  /// MetaProfile 저장
  Future<void> save(MetaProfile profile) async {
    try {
      await _ensureDir();
      
      final jsonStr = jsonEncode(profile.toJson());
      final metaPath = await _metaPath;
      final bakPath = await _bakPath;
      final tmpPath = await _tmpPath;
      
      // 1. 임시 파일에 쓰기
      await File(tmpPath).writeAsString(jsonStr, flush: true);
      
      // 2. 기존 파일을 백업으로 이동
      final metaFile = File(metaPath);
      if (await metaFile.exists()) {
        try {
          await metaFile.rename(bakPath);
        } catch (e) {
          debugPrint('[MetaProfileSystem] Failed to create backup: $e');
        }
      }
      
      // 3. 임시 파일을 메인 파일로 이동
      await File(tmpPath).rename(metaPath);
      
      _isDirty = false;
      debugPrint('[MetaProfileSystem] ✅ Saved: $profile');
    } catch (e, stackTrace) {
      debugPrint('[MetaProfileSystem] ❌ Save failed: $e');
      debugPrint('$stackTrace');
      throw Exception('MetaProfile save failed: $e');
    }
  }
  
  /// MetaProfile 로드
  Future<MetaProfile> load() async {
    try {
      await _ensureDir();
      
      final metaPath = await _metaPath;
      final bakPath = await _bakPath;
      
      // 1. 메인 파일 시도
      MetaProfile? profile = await _tryLoadFile(metaPath);
      if (profile != null) {
        debugPrint('[MetaProfileSystem] ✅ Loaded from main file: $profile');
        return profile;
      }
      
      // 2. 백업 파일 시도
      profile = await _tryLoadFile(bakPath);
      if (profile != null) {
        debugPrint('[MetaProfileSystem] ✅ Loaded from backup file: $profile');
        // 백업에서 로드했으면 메인 파일로 다시 저장
        await save(profile);
        return profile;
      }
      
      // 3. 파일이 없으면 새로 생성
      debugPrint('[MetaProfileSystem] ℹ️ No existing profile, creating new');
      final newProfile = const MetaProfile();
      await save(newProfile);
      return newProfile;
    } catch (e, stackTrace) {
      debugPrint('[MetaProfileSystem] ❌ Load failed: $e');
      debugPrint('$stackTrace');
      // 로드 실패 시 기본 프로필 반환
      return const MetaProfile();
    }
  }
  
  /// 파일에서 MetaProfile 로드 시도
  Future<MetaProfile?> _tryLoadFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    
    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return MetaProfile.fromJson(json);
    } catch (e) {
      debugPrint('[MetaProfileSystem] Failed to load $path: $e');
      return null;
    }
  }
  
  /// MetaProfile 삭제 (디버그/테스트용)
  Future<void> delete() async {
    try {
      final metaPath = await _metaPath;
      final bakPath = await _bakPath;
      final tmpPath = await _tmpPath;
      
      for (final path in [metaPath, bakPath, tmpPath]) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          debugPrint('[MetaProfileSystem] Deleted: $path');
        }
      }
      
      _isDirty = false;
    } catch (e) {
      debugPrint('[MetaProfileSystem] Delete failed: $e');
    }
  }
  
  /// MetaProfile 존재 여부 확인
  Future<bool> exists() async {
    try {
      final metaPath = await _metaPath;
      return await File(metaPath).exists();
    } catch (e) {
      return false;
    }
  }
  
  /// dirty 플래그 설정 (나중에 자동 저장용)
  void markDirty() {
    _isDirty = true;
  }
  
  /// dirty 플래그 확인
  bool get isDirty => _isDirty;
}



