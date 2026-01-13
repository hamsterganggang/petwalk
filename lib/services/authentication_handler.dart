import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';
import 'notification_service.dart';

/// Firebase Authentication 래퍼 클래스
class UserAuthenticationService {
  final FirebaseAuth _auth = FirebaseService.getAuth();
  final FirebaseFirestore _firestore = FirebaseService.getFirestore();

  /// 현재 로그인한 사용자 가져오기
  User? get currentUser => _auth.currentUser;

  /// 인증 상태 변경 Stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// 인증 상태 확인
  bool get isAuthenticated => currentUser != null;

  /// 구글 로그인
  Future<Map<String, dynamic>> signInWithGoogle({
    required String googleIdToken,
    required String googleAccessToken,
  }) async {
    try {
      final credential = GoogleAuthProvider.credential(
        idToken: googleIdToken,
        accessToken: googleAccessToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      
      bool isNew = false;
      if (userCredential.user != null) {
        isNew = await _saveUserToFirestore(userCredential.user!);
        await NotificationService.updateToken();
      }

      return {
        'userCredential': userCredential,
        'isNewUser': isNew,
      };
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// 이메일/비밀번호로 회원가입
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (displayName != null && displayName.isNotEmpty && userCredential.user != null) {
        await userCredential.user!.updateDisplayName(displayName);
        await userCredential.user!.reload();
      }

      if (userCredential.user != null) {
        await _saveUserToFirestore(userCredential.user!);
        await NotificationService.updateToken();
      }

      return userCredential;
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// 이메일/비밀번호로 로그인
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // 서버 정보 확인 및 복구 시도
        await _saveUserToFirestore(userCredential.user!);
        await NotificationService.updateToken();
      }

      return userCredential;
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// 비밀번호 재설정 이메일 전송
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// Firestore에 사용자 정보 저장 (profiles 컬렉션 사용)
  Future<bool> _saveUserToFirestore(User user) async {
    try {
      final userDoc = _firestore.collection('profiles').doc(user.uid);
      final docSnapshot = await userDoc.get();
      final isNew = !docSnapshot.exists;
      
      if (isNew) {
        await userDoc.set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          'nickname': user.displayName ?? '',
          'photoUrl': user.photoURL,
          'followers': 0,
          'following': 0,
          'notificationsEnabled': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await userDoc.update({
          'email': user.email,
          'displayName': user.displayName,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      return isNew;
    } catch (e) {
      print('Error saving user to Firestore: $e');
      return false;
    }
  }

  /// 사용자의 닉네임이 설정되어 있는지 확인
  Future<bool> hasNickname() async {
    try {
      final user = currentUser;
      if (user == null) return false;

      final docSnapshot = await _firestore.collection('profiles').doc(user.uid).get();
      if (!docSnapshot.exists) return false;

      final data = docSnapshot.data();
      final nickname = data?['nickname'] as String?;
      return nickname != null && nickname.trim().isNotEmpty;
    } catch (e) {
      print('Error checking hasNickname: $e');
      return false;
    }
  }

  /// 인증 상태 및 서버 정보 교차 확인 (서버에서 정보 삭제 시 로그아웃 처리)
  Future<bool> checkAuthStatus() async {
    try {
      // 1. Firebase Auth 세션 확인
      final user = _auth.currentUser;
      if (user == null) return false;

      // 2. Firestore 서버 데이터 존재 확인
      final docSnapshot = await _firestore.collection('profiles').doc(user.uid).get();
      
      if (!docSnapshot.exists) {
        // 인증은 되어있으나 서버에 정보가 없는 경우 (강제 로그아웃)
        print('User found in Auth but not in Firestore. Signing out...');
        await logoutUser();
        return false;
      }

      return true;
    } catch (e) {
      print('Error checking auth status: $e');
      // 네트워크 오류 등의 경우 기존 인증 상태 유지 (안전책)
      return isAuthenticated;
    }
  }

  /// 닉네임 중복 체크
  Future<bool> checkNicknameAvailability(String nickname) async {
    try {
      final user = currentUser;
      if (user == null) return false;

      final querySnapshot = await _firestore
          .collection('profiles')
          .where('nickname', isEqualTo: nickname.trim())
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        if (doc.id == user.uid) return true;
        return false;
      }
      return true;
    } catch (e) {
      print('Error checking nickname availability: $e');
      return false;
    }
  }

  /// 사용자 닉네임 업데이트
  Future<void> updateUserNickname(String nickname) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('로그인이 필요합니다.');

      final isAvailable = await checkNicknameAvailability(nickname);
      if (!isAvailable) throw Exception('이미 사용 중인 닉네임입니다.');

      await user.updateDisplayName(nickname);
      await user.reload();

      await _firestore.collection('profiles').doc(user.uid).update({
        'nickname': nickname,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// 로그아웃
  Future<void> logoutUser() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  Exception _handleAuthError(dynamic error) {
    if (error is FirebaseAuthException) {
      return Exception(error.message ?? '인증 오류가 발생했습니다.');
    }
    return Exception(error.toString());
  }
}
