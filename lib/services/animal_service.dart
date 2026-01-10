import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/animal_data_model.dart';
import '../services/firebase_service.dart';

/// 반려동물 데이터 관리 서비스 클래스
class AnimalService {
  final FirebaseFirestore _firestore = FirebaseService.getFirestore();
  final FirebaseStorage _storage = FirebaseService.getStorage();
  static const String _collectionName = 'animals';

  /// 새로운 반려동물 등록
  /// 
  /// [animal] 등록할 반려동물 데이터
  /// [autoSetPrimary] 첫 번째 반려동물을 자동으로 대표로 설정할지 여부
  /// 반환: 생성된 문서 ID
  Future<String> addNewAnimal(
    AnimalDataModel animal, {
    bool autoSetPrimary = true,
  }) async {
    try {
      // 사용자가 명시적으로 대표 동물로 설정하지 않은 경우에만 자동 설정
      if (!animal.isPrimary && autoSetPrimary) {
        // 첫 번째 반려동물인지 확인
        final existingAnimals = await fetchAnimalList(animal.ownerId);
        final isFirstAnimal = existingAnimals.isEmpty;
        
        // 첫 번째 반려동물이면 자동으로 대표로 설정
        if (isFirstAnimal) {
          animal = animal.copyWith(isPrimary: true);
        }
      }
      
      final docRef = _firestore.collection(_collectionName).doc();
      final animalWithId = animal.copyWith(id: docRef.id);
      
      await docRef.set(animalWithId.toMap());
      
      // 대표 반려동물로 설정된 경우, 다른 반려동물들의 isPrimary를 false로 변경
      if (animal.isPrimary) {
        await _updateOtherAnimalsPrimaryStatus(docRef.id, animal.ownerId);
      }
      
      return docRef.id;
    } catch (e) {
      print('반려동물 등록 오류: $e');
      rethrow;
    }
  }

  /// 반려동물 목록 조회
  /// 
  /// [ownerId] 소유자 ID
  /// 반환: 반려동물 목록 (대표 반려동물 우선)
  Future<List<AnimalDataModel>> fetchAnimalList(String ownerId) async {
    try {
      // 인덱스 없이 작동하도록 단일 where 쿼리 사용
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('ownerId', isEqualTo: ownerId)
          .get();

      final animals = <AnimalDataModel>[];
      for (var doc in querySnapshot.docs) {
        try {
          final animal = AnimalDataModel.fromMap(doc.data(), doc.id);
          animals.add(animal);
        } catch (e) {
          print('반려동물 파싱 오류 (${doc.id}): $e');
        }
      }

      // 클라이언트 측에서 정렬 (대표 반려동물 우선, 그 다음 생성일 순)
      animals.sort((a, b) {
        // 대표 반려동물 우선
        if (a.isPrimary && !b.isPrimary) return -1;
        if (!a.isPrimary && b.isPrimary) return 1;
        // 같은 우선순위면 생성일 순
        return a.createdAt.compareTo(b.createdAt);
      });

      return animals;
    } catch (e) {
      print('반려동물 목록 조회 오류: $e');
      rethrow;
    }
  }

  /// 반려동물 정보 수정
  /// 
  /// [animal] 수정할 반려동물 데이터
  Future<void> modifyAnimalInfo(AnimalDataModel animal) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(animal.id)
          .update({
        'name': animal.name,
        'type': animal.type,
        'breed': animal.breed,
        'birthDate': animal.birthDate.toIso8601String(),
        'gender': animal.gender,
        'isNeutered': animal.isNeutered,
        'weight': animal.weight,
        'photoUrl': animal.photoUrl,
        'isPrimary': animal.isPrimary,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // 대표 반려동물로 설정된 경우, 다른 반려동물들의 isPrimary를 false로 변경
      // 대표 동물을 해제하는 경우(isPrimary가 false로 변경)도 처리
      if (animal.isPrimary) {
        await _updateOtherAnimalsPrimaryStatus(animal.id, animal.ownerId);
      } else {
        // 대표 동물을 해제하는 경우, 기존에 대표 동물이었다면 다른 동물 중 하나를 대표로 설정
        // (하지만 사용자가 명시적으로 해제했으므로 그대로 둠)
        // 혹시 다른 동물이 대표 동물이 아니게 되었을 수 있으므로 확인
        final allAnimals = await fetchAnimalList(animal.ownerId);
        final hasPrimary = allAnimals.any((a) => a.id != animal.id && a.isPrimary);
        
        // 대표 동물이 없고 다른 동물이 있다면, 첫 번째 동물을 대표로 설정
        if (!hasPrimary && allAnimals.length > 1) {
          final firstOtherAnimal = allAnimals.firstWhere(
            (a) => a.id != animal.id,
            orElse: () => allAnimals.first,
          );
          if (firstOtherAnimal.id != animal.id) {
            await setPrimaryAnimal(firstOtherAnimal.id, animal.ownerId);
          }
        }
      }
    } catch (e) {
      print('반려동물 정보 수정 오류: $e');
      rethrow;
    }
  }

