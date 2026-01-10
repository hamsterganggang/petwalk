import 'package:cloud_firestore/cloud_firestore.dart';

class Pet {
  final String id;
  final String ownerId;
  final String name;
  final String type; // 강아지, 고양이 등
  final String? breed; // 품종
  final int age;
  final String gender; // 수컷, 암컷
  final String? imageUrl;
  final bool isRepresentative; // 대표 반려동물 여부
  final DateTime createdAt;
  final DateTime? updatedAt;

  Pet({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.type,
    this.breed,
    required this.age,
    required this.gender,
    this.imageUrl,
    this.isRepresentative = false,
    required this.createdAt,
    this.updatedAt,
  });

  factory Pet.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Pet(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      name: data['name'] ?? '',
      type: data['type'] ?? '',
      breed: data['breed'],
      age: data['age'] ?? 0,
      gender: data['gender'] ?? '',
      imageUrl: data['imageUrl'],
      isRepresentative: data['isRepresentative'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'name': name,
      'type': type,
      'breed': breed,
      'age': age,
      'gender': gender,
      'imageUrl': imageUrl,
      'isRepresentative': isRepresentative,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  Pet copyWith({
    String? name,
    String? type,
    String? breed,
    int? age,
    String? gender,
    String? imageUrl,
    bool? isRepresentative,
    DateTime? updatedAt,
  }) {
    return Pet(
      id: this.id,
      ownerId: this.ownerId,
      name: name ?? this.name,
      type: type ?? this.type,
      breed: breed ?? this.breed,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      imageUrl: imageUrl ?? this.imageUrl,
      isRepresentative: isRepresentative ?? this.isRepresentative,
      createdAt: this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
