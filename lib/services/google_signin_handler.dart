import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'authentication_handler.dart';

/// Google Sign-In 처리 클래스
class GoogleSignInHandler {
  // Web 클라이언트 ID (google-services.json의 client_type: 3)
  // Firebase Auth와 연동을 위해 서버 클라이언트 ID로 사용
  static const String _webClientId = '125120646156-sjva9r9elhe2tjikff2sbstmm1bia8vg.apps.googleusercontent.com';
  
  // Android 클라이언트 ID (google-services.json의 client_type: 1)
  // Android 플랫폼에서 사용되는 클라이언트 ID
  static const String _androidClientId = '125120646156-8mpfvkoj0q3heh65fiiim5mnbg1e3ctd.apps.googleusercontent.com';
  
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
    // 서버 클라이언트 ID 설정 (Firebase Auth와 연동을 위해 필요)
    // Android에서는 자동으로 google-services.json에서 클라이언트 ID를 가져오지만,
    // 명시적으로 설정하면 더 안정적입니다.
    serverClientId: _webClientId,
  );

  final UserAuthenticationService _authService = UserAuthenticationService();

  /// 구글 로그인 실행
  /// 반환값: 신규 사용자인지 여부
  Future<bool> signInWithGoogle() async {
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
        // 더 자세한 에러 메시지 제공
        throw Exception(
          'Google 인증 토큰을 가져올 수 없습니다.\n\n'
          '가능한 원인:\n'
          '1. Google Play Services가 설치되지 않았거나 오래된 버전입니다.\n'
          '2. SHA-1 인증서 지문이 Firebase Console에 등록되지 않았습니다.\n'
          '3. 인터넷 연결을 확인해주세요.\n\n'
          '해결 방법:\n'
          '- Google Play Store에서 Google Play Services를 업데이트하세요.\n'
          '- 개발자의 경우: SHA-1 인증서 지문을 Firebase Console에 추가하세요.'
        );
      }

      // Access 토큰이 없는 경우 에러 처리
      if (googleAuth.accessToken == null) {
        throw Exception(
          'Google 액세스 토큰을 가져올 수 없습니다.\n\n'
          '가능한 원인:\n'
          '1. Google Play Services가 설치되지 않았거나 오래된 버전입니다.\n'
          '2. SHA-1 인증서 지문이 Firebase Console에 등록되지 않았습니다.\n\n'
          '해결 방법:\n'
          '- Google Play Store에서 Google Play Services를 업데이트하세요.'
        );
      }

      // Firebase Auth에 로그인
      final result = await _authService.signInWithGoogle(
        googleIdToken: googleAuth.idToken!,
        googleAccessToken: googleAuth.accessToken!,
      );
      
      return result['isNewUser'] as bool;
    } on PlatformException catch (e) {
      // PlatformException 처리
      String errorMessage = '구글 로그인에 실패했습니다.';
      
      if (e.code == 'sign_in_failed') {
        errorMessage = 
          '구글 로그인에 실패했습니다.\n\n'
          '가능한 원인:\n'
          '1. Google Play Services가 설치되지 않았거나 오래된 버전입니다.\n'
          '2. SHA-1 인증서 지문이 Firebase Console에 등록되지 않았습니다.\n'
          '3. 네트워크 연결 문제입니다.\n\n'
          '에러 코드: ${e.code}\n'
          '에러 메시지: ${e.message ?? "없음"}';
      } else if (e.code == 'sign_in_canceled') {
        errorMessage = '로그인이 취소되었습니다.';
      } else if (e.code == 'network_error') {
        errorMessage = '네트워크 연결을 확인해주세요.';
      } else if (e.message != null) {
        errorMessage = '구글 로그인 오류: ${e.message}\n에러 코드: ${e.code}';
      }
      
      // 디버깅을 위한 상세 정보 출력 (개발 중에만)
      print('Google Sign-In PlatformException:');
      print('  Code: ${e.code}');
      print('  Message: ${e.message}');
      print('  Details: ${e.details}');
      print('  Stacktrace: ${e.stacktrace}');
      
      throw Exception(errorMessage);
    } catch (e) {
      // 기타 에러 처리
      String errorMessage = '구글 로그인 중 오류가 발생했습니다.';
      
      final errorString = e.toString();
      
      if (errorString.contains('sign_in_failed')) {
        errorMessage = 
          '구글 로그인에 실패했습니다.\n\n'
          '가능한 원인:\n'
          '1. Google Play Services가 설치되지 않았거나 오래된 버전입니다.\n'
          '2. SHA-1 인증서 지문이 Firebase Console에 등록되지 않았습니다.\n'
          '3. 앱의 패키지 이름이나 클라이언트 ID가 올바르지 않습니다.\n\n'
          '해결 방법:\n'
          '- Google Play Store에서 Google Play Services를 업데이트하세요.\n'
          '- 개발자의 경우: android/get_sha1.ps1 스크립트를 실행하여 SHA-1을 확인하고 Firebase Console에 추가하세요.';
      } else if (errorString.contains('network') || errorString.contains('Network')) {
        errorMessage = '네트워크 연결을 확인해주세요.';
      } else if (errorString.contains('DEVELOPER_ERROR') || errorString.contains('10:')) {
        errorMessage = 
          '개발자 설정 오류입니다.\n\n'
          'SHA-1 인증서 지문이 Firebase Console에 등록되지 않았을 가능성이 높습니다.\n\n'
          '해결 방법:\n'
          '1. android/get_sha1.ps1 스크립트를 실행하여 SHA-1을 확인하세요.\n'
          '2. Firebase Console > 프로젝트 설정 > 일반 탭에서 SHA 인증서 지문을 추가하세요.\n'
          '3. google-services.json 파일을 다시 다운로드하고 프로젝트에 적용하세요.';
      }
      
      // 디버깅을 위한 상세 정보 출력
      print('Google Sign-In Error:');
      print('  Type: ${e.runtimeType}');
      print('  Message: $errorString');
      
      throw Exception('$errorMessage\n\n상세 오류: $errorString');
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
