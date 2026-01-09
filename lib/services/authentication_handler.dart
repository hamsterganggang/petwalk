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
  /// 반환값: (UserCredential, isNewUser)
  Future<Map<String, dynamic>> signInWithGoogle({
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
      
      // 로그인 성공 시 Firestore에 사용자 정보 저장 및 신규 사용자 여부 확인
      bool isNew = false;
      if (userCredential.user != null) {
        isNew = await _saveUserToFirestore(userCredential.user!);
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

      // 회원가입 성공 시 사용자 이름 설정 (있는 경우)
      if (displayName != null && displayName.isNotEmpty && userCredential.user != null) {
        await userCredential.user!.updateDisplayName(displayName);
        await userCredential.user!.reload();
      }

      // Firestore에 사용자 정보 저장
      if (userCredential.user != null) {
        await _saveUserToFirestore(userCredential.user!);
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

      // 로그인 성공 시 Firestore에 사용자 정보 업데이트
      if (userCredential.user != null) {
        await _saveUserToFirestore(userCredential.user!);
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

  /// Firestore에 사용자 정보 저장
  /// 반환값: 신규 사용자인지 여부 (true: 신규, false: 기존)
  Future<bool> _saveUserToFirestore(User user) async {
    try {
      final userDoc = _firestore.collection('users').doc(user.uid);
      
      // 사용자 문서가 이미 존재하는지 확인
      final docSnapshot = await userDoc.get();
      final isNew = !docSnapshot.exists;
      
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
      
      return isNew;
    } catch (e) {
      print('Error saving user to Firestore: $e');
      // Firestore 저장 실패해도 로그인은 성공으로 처리
      return false;
    }
  }

  /// 사용자 닉네임 업데이트
  Future<void> updateUserNickname(String nickname) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('로그인이 필요합니다.');
      }

      // Firebase Auth에 닉네임 설정
      await user.updateDisplayName(nickname);
      await user.reload();

      // Firestore에 닉네임 저장
      final userDoc = _firestore.collection('users').doc(user.uid);
      await userDoc.update({
        'displayName': nickname,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// 사용자가 신규 사용자인지 확인 (Firestore에 문서가 없으면 신규)
  Future<bool> isNewUser() async {
    try {
      final user = currentUser;
      if (user == null) {
        return false;
      }

      final userDoc = _firestore.collection('users').doc(user.uid);
      final docSnapshot = await userDoc.get();
      return !docSnapshot.exists;
    } catch (e) {
      print('Error checking if new user: $e');
      return false;
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
  Exception _handleAuthError(dynamic error) {
    String message;
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-disabled':
          message = '이 계정은 비활성화되었습니다.';
          break;
        case 'invalid-credential':
          message = '로그인 정보가 올바르지 않습니다.';
          break;
        case 'operation-not-allowed':
          message = '이 로그인 방법은 허용되지 않습니다.';
          break;
        case 'weak-password':
          message = '비밀번호가 너무 약합니다.';
          break;
        case 'email-already-in-use':
          message = '이 이메일은 이미 사용 중입니다.';
          break;
        case 'user-not-found':
          message = '사용자를 찾을 수 없습니다.';
          break;
        case 'wrong-password':
          message = '비밀번호가 올바르지 않습니다.';
          break;
        case 'network-request-failed':
          message = '네트워크 연결을 확인해주세요.';
          break;
        default:
          message = '로그인 중 오류가 발생했습니다: ${error.message ?? error.code}';
      }
    } else {
      message = '알 수 없는 오류가 발생했습니다: $error';
    }
    return Exception(message);
  }
}
