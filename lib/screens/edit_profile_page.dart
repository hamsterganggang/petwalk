import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/profile_state_manager.dart';
import '../models/user_profile.dart';
import '../utils/theme_config.dart';

/// 프로필 수정 화면
class EditProfilePage extends StatefulWidget {
  final UserProfile profile;
  final ProfileStateManager profileManager;

  const EditProfilePage({
    super.key,
    required this.profile,
    required this.profileManager,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nicknameController;
  late TextEditingController _bioController;
  File? _selectedImage;
  String? _imageUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.profile.nickname);
    _bioController = TextEditingController(text: widget.profile.bio);
    _imageUrl = widget.profile.photoUrl;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  /// 이미지 선택 다이얼로그
  Future<void> _showImagePickerDialog() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('갤러리에서 선택'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('카메라로 촬영'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              if (_imageUrl != null || _selectedImage != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: AppColors.error),
                  title: const Text('사진 삭제', style: TextStyle(color: AppColors.error)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedImage = null;
                      _imageUrl = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  /// 이미지 선택
  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _imageUrl = null; // 새로운 이미지가 선택되면 URL 초기화
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이미지 선택 중 오류가 발생했습니다: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// 닉네임 유효성 검사
  String? _validateNickname(String? value) {
    if (value == null || value.isEmpty) {
      return '닉네임을 입력해주세요.';
    }
    if (value.length < 2) {
      return '닉네임은 2자 이상이어야 합니다.';
    }
    if (value.length > 10) {
      return '닉네임은 10자 이하여야 합니다.';
    }
    if (!RegExp(r'^[a-zA-Z0-9가-힣]+$').hasMatch(value)) {
      return '닉네임은 영문, 숫자, 한글만 사용 가능합니다.';
    }
    return null;
  }

  /// 저장 버튼 클릭
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final newNickname = _nicknameController.text.trim();
      final newBio = _bioController.text.trim();

      // 변경사항 확인
      bool nicknameChanged = newNickname != widget.profile.nickname;
      bool bioChanged = newBio != widget.profile.bio;
      bool hasNewImage = _selectedImage != null;
      bool imageDeleted = _imageUrl == null && widget.profile.photoUrl != null && !hasNewImage;

      // 변경사항이 없으면 종료
      if (!nicknameChanged && !bioChanged && !hasNewImage && !imageDeleted) {
        if (mounted) {
          Navigator.pop(context, false);
        }
        return;
      }

      bool success = true;

      // 이미지 업로드
      if (hasNewImage) {
        success = await widget.profileManager.uploadProfileImage(_selectedImage!);
        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.profileManager.errorMessage ?? '프로필 사진 업로드에 실패했습니다.'),
              backgroundColor: AppColors.error,
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      // 이미지 삭제
      if (imageDeleted) {
        success = await widget.profileManager.updateProfilePhotoUrl(null);
        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.profileManager.errorMessage ?? '프로필 사진 삭제에 실패했습니다.'),
              backgroundColor: AppColors.error,
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      // 닉네임 또는 bio 업데이트
      if (nicknameChanged || bioChanged) {
        success = await widget.profileManager.updateProfile(
          nickname: nicknameChanged ? newNickname : null,
          bio: bioChanged ? newBio : null,
        );
        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.profileManager.errorMessage ?? '프로필 업데이트에 실패했습니다.'),
              backgroundColor: AppColors.error,
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('프로필이 성공적으로 업데이트되었습니다.'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('프로필 업데이트 중 오류가 발생했습니다: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필 수정'),
        actions: [
          if (_isLoading || widget.profileManager.isUpdating)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _handleSave,
              child: const Text(
                '저장',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              // 프로필 사진
              GestureDetector(
                onTap: _showImagePickerDialog,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: AppColors.divider,
                      backgroundImage: _selectedImage != null
                          ? FileImage(_selectedImage!)
                          : (_imageUrl != null
                              ? NetworkImage(_imageUrl!)
                              : null) as ImageProvider?,
                      child: (_selectedImage == null && _imageUrl == null)
                          ? const Icon(
                              Icons.person,
                              size: 60,
                              color: AppColors.textSecondary,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _showImagePickerDialog,
                child: const Text('프로필 사진 변경'),
              ),
              const SizedBox(height: 32),
              // 닉네임 입력
              TextFormField(
                controller: _nicknameController,
                decoration: const InputDecoration(
                  labelText: '닉네임',
                  hintText: '닉네임을 입력하세요',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: _validateNickname,
                maxLength: 16,
                enabled: !_isLoading && !widget.profileManager.isUpdating,
              ),
              const SizedBox(height: 16),
              // 한 줄 소개 입력
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: '한 줄 소개',
                  hintText: '한 줄 소개를 입력해주세요',
                  prefixIcon: Icon(Icons.edit_note),
                ),
                maxLength: 70,
                maxLines: 3,
                enabled: !_isLoading && !widget.profileManager.isUpdating,
              ),
              const SizedBox(height: 32),
              // 저장 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isLoading || widget.profileManager.isUpdating) 
                      ? null 
                      : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          '프로필 저장',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
