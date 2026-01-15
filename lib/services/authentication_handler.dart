import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';
import 'notification_service.dart';

/// Firebase Authentication 래퍼 클래스
class UserAuthenticationService {
  final FirebaseAuth _auth = FirebaseService.getAuth();
  final FirebaseFirestore _firestore = FirebaseService.getFirestore();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  bool get isAuthenticated => currentUser != null;

  /// 비밀번호 변경 (재인증 포함)
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw Exception('사용자를 찾을 수 없습니다.');

    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        throw Exception('현재 비밀번호가 일치하지 않습니다.');
      } else if (e.code == 'weak-password') {
        throw Exception('비밀번호가 너무 취약합니다.');
      }
      throw Exception(e.message ?? '비밀번호 변경 중 오류가 발생했습니다.');
    } catch (e) {
      throw Exception('오류가 발생했습니다: $e');
    }
  }

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
      return {'userCredential': userCredential, 'isNewUser': isNew};
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

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
        await _saveUserToFirestore(userCredential.user!);
        await NotificationService.updateToken();
      }
      return userCredential;
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// 비밀번호 재설정 이메일 전송 (계정 존재 여부 확인 추가)
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      // 1. Firestore에서 해당 이메일을 가진 사용자가 있는지 먼저 확인
      final querySnapshot = await _firestore
          .collection('profiles')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        // 보안상 이유로 Firebase Auth가 직접 알려주지 않는 '없는 계정' 에러를 수동으로 처리
        throw Exception('등록되지 않은 이메일 계정입니다.');
      }

      // 2. 계정이 존재할 때만 이메일 발송
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      rethrow;
    }
  }

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
      return false;
    }
  }

  Future<bool> checkAuthStatus() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      final docSnapshot = await _firestore.collection('profiles').doc(user.uid).get();
      if (!docSnapshot.exists) {
        await logoutUser();
        return false;
      }
      return true;
    } catch (e) {
      return isAuthenticated;
    }
  }

  Future<bool> checkNicknameAvailability(String nickname) async {
    try {
      final user = currentUser;
      if (user == null) return false;
      final querySnapshot = await _firestore.collection('profiles').where('nickname', isEqualTo: nickname.trim()).limit(1).get();
      if (querySnapshot.docs.isNotEmpty) {
        if (querySnapshot.docs.first.id == user.uid) return true;
        return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

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
