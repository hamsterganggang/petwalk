/// 인증 관련 유틸리티 함수들

/// 에러 메시지 정리 (Exception: 제거)
String cleanErrorMessage(dynamic error) {
  return error.toString().replaceAll('Exception: ', '');
}
