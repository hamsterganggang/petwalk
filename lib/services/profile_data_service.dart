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
  /// 
  /// [uid] 사용자 ID
  /// 반환: UserProfile 또는 null
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
  ///
  /// [profile] 생성할 프로필 데이터
  Future<void> createProfile(UserProfile profile) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(profile.uid)
          .set(profile.toMap());

      // 닉네임 인덱스에도 추가
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
  ///
  /// [uid] 사용자 ID
  /// [newNickname] 새로운 닉네임
  Future<void> updateNickname(String uid, String newNickname) async {
    try {
      // 기존 프로필 조회
      final currentProfile = await loadProfileData(uid);
      if (currentProfile == null) {
        throw Exception('프로필을 찾을 수 없습니다.');
      }

      // 닉네임이 변경되지 않았으면 종료
      if (currentProfile.nickname == newNickname) {
        return;
      }

      // 닉네임 중복 체크
      final isDuplicate = await checkNicknameDuplicate(newNickname, uid);
      if (isDuplicate) {
        throw Exception('이미 사용 중인 닉네임입니다.');
      }

      // 프로필 업데이트
      await _firestore
          .collection(_collectionName)
          .doc(uid)
          .update({
        'nickname': newNickname,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 기존 닉네임 인덱스 삭제
      await _firestore
          .collection(_nicknameIndexCollection)
          .doc(currentProfile.nickname.toLowerCase())
          .delete();

      // 새로운 닉네임 인덱스 추가
      await _firestore
          .collection(_nicknameIndexCollection)
          .doc(newNickname.toLowerCase())
          .set({
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
  ///
  /// [nickname] 체크할 닉네임
  /// [currentUid] 현재 사용자 ID (자신의 닉네임은 중복으로 간주하지 않음)
  /// 반환: true면 중복, false면 사용 가능
  Future<bool> checkNicknameDuplicate(String nickname, String? currentUid) async {
    try {
      final docSnapshot = await _firestore
          .collection(_nicknameIndexCollection)
          .doc(nickname.toLowerCase())
          .get();

      if (!docSnapshot.exists) {
        return false;
      }

      final data = docSnapshot.data();
      if (data == null) {
        return false;
      }

      final existingUid = data['uid'] as String?;

      // 현재 사용자의 닉네임이면 중복 아님
      if (currentUid != null && existingUid == currentUid) {
        return false;
      }

      return true;
    } catch (e) {
      print('닉네임 중복 체크 오류: $e');
      rethrow;
    }
  }

  /// 프로필 사진 업로드
  ///
  /// [uid] 사용자 ID
  /// [imageFile] 업로드할 이미지 파일
  /// 반환: 업로드된 이미지 URL
  Future<String> uploadProfileImage(String uid, File imageFile) async {
    try {
      final storageRef = _storage.ref().child('profiles/$uid/profile.jpg');

      // 기존 파일 삭제 (선택사항)
      try {
        await storageRef.delete();
      } catch (e) {
        // 파일이 없으면 무시
      }

      // 새 파일 업로드
      await storageRef.putFile(imageFile);

      // 다운로드 URL 가져오기
      final downloadUrl = await storageRef.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print('프로필 사진 업로드 오류: $e');
      rethrow;
    }
  }

  /// 프로필 사진 URL 업데이트
  ///
  /// [uid] 사용자 ID
  /// [photoUrl] 새로운 프로필 사진 URL
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
  ///
  /// [uid] 사용자 ID
  /// [locationEnabled] 위치 권한 활성화 여부
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
  ///
  /// [uid] 사용자 ID
  /// [nickname] 새로운 닉네임 (선택)
  /// [bio] 새로운 한 줄 소개 (선택)
  /// [photoUrl] 새로운 프로필 사진 URL (선택)
  /// [locationEnabled] 위치 권한 활성화 여부 (선택)
  Future<void> updateProfile({
    required String uid,
    String? nickname,
    String? bio,
    String? photoUrl,
    bool? locationEnabled,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (nickname != null) {
        // 닉네임 중복 체크
        final isDuplicate = await checkNicknameDuplicate(nickname, uid);
        if (isDuplicate) {
          throw Exception('이미 사용 중인 닉네임입니다.');
        }

        // 기존 프로필 조회
        final currentProfile = await loadProfileData(uid);
        if (currentProfile != null && currentProfile.nickname != nickname) {
          // 기존 닉네임 인덱스 삭제
          await _firestore
              .collection(_nicknameIndexCollection)
              .doc(currentProfile.nickname.toLowerCase())
              .delete();

          // 새로운 닉네임 인덱스 추가
          await _firestore
              .collection(_nicknameIndexCollection)
              .doc(nickname.toLowerCase())
              .set({
            'uid': uid,
            'nickname': nickname,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        updateData['nickname'] = nickname;
      }

      if (photoUrl != null) {
        updateData['photoUrl'] = photoUrl;
      }

      if (bio != null) {
        updateData['bio'] = bio;
      }

      if (locationEnabled != null) {
        updateData['locationEnabled'] = locationEnabled;
      }

      await _firestore
          .collection(_collectionName)
          .doc(uid)
          .update(updateData);
    } catch (e) {
      print('프로필 정보 업데이트 오류: $e');
      rethrow;
    }
  }
}
