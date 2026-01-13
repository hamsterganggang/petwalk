import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_profile.dart';
import '../services/firebase_service.dart';

/// 프로필 데이터 관리 서비스 클래스
class ProfileDataService {
  final FirebaseFirestore _firestore = FirebaseService.getFirestore();
  final FirebaseStorage _storage = FirebaseService.getStorage();
  static const String _collectionName = 'profiles';
  static const String _nicknameIndexCollection = 'nickname_index';

  /// 사용자 프로필 데이터 조회
  Future<UserProfile?> loadProfileData(String uid) async {
    try {
      final docSnapshot = await _firestore
          .collection(_collectionName)
          .doc(uid)
          .get();

      if (!docSnapshot.exists || docSnapshot.data() == null) {
        return null;
      }

      return UserProfile.fromFirestore(docSnapshot);
    } catch (e) {
      print('프로필 데이터 조회 오류: $e');
      rethrow;
    }
  }

  /// 사용자 프로필 생성
  Future<void> createProfile(UserProfile profile) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(profile.uid)
          .set(profile.toMap());

      await _firestore
          .collection(_nicknameIndexCollection)
          .doc(profile.nickname.toLowerCase())
          .set({
        'uid': profile.uid,
        'nickname': profile.nickname,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('프로필 생성 오류: $e');
      rethrow;
    }
  }

  /// 닉네임 업데이트
  Future<void> updateNickname(String uid, String newNickname) async {
    try {
      final currentProfile = await loadProfileData(uid);
      if (currentProfile == null) throw Exception('프로필을 찾을 수 없습니다.');
      if (currentProfile.nickname == newNickname) return;

      final isDuplicate = await checkNicknameDuplicate(newNickname, uid);
      if (isDuplicate) throw Exception('이미 사용 중인 닉네임입니다.');

      await _firestore
          .collection(_collectionName)
          .doc(uid)
          .update({
        'nickname': newNickname,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection(_nicknameIndexCollection).doc(currentProfile.nickname.toLowerCase()).delete();
      await _firestore.collection(_nicknameIndexCollection).doc(newNickname.toLowerCase()).set({
        'uid': uid,
        'nickname': newNickname,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('닉네임 업데이트 오류: $e');
      rethrow;
    }
  }

  /// 닉네임 중복 체크
  Future<bool> checkNicknameDuplicate(String nickname, String? currentUid) async {
    try {
      final docSnapshot = await _firestore
          .collection(_nicknameIndexCollection)
          .doc(nickname.toLowerCase())
          .get();

      if (!docSnapshot.exists) return false;
      final data = docSnapshot.data();
      if (data == null) return false;

      final existingUid = data['uid'] as String?;
      if (currentUid != null && existingUid == currentUid) return false;
      return true;
    } catch (e) {
      print('닉네임 중복 체크 오류: $e');
      rethrow;
    }
  }

  /// 프로필 사진 업로드
  Future<String> uploadProfileImage(String uid, File imageFile) async {
    try {
      final storageRef = _storage.ref().child('profiles/$uid/profile.jpg');
      try { await storageRef.delete(); } catch (_) {}
      await storageRef.putFile(imageFile);
      return await storageRef.getDownloadURL();
    } catch (e) {
      print('프로필 사진 업로드 오류: $e');
      rethrow;
    }
  }

  /// 프로필 사진 URL 업데이트
  Future<void> updateProfilePhotoUrl(String uid, String photoUrl) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(uid)
          .update({
        'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('프로필 사진 URL 업데이트 오류: $e');
      rethrow;
    }
  }

  /// 위치 권한 설정 업데이트
  Future<void> updateLocationEnabled(String uid, bool locationEnabled) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(uid)
          .update({
        'locationEnabled': locationEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('위치 권한 설정 업데이트 오류: $e');
      rethrow;
    }
  }

  /// 프로필 정보 업데이트 (통합)
  Future<void> updateProfile({
    required String uid,
    String? nickname,
    String? bio,
    String? photoUrl,
    bool? locationEnabled,
    bool? isPrivate, // 파라미터 추가
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (nickname != null) {
        final isDuplicate = await checkNicknameDuplicate(nickname, uid);
        if (isDuplicate) throw Exception('이미 사용 중인 닉네임입니다.');

        final currentProfile = await loadProfileData(uid);
        if (currentProfile != null && currentProfile.nickname != nickname) {
          await _firestore.collection(_nicknameIndexCollection).doc(currentProfile.nickname.toLowerCase()).delete();
          await _firestore.collection(_nicknameIndexCollection).doc(nickname.toLowerCase()).set({
            'uid': uid,
            'nickname': nickname,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        updateData['nickname'] = nickname;
      }

      if (photoUrl != null) updateData['photoUrl'] = photoUrl;
      if (bio != null) updateData['bio'] = bio;
      if (locationEnabled != null) updateData['locationEnabled'] = locationEnabled;
      if (isPrivate != null) updateData['isPrivate'] = isPrivate; // 필드 추가

      await _firestore.collection(_collectionName).doc(uid).update(updateData);
    } catch (e) {
      print('프로필 정보 업데이트 오류: $e');
      rethrow;
    }
  }
}
