import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../services/profile_data_service.dart';

/// 프로필 상태 관리 클래스
class ProfileStateManager extends ChangeNotifier {
  final ProfileDataService _profileService = ProfileDataService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  UserProfile? _profile;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isUpdating = false;

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isUpdating => _isUpdating;

  /// 프로필 데이터 로드
  Future<void> loadProfileData() async {
    final user = _auth.currentUser;
    if (user == null) {
      _errorMessage = '로그인이 필요합니다.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _profile = await _profileService.loadProfileData(user.uid);
      
      // 프로필이 없으면 기본 프로필 생성
      if (_profile == null) {
        try {
          final newProfile = UserProfile(
            uid: user.uid,
            email: user.email ?? '',
            nickname: user.displayName ?? user.email?.split('@')[0] ?? '사용자',
            photoUrl: user.photoURL,
            locationEnabled: false,
            ///createdAt: DateTime.now(),
           /// updatedAt: DateTime.now(),
          );
          
          await _profileService.createProfile(newProfile);
          _profile = newProfile;
        } catch (createError) {
          _errorMessage = '프로필 생성 중 오류가 발생했습니다: ${createError.toString()}';
          print('프로필 생성 오류: $createError');
        }
      }
    } catch (e) {
      _errorMessage = '프로필을 불러오는 중 오류가 발생했습니다: ${e.toString()}';
      print('프로필 로드 오류: $e');
      // 에러가 발생해도 프로필을 null로 유지하여 재시도 가능하도록 함
      _profile = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 닉네임 업데이트
  Future<bool> updateNickname(String newNickname) async {
    final user = _auth.currentUser;
    if (user == null) {
      _errorMessage = '로그인이 필요합니다.';
      notifyListeners();
      return false;
    }

    if (_profile == null) {
      _errorMessage = '프로필을 먼저 불러와주세요.';
      notifyListeners();
      return false;
    }

    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 닉네임 중복 체크
      final isDuplicate = await _profileService.checkNicknameDuplicate(
        newNickname,
        user.uid,
      );

      if (isDuplicate) {
        _errorMessage = '이미 사용 중인 닉네임입니다.';
        _isUpdating = false;
        notifyListeners();
        return false;
      }

      // 닉네임 업데이트
      await _profileService.updateNickname(user.uid, newNickname);

      // 프로필 새로고침
      await loadProfileData();

      return true;
    } catch (e) {
      _errorMessage = '닉네임 업데이트 중 오류가 발생했습니다: ${e.toString()}';
      print('닉네임 업데이트 오류: $e');
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  /// 프로필 사진 업로드 및 업데이트
  Future<bool> uploadProfileImage(File imageFile) async {
    final user = _auth.currentUser;
    if (user == null) {
      _errorMessage = '로그인이 필요합니다.';
      notifyListeners();
      return false;
    }

    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 이미지 파일 업로드
      final imageUrl = await _profileService.uploadProfileImage(
        user.uid,
        imageFile,
      );

      // 프로필 사진 URL 업데이트
      await _profileService.updateProfilePhotoUrl(user.uid, imageUrl);

      // 프로필 새로고침
      await loadProfileData();

      return true;
    } catch (e) {
      _errorMessage = '프로필 사진 업로드 중 오류가 발생했습니다: ${e.toString()}';
      print('프로필 사진 업로드 오류: $e');
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  /// 프로필 사진 URL 업데이트
  Future<bool> updateProfilePhotoUrl(String? photoUrl) async {
    final user = _auth.currentUser;
    if (user == null) {
      _errorMessage = '로그인이 필요합니다.';
      notifyListeners();
      return false;
    }

    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _profileService.updateProfilePhotoUrl(
        user.uid,
        photoUrl ?? '',
      );

      // 프로필 새로고침
      await loadProfileData();

      return true;
    } catch (e) {
      _errorMessage = '프로필 사진 URL 업데이트 중 오류가 발생했습니다: ${e.toString()}';
      print('프로필 사진 URL 업데이트 오류: $e');
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  /// 위치 권한 설정 업데이트
  Future<bool> updateLocationEnabled(bool enabled) async {
    final user = _auth.currentUser;
    if (user == null) {
      _errorMessage = '로그인이 필요합니다.';
      notifyListeners();
      return false;
    }

    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _profileService.updateLocationEnabled(user.uid, enabled);

      // 프로필 새로고침
      await loadProfileData();

      return true;
    } catch (e) {
      _errorMessage = '위치 권한 설정 업데이트 중 오류가 발생했습니다: ${e.toString()}';
      print('위치 권한 설정 업데이트 오류: $e');
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  /// 프로필 정보 업데이트 (통합)
  Future<bool> updateProfile({
    String? nickname,
    String? photoUrl,
    bool? locationEnabled,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      _errorMessage = '로그인이 필요합니다.';
      notifyListeners();
      return false;
    }

    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _profileService.updateProfile(
        uid: user.uid,
        nickname: nickname,
        photoUrl: photoUrl,
        locationEnabled: locationEnabled,
      );

      // 프로필 새로고침
      await loadProfileData();

      return true;
    } catch (e) {
      _errorMessage = '프로필 업데이트 중 오류가 발생했습니다: ${e.toString()}';
      print('프로필 업데이트 오류: $e');
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  /// 에러 메시지 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// 프로필 새로고침
  Future<void> refresh() async {
    await loadProfileData();
  }
}
