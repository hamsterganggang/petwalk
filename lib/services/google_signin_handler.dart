import 'package:google_sign_in/google_sign_in.dart';
import 'authentication_handler.dart';

/// Google Sign-In 처리 클래스
class GoogleSignInHandler {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
  );

  final UserAuthenticationService _authService = UserAuthenticationService();

  /// 구글 로그인 실행
  Future<void> signInWithGoogle() async {
    try {
      // Google Sign-In 실행
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // 사용자가 로그인을 취소한 경우
        throw Exception('로그인이 취소되었습니다.');
      }

      // Google 인증 정보 가져오기
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Firebase Auth에 로그인
      await _authService.signInWithGoogle(
        googleIdToken: googleAuth.idToken!,
        googleAccessToken: googleAuth.accessToken!,
      );
    } catch (e) {
      // 에러를 다시 throw하여 UI에서 처리할 수 있도록 함
      rethrow;
    }
  }

  /// 구글 로그아웃
  Future<void> signOut() async {
    try {
      // Google Sign-In에서 로그아웃
      await _googleSignIn.signOut();
      
      // Firebase Auth에서 로그아웃
      await _authService.logoutUser();
    } catch (e) {
      rethrow;
    }
  }

  /// 현재 구글 로그인 상태 확인
  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }
}
