/// 유효성 검증 유틸리티 함수
class ValidationUtils {
  /// 반려동물 이름 유효성 검사
  /// 
  /// [value] 검사할 이름
  /// 반환: 에러 메시지 또는 null
  static String? validateAnimalName(String? value) {
    if (value == null || value.isEmpty) {
      return '이름을 입력해주세요.';
    }
    if (value.length < 1) {
      return '이름은 1자 이상이어야 합니다.';
    }
    if (value.length > 20) {
      return '이름은 20자 이하여야 합니다.';
    }
    return null;
  }

  /// 반려동물 종류 유효성 검사
  /// 
  /// [value] 검사할 종류
  /// 반환: 에러 메시지 또는 null
  static String? validateAnimalType(String? value) {
    if (value == null || value.isEmpty) {
      return '종류를 선택해주세요.';
    }
    return null;
  }

  /// 반려동물 생년월일 유효성 검사
  /// 
  /// [value] 검사할 생년월일
  /// 반환: 에러 메시지 또는 null
  static String? validateBirthDate(DateTime? value) {
    if (value == null) {
      return '생년월일을 선택해주세요.';
    }
    final now = DateTime.now();
    if (value.isAfter(now)) {
      return '생년월일은 오늘보다 이전이어야 합니다.';
    }
    // 50년 이전 날짜 체크 (합리적인 범위)
    final fiftyYearsAgo = DateTime(now.year - 50, now.month, now.day);
    if (value.isBefore(fiftyYearsAgo)) {
      return '생년월일이 너무 오래되었습니다.';
    }
    return null;
  }

  /// 반려동물 성별 유효성 검사
  /// 
  /// [value] 검사할 성별
  /// 반환: 에러 메시지 또는 null
  static String? validateGender(String? value) {
    if (value == null || value.isEmpty) {
      return '성별을 선택해주세요.';
    }
    return null;
  }

  /// 반려동물 체중 유효성 검사
  /// 
  /// [value] 검사할 체중
  /// 반환: 에러 메시지 또는 null
  static String? validateWeight(String? value) {
    if (value == null || value.isEmpty) {
      return '체중을 입력해주세요.';
    }
    final weight = double.tryParse(value);
    if (weight == null) {
      return '올바른 숫자를 입력해주세요.';
    }
    if (weight <= 0) {
      return '체중은 0보다 커야 합니다.';
    }
    if (weight > 200) {
      return '체중은 200kg 이하여야 합니다.';
    }
    return null;
  }
}
