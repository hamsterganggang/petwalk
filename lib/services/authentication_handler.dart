import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';

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
  /// 
  /// [googleIdToken]과 [googleAccessToken]을 받아서 Firebase Auth에 인증
  Future<UserCredential> signInWithGoogle({
    required String googleIdToken,
    required String googleAccessToken,
  }) async {
    try {
      // Google 인증 정보로 Firebase Auth에 로그인
      final credential = GoogleAuthProvider.credential(
        idToken: googleIdToken,
        accessToken: googleAccessToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      
      // 로그인 성공 시 Firestore에 사용자 정보 저장
      if (userCredential.user != null) {
        await _saveUserToFirestore(userCredential.user!);
      }

      return userCredential;
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// Firestore에 사용자 정보 저장
  Future<void> _saveUserToFirestore(User user) async {
    try {
      final userDoc = _firestore.collection('users').doc(user.uid);
      
      // 사용자 문서가 이미 존재하는지 확인
      final docSnapshot = await userDoc.get();
      
      if (!docSnapshot.exists) {
        // 새 사용자인 경우 문서 생성
        await userDoc.set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // 기존 사용자인 경우 정보 업데이트
        await userDoc.update({
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error saving user to Firestore: $e');
      // Firestore 저장 실패해도 로그인은 성공으로 처리
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

  /// 인증 상태 확인
  Future<bool> checkAuthStatus() async {
    try {
      await _auth.authStateChanges().first;
      return isAuthenticated;
    } catch (e) {
      print('Error checking auth status: $e');
      return false;
    }
  }

  /// 에러 처리 및 사용자 친화적 메시지 반환
  String _handleAuthError(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-disabled':
          return '이 계정은 비활성화되었습니다.';
        case 'invalid-credential':
          return '로그인 정보가 올바르지 않습니다.';
        case 'operation-not-allowed':
          return '이 로그인 방법은 허용되지 않습니다.';
        case 'weak-password':
          return '비밀번호가 너무 약합니다.';
        case 'email-already-in-use':
          return '이 이메일은 이미 사용 중입니다.';
        case 'user-not-found':
          return '사용자를 찾을 수 없습니다.';
        case 'wrong-password':
          return '비밀번호가 올바르지 않습니다.';
        case 'network-request-failed':
          return '네트워크 연결을 확인해주세요.';
        default:
          return '로그인 중 오류가 발생했습니다: ${error.message}';
      }
    }
    return '알 수 없는 오류가 발생했습니다: $error';
  }
}
