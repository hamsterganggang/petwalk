import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../services/profile_data_service.dart';
import '../services/follow_service.dart';

class ProfileStateManager extends ChangeNotifier {
  final ProfileDataService _profileService = ProfileDataService();
  final FollowService _followService = FollowService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  UserProfile? _profile;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isUpdating = false;

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isUpdating => _isUpdating;

  int get followers => _profile?.followers ?? 0;
  int get following => _profile?.following ?? 0;

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

      if (_profile == null) {
        try {
          final newProfile = UserProfile(
            uid: user.uid,
            email: user.email ?? '',
            nickname: user.displayName ?? user.email?.split('@')[0] ?? '사용자',
            photoUrl: user.photoURL,
            bio: '',
            locationEnabled: false,
            followers: 0,
            following: 0,
          );

          await _profileService.createProfile(newProfile);
          _profile = newProfile;
        } catch (createError) {
          _errorMessage = '프로필 생성 중 오류가 발생했습니다: ${createError.toString()}';
        }
      }
    } catch (e) {
      _errorMessage = '프로필을 불러오는 중 오류가 발생했습니다: ${e.toString()}';
      _profile = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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

      await _profileService.updateNickname(user.uid, newNickname);
      await loadProfileData();
      return true;
    } catch (e) {
      _errorMessage = '닉네임 업데이트 중 오류가 발생했습니다: ${e.toString()}';
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

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
      final imageUrl = await _profileService.uploadProfileImage(
        user.uid,
        imageFile,
      );
      await _profileService.updateProfilePhotoUrl(user.uid, imageUrl);
      await loadProfileData();
      return true;
    } catch (e) {
      _errorMessage = '프로필 사진 업로드 중 오류가 발생했습니다: ${e.toString()}';
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

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
      await loadProfileData();
      return true;
    } catch (e) {
      _errorMessage = '프로필 사진 URL 업데이트 중 오류가 발생했습니다: ${e.toString()}';
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

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
      await loadProfileData();
      return true;
    } catch (e) {
      _errorMessage = '위치 권한 설정 업데이트 중 오류가 발생했습니다: ${e.toString()}';
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile({
    String? nickname,
    String? bio,
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
        bio: bio,
        photoUrl: photoUrl,
        locationEnabled: locationEnabled,
      );
      await loadProfileData();
      return true;
    } catch (e) {
      _errorMessage = '프로필 업데이트 중 오류가 발생했습니다: ${e.toString()}';
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    await loadProfileData();
  }

  Future<bool> followUser(String targetUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      _errorMessage = '로그인이 필요합니다.';
      notifyListeners();
      return false;
    }

    try {
      await _followService.toggleFollowStatus(currentUserId, targetUserId, false);

      if (_profile != null) {
        _profile = _profile!.copyWith(following: _profile!.following + 1);
        notifyListeners();
      }

      _refreshProfileInBackground();
      return true;
    } catch (e) {
      _errorMessage = '팔로우 중 오류가 발생했습니다: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> unfollowUser(String targetUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      _errorMessage = '로그인이 필요합니다.';
      notifyListeners();
      return false;
    }

    try {
      await _followService.toggleFollowStatus(currentUserId, targetUserId, true);

      if (_profile != null) {
        final currentFollowing = _profile!.following;
        _profile = _profile!.copyWith(
          following: currentFollowing > 0 ? currentFollowing - 1 : 0,
        );
        notifyListeners();
      }

      _refreshProfileInBackground();
      return true;
    } catch (e) {
      _errorMessage = '언팔로우 중 오류가 발생했습니다: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<void> _refreshProfileInBackground() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final updatedProfile = await _profileService.loadProfileData(user.uid);
        if (updatedProfile != null) {
          _profile = updatedProfile;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('백그라운드 프로필 새로고침 오류: $e');
    }
  }

  Future<bool> isFollowing(String targetUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return false;
    return await _followService.isFollowing(currentUserId, targetUserId);
  }

  Future<List<UserProfile>> getFollowers(String userId) async {
    return await _followService.getFollowers(userId);
  }

  Future<List<UserProfile>> getFollowing(String userId) async {
    return await _followService.getFollowing(userId);
  }
}