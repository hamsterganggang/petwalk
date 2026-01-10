import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'authentication_handler.dart';
import 'notification_service.dart'; // 추가

/// Google Sign-In 처리 클래스
class GoogleSignInHandler {
  static const String _webClientId = '125120646156-sjva9r9elhe2tjikff2sbstmm1bia8vg.apps.googleusercontent.com';
  static const String _androidClientId = '125120646156-8mpfvkoj0q3heh65fiiim5mnbg1e3ctd.apps.googleusercontent.com';
  
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
    serverClientId: _webClientId,
  );

  final UserAuthenticationService _authService = UserAuthenticationService();

  /// 구글 로그인 실행
  Future<bool> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('로그인이 취소되었습니다.');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.idToken == null) {
        throw Exception('Google 인증 토큰을 가져올 수 없습니다.');
      }

      if (googleAuth.accessToken == null) {
        throw Exception('Google 액세스 토큰을 가져올 수 없습니다.');
      }

      final result = await _authService.signInWithGoogle(
        googleIdToken: googleAuth.idToken!,
        googleAccessToken: googleAuth.accessToken!,
      );
      
      // 로그인 성공 후 FCM 토큰 업데이트 호출 (추가된 부분)
      await NotificationService.updateToken();
      
      return result['isNewUser'] as bool;
    } on PlatformException catch (e) {
      print('Google Sign-In PlatformException: ${e.code}');
      rethrow;
    } catch (e) {
      print('Google Sign-In Error: $e');
      rethrow;
    }
  }

  /// 구글 로그아웃
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _authService.logoutUser();
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }
}