  /// 반려동물 삭제
  /// 
  /// [animalId] 삭제할 반려동물 ID
  /// [ownerId] 소유자 ID (보안 검증용)
  Future<void> deleteAnimal(String animalId, String ownerId) async {
    try {
      // 소유자 확인
      final doc = await _firestore
          .collection(_collectionName)
          .doc(animalId)
          .get();

      if (!doc.exists) {
        throw Exception('반려동물 정보를 찾을 수 없습니다.');
      }

      final data = doc.data();
      if (data == null || data['ownerId'] != ownerId) {
        throw Exception('권한이 없습니다.');
      }

      // 사진이 있으면 Storage에서도 삭제
      final photoUrl = data['photoUrl'] as String?;
      if (photoUrl != null && photoUrl.isNotEmpty) {
        try {
          final storageRef = _storage.refFromURL(photoUrl);
          await storageRef.delete();
        } catch (e) {
          print('프로필 사진 삭제 오류 (무시됨): $e');
        }
      }

      // Firestore에서 삭제
      await _firestore
          .collection(_collectionName)
          .doc(animalId)
          .delete();
    } catch (e) {
      print('반려동물 삭제 오류: $e');
      rethrow;
    }
  }

  /// 반려동물 사진 업로드
  /// 
  /// [ownerId] 소유자 ID
  /// [animalId] 반려동물 ID
  /// [imageFile] 업로드할 이미지 파일
  /// 반환: 업로드된 이미지 URL
  Future<String> uploadAnimalPhoto(
    String ownerId,
    String animalId,
    File imageFile,
  ) async {
    try {
      final storageRef = _storage
          .ref()
          .child('animals/$ownerId/$animalId/profile.jpg');
      
      // 기존 파일 삭제 (있는 경우)
      try {
        await storageRef.delete();
      } catch (e) {
        // 파일이 없으면 무시
      }

      // 새 파일 업로드
      await storageRef.putFile(imageFile);
      
      // 다운로드 URL 가져오기
      final downloadUrl = await storageRef.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('반려동물 사진 업로드 오류: $e');
      rethrow;
    }
  }

  /// 반려동물 사진 URL 업데이트
  /// 
  /// [animalId] 반려동물 ID
  /// [photoUrl] 새로운 사진 URL
  Future<void> updateAnimalPhotoUrl(String animalId, String photoUrl) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(animalId)
          .update({
        'photoUrl': photoUrl,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('반려동물 사진 URL 업데이트 오류: $e');
      rethrow;
    }
  }

  /// 대표 반려동물 설정
  /// 
  /// [animalId] 대표로 설정할 반려동물 ID
  /// [ownerId] 소유자 ID
  Future<void> setPrimaryAnimal(String animalId, String ownerId) async {
    try {
      // 다른 반려동물들의 isPrimary를 false로 변경
      await _updateOtherAnimalsPrimaryStatus(animalId, ownerId);

      // 선택한 반려동물을 대표로 설정
      await _firestore
          .collection(_collectionName)
          .doc(animalId)
          .update({
        'isPrimary': true,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('대표 반려동물 설정 오류: $e');
      rethrow;
    }
  }

  /// 다른 반려동물들의 대표 상태 해제
  /// 
  /// [currentAnimalId] 현재 대표로 설정할 반려동물 ID (제외)
  /// [ownerId] 소유자 ID
  Future<void> _updateOtherAnimalsPrimaryStatus(
    String currentAnimalId,
    String ownerId,
  ) async {
    try {
      // 인덱스 없이 작동하도록 단일 where 쿼리 사용
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('ownerId', isEqualTo: ownerId)
          .get();

      final batch = _firestore.batch();
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        // 현재 동물이 아니고, isPrimary가 true인 경우만 업데이트
        if (doc.id != currentAnimalId && 
            (data['isPrimary'] as bool? ?? false)) {
          batch.update(doc.reference, {
            'isPrimary': false,
            'updatedAt': DateTime.now().toIso8601String(),
          });
        }
      }

      await batch.commit();
    } catch (e) {
      print('대표 반려동물 상태 업데이트 오류: $e');
      rethrow;
    }
  }

  /// 반려동물 정보 조회 (단일)
  /// 
  /// [animalId] 반려동물 ID
  /// 반환: 반려동물 정보 또는 null
  Future<AnimalDataModel?> getAnimalById(String animalId) async {
    try {
      final doc = await _firestore
          .collection(_collectionName)
          .doc(animalId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return AnimalDataModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      print('반려동물 정보 조회 오류: $e');
      rethrow;
    }
  }
}
