import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/walk_session_provider.dart';
import '../services/walk_record_service.dart';
import '../utils/theme_config.dart';

class EndWalkDialog extends StatefulWidget {
  const EndWalkDialog({super.key});

  @override
  State<EndWalkDialog> createState() => _EndWalkDialogState();
}

class _EndWalkDialogState extends State<EndWalkDialog> {
  final _memoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedMood = '😊';
  final List<String> _moods = ['😊', '😎', '🐾', '😴', '🥵'];
  bool _isSaving = false;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(String userId) async {
    if (_imageFile == null) return null;

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('walk_photos')
          .child('$userId/${DateTime.now().millisecondsSinceEpoch}.jpg');

      final uploadTask = await storageRef.putFile(_imageFile!);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _saveAndFinish() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    
    final walkProvider = context.read<WalkSessionProvider>();
    final recordService = WalkRecordService();

    try {
      String? imageUrl;
      // 이미지 업로드 시도
      imageUrl = await _uploadImage(walkProvider.selectedPets.firstOrNull?.id ?? 'unknown');

      await recordService.saveWalkData(
        startTime: walkProvider.startTime ?? DateTime.now(),
        endTime: DateTime.now(),
        totalDistance: walkProvider.totalDistance,
        routeCoordinates: walkProvider.routeCoordinates,
        memo: _memoController.text,
        mood: _selectedMood,
        selectedPetNames: walkProvider.selectedPets.isEmpty 
            ? ['혼자 산책'] 
            : walkProvider.selectedPets.map((p) => p.name).toList(),
        imageUrls: imageUrl != null ? [imageUrl] : [],
      );
      
      walkProvider.reset();
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final walkProvider = context.watch<WalkSessionProvider>();
    final petNames = walkProvider.selectedPets.isEmpty 
        ? '혼자' 
        : walkProvider.selectedPets.map((p) => p.name).join(', ');

    return AlertDialog(
      title: const Text('산책 종료 및 저장'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$petNames와(과) 함께한 산책',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
              ),
              const SizedBox(height: 16),
              // 사진 촬영 영역
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: _imageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_imageFile!, fit: BoxFit.cover),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('산책 인증 사진 촬영', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _memoController,
                decoration: const InputDecoration(
                  labelText: '산책 메모',
                  hintText: '오늘 산책은 어땠나요?',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                validator: (value) =>
                    (value == null || value.isEmpty) ? '메모를 입력해주세요' : null,
              ),
              const SizedBox(height: 16),
              const Text('오늘의 기분'),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _moods.map((mood) {
                  return GestureDetector(
                    onTap: () => setState(() => _selectedMood = mood),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _selectedMood == mood
                            ? AppColors.primaryGreen.withOpacity(0.2)
                            : null,
                        borderRadius: BorderRadius.circular(8),
                        border: _selectedMood == mood 
                            ? Border.all(color: AppColors.primaryGreen) 
                            : null,
                      ),
                      child: Text(mood, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveAndFinish,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('기록 저장', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
