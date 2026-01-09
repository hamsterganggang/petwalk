/// 반려동물 데이터 모델 클래스
class AnimalDataModel {
  final String id;
  final String ownerId;
  final String name;
  final String type; // 종류 (예: 강아지, 고양이 등)
  final String? breed; // 품종 (강아지일 때만)
  final DateTime birthDate;
  final String gender; // 성별 (예: 수컷, 암컷)
  final bool isNeutered; // 중성화 여부
  final double weight; // 체중 (kg) - 필수
  final String? photoUrl; // 사진 URL
  final bool isPrimary; // 대표 반려동물 여부
  final DateTime createdAt;
  final DateTime updatedAt;

  AnimalDataModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.type,
    this.breed,
    required this.birthDate,
    required this.gender,
    required this.isNeutered,
    required this.weight,
    this.photoUrl,
    this.isPrimary = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 나이 계산 (년, 개월)
  Map<String, int> getAge() {
    final now = DateTime.now();
    int years = now.year - birthDate.year;
    int months = now.month - birthDate.month;

    if (months < 0) {
      years--;
      months += 12;
    }

    if (now.day < birthDate.day) {
      months--;
      if (months < 0) {
        years--;
        months += 12;
      }
    }

    return {'years': years, 'months': months};
  }

  /// 나이 텍스트 (예: "2년 3개월" 또는 "6개월")
  String getAgeText() {
    final age = getAge();
    if (age['years']! > 0) {
      if (age['months']! > 0) {
        return '${age['years']}년 ${age['months']}개월';
      }
      return '${age['years']}년';
    }
    return '${age['months']}개월';
  }

  /// Firestore Map으로 변환
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'name': name,
      'type': type,
      'breed': breed,
      'birthDate': birthDate.toIso8601String(),
      'gender': gender,
      'isNeutered': isNeutered,
      'weight': weight,
      'photoUrl': photoUrl,
      'isPrimary': isPrimary,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Firestore Map에서 생성
  factory AnimalDataModel.fromMap(Map<String, dynamic> map, String docId) {
    return AnimalDataModel(
      id: docId,
      ownerId: map['ownerId'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      breed: map['breed'] as String?,
      birthDate: DateTime.parse(map['birthDate'] as String),
      gender: map['gender'] as String,
      isNeutered: map['isNeutered'] as bool? ?? false,
      weight: (map['weight'] as num?)?.toDouble() ?? 0.0,
      photoUrl: map['photoUrl'] as String?,
      isPrimary: map['isPrimary'] as bool? ?? false,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  /// 반려동물 정보 복사 (수정 시 사용)
  AnimalDataModel copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? type,
    String? breed,
    DateTime? birthDate,
    String? gender,
    bool? isNeutered,
    double? weight,
    String? photoUrl,
    bool? isPrimary,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AnimalDataModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      type: type ?? this.type,
      breed: breed ?? this.breed,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      isNeutered: isNeutered ?? this.isNeutered,
      weight: weight ?? this.weight,
      photoUrl: photoUrl ?? this.photoUrl,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'AnimalDataModel(id: $id, name: $name, type: $type, gender: $gender, age: ${getAgeText()})';
  }
}
