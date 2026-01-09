import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/animal_data_model.dart';
import '../services/animal_service.dart';

/// 반려동물 리스트 상태 관리 클래스
class AnimalListProvider extends ChangeNotifier {
  final AnimalService _animalService = AnimalService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<AnimalDataModel> _animalList = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isUpdating = false;

  List<AnimalDataModel> get animalList => _animalList;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isUpdating => _isUpdating;

  /// 반려동물 목록 조회
  Future<void> fetchAnimalList() async {
    final user = _auth.currentUser;
    if (user == null) {
      _errorMessage = '로그인이 필요합니다.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _animalList = await _animalService.fetchAnimalList(user.uid);
    } catch (e) {
      _errorMessage = '반려동물 목록을 불러오는 중 오류가 발생했습니다: ${e.toString()}';
      print('반려동물 목록 조회 오류: $e');
      _animalList = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 새로운 반려동물 등록
  /// 
  /// [animal] 등록할 반려동물 데이터
  /// [imageFile] 업로드할 이미지 파일 (선택)
  /// 반환: 성공 여부
  Future<bool> addNewAnimal(AnimalDataModel animal, File? imageFile) async {
    final user = _auth.currentUser;
    if (user == null) {
      _errorMessage = '로그인이 필요합니다.';
      notifyListeners();
      return false;
    }

    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String? photoUrl;

      // 반려동물 등록 (이미지는 나중에 업로드)
      final animalId = await _animalService.addNewAnimal(animal);

      // 이미지 업로드 (있는 경우)
      if (imageFile != null) {
        photoUrl = await _animalService.uploadAnimalPhoto(
          user.uid,
          animalId,
          imageFile,
        );
        // 사진 URL 업데이트
        await _animalService.updateAnimalPhotoUrl(animalId, photoUrl);
      }

      // 목록 새로고침
      await fetchAnimalList();

      return true;
    } catch (e) {
      _errorMessage = '반려동물 등록 중 오류가 발생했습니다: ${e.toString()}';
      print('반려동물 등록 오류: $e');
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  /// 반려동물 정보 수정
  /// 
  /// [animal] 수정할 반려동물 데이터
  /// [imageFile] 새로운 이미지 파일 (선택)
  /// [deletePhoto] 기존 사진 삭제 여부
  /// 반환: 성공 여부
  Future<bool> modifyAnimalInfo(
    AnimalDataModel animal,
    File? imageFile,
    bool deletePhoto,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      _errorMessage = '로그인이 필요합니다.';
      notifyListeners();
      return false;
    }

    if (animal.ownerId != user.uid) {
      _errorMessage = '권한이 없습니다.';
      notifyListeners();
      return false;
    }

    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String? photoUrl = animal.photoUrl;

      // 이미지 삭제
      if (deletePhoto) {
        photoUrl = null;
      }
      // 새 이미지 업로드
      else if (imageFile != null) {
        photoUrl = await _animalService.uploadAnimalPhoto(
          user.uid,
          animal.id,
          imageFile,
        );
      }

      // 반려동물 정보 업데이트
      final updatedAnimal = animal.copyWith(
        photoUrl: photoUrl,
        updatedAt: DateTime.now(),
      );

      await _animalService.modifyAnimalInfo(updatedAnimal);

      // 목록 새로고침
      await fetchAnimalList();

      return true;
    } catch (e) {
      _errorMessage = '반려동물 정보 수정 중 오류가 발생했습니다: ${e.toString()}';
      print('반려동물 정보 수정 오류: $e');
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  /// 반려동물 삭제
  /// 
  /// [animalId] 삭제할 반려동물 ID
  /// 반환: 성공 여부
  Future<bool> deleteAnimal(String animalId) async {
    final user = _auth.currentUser;
    if (user == null) {
      _errorMessage = '로그인이 필요합니다.';
      notifyListeners();
      return false;
    }

    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _animalService.deleteAnimal(animalId, user.uid);

      // 목록 새로고침
      await fetchAnimalList();

      return true;
    } catch (e) {
      _errorMessage = '반려동물 삭제 중 오류가 발생했습니다: ${e.toString()}';
      print('반려동물 삭제 오류: $e');
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  /// 대표 반려동물 설정
  /// 
  /// [animalId] 대표로 설정할 반려동물 ID
  /// 반환: 성공 여부
  Future<bool> setPrimaryAnimal(String animalId) async {
    final user = _auth.currentUser;
    if (user == null) {
      _errorMessage = '로그인이 필요합니다.';
      notifyListeners();
      return false;
    }

    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _animalService.setPrimaryAnimal(animalId, user.uid);

      // 목록 새로고침
      await fetchAnimalList();

      return true;
    } catch (e) {
      _errorMessage = '대표 반려동물 설정 중 오류가 발생했습니다: ${e.toString()}';
      print('대표 반려동물 설정 오류: $e');
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  /// 에러 메시지 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// 목록 새로고침
  Future<void> refresh() async {
    await fetchAnimalList();
  }
}
