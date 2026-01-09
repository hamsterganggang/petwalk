import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'authentication_handler.dart';

/// Google Sign-In 처리 클래스
class GoogleSignInHandler {
  // Web 클라이언트 ID (google-services.json의 client_type: 3)
  static const String _webClientId = '125120646156-sjva9r9elhe2tjikff2sbstmm1bia8vg.apps.googleusercontent.com';
  
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
    // 서버 클라이언트 ID 설정 (Firebase Auth와 연동을 위해 필요)
    serverClientId: _webClientId,
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

      // ID 토큰이 없는 경우 에러 처리
      if (googleAuth.idToken == null) {
        throw Exception('Google 인증 토큰을 가져올 수 없습니다. Google Play Services를 확인해주세요.');
      }

      // Access 토큰이 없는 경우 에러 처리
      if (googleAuth.accessToken == null) {
        throw Exception('Google 액세스 토큰을 가져올 수 없습니다. Google Play Services를 확인해주세요.');
      }

      // Firebase Auth에 로그인
      await _authService.signInWithGoogle(
        googleIdToken: googleAuth.idToken!,
        googleAccessToken: googleAuth.accessToken!,
      );
    } on PlatformException catch (e) {
      // PlatformException 처리
      String errorMessage = '구글 로그인에 실패했습니다.';
      
      if (e.code == 'sign_in_failed') {
        errorMessage = '구글 로그인에 실패했습니다. Google Play Services를 확인해주세요.';
      } else if (e.code == 'sign_in_canceled') {
        errorMessage = '로그인이 취소되었습니다.';
      } else if (e.message != null) {
        errorMessage = '구글 로그인 오류: ${e.message}';
      }
      
      throw Exception(errorMessage);
    } catch (e) {
      // 기타 에러 처리
      String errorMessage = '구글 로그인 중 오류가 발생했습니다.';
      if (e.toString().contains('sign_in_failed')) {
        errorMessage = '구글 로그인에 실패했습니다. Google Play Services가 설치되어 있고 최신 버전인지 확인해주세요.';
      } else if (e.toString().contains('network')) {
        errorMessage = '네트워크 연결을 확인해주세요.';
      }
      throw Exception('$errorMessage (${e.toString()})');
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
