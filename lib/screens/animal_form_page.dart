import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/animal_data_model.dart';
import '../providers/animal_list_provider.dart';
import '../utils/validation_utils.dart';
import '../utils/theme_config.dart';

/// 반려동물 등록/수정 화면
class AnimalFormPage extends StatefulWidget {
  final AnimalDataModel? animal;
  final bool isEditMode;

  const AnimalFormPage({
    super.key,
    this.animal,
    required this.isEditMode,
  });

  @override
  State<AnimalFormPage> createState() => _AnimalFormPageState();
}

class _AnimalFormPageState extends State<AnimalFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _weightController;

  final String _fixedType = '강아지';
  late TextEditingController _breedController;
  DateTime? _selectedBirthDate;
  String? _selectedGender;
  bool _isNeutered = false;
  bool _isPrimary = false;
  File? _selectedImage;
  String? _imageUrl;
  bool _deletePhoto = false;
  bool _isLoading = false;

  final List<String> _genders = ['수컷', '암컷'];

  @override
  void initState() {
    super.initState();

    if (widget.isEditMode && widget.animal != null) {
      final animal = widget.animal!;
      _nameController = TextEditingController(text: animal.name);
      _weightController = TextEditingController(
        text: animal.weight.toStringAsFixed(1),
      );
      _breedController = TextEditingController(text: animal.breed ?? '');
      _selectedBirthDate = animal.birthDate;
      _selectedGender = animal.gender;
      _isNeutered = animal.isNeutered;
      _isPrimary = animal.isPrimary;
      _imageUrl = animal.photoUrl;
    } else {
      _nameController = TextEditingController();
      _weightController = TextEditingController();
      _breedController = TextEditingController();
      _selectedBirthDate = DateTime.now().subtract(const Duration(days: 365));
      // 등록 모드일 때, 첫 번째 반려동물이면 자동으로 대표 동물로 설정
      // (AnimalService에서 처리하므로 여기서는 false로 시작)
      _isPrimary = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _breedController.dispose();
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
                      _deletePhoto = true;
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
          _imageUrl = null;
          _deletePhoto = false;
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

  /// 생년월일 선택
  Future<void> _selectBirthDate() async {
    final DateTime now = DateTime.now();
    final DateTime firstDate = DateTime(now.year - 50, 1, 1);
    final DateTime lastDate = now;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? lastDate.subtract(const Duration(days: 365)),
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryGreen,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedBirthDate) {
      setState(() {
        _selectedBirthDate = picked;
      });
    }
  }

  /// 저장 처리
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('로그인이 필요합니다.');
      }

      final provider = Provider.of<AnimalListProvider>(context, listen: false);

      final weight = double.parse(_weightController.text.trim());

      final animal = AnimalDataModel(
        id: widget.animal?.id ?? '',
        ownerId: user.uid,
        name: _nameController.text.trim(),
        type: _fixedType, // 강아지로 고정 저장
        breed: _breedController.text.trim().isEmpty ? null : _breedController.text.trim(),
        birthDate: _selectedBirthDate!,
        gender: _selectedGender!,
        isNeutered: _isNeutered,
        weight: weight,
        photoUrl: _imageUrl,
        isPrimary: _isPrimary,
        createdAt: widget.animal?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      bool success;

      if (widget.isEditMode) {
        success = await provider.modifyAnimalInfo(
          animal,
          _selectedImage,
          _deletePhoto,
        );
      } else {
        // 등록 모드일 때, 첫 번째 반려동물이면 자동으로 대표로 설정
        // (AnimalService에서 처리하므로 여기서는 그대로 전달)
        success = await provider.addNewAnimal(animal, _selectedImage);
      }

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditMode
                  ? '반려동물 정보가 수정되었습니다.'
                  : '반려동물이 등록되었습니다.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      } else if (mounted && provider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage!),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
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
    final provider = Provider.of<AnimalListProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditMode ? '반려동물 수정' : '반려동물 등록'),
        actions: [
          if (_isLoading || provider.isUpdating)
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 사진 선택
              Center(
                child: GestureDetector(
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
                          Icons.pets,
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
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _showImagePickerDialog,
                  child: const Text('사진 선택'),
                ),
              ),
              const SizedBox(height: 32),
              // 이름
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '이름 *',
                  hintText: '반려동물 이름을 입력하세요',
                  prefixIcon: Icon(Icons.pets),
                ),
                validator: ValidationUtils.validateAnimalName,
                maxLength: 20,
                enabled: !_isLoading && !provider.isUpdating,
              ),
              const SizedBox(height: 16),
              // 품종 입력 (텍스트 입력)
              TextFormField(
                controller: _breedController,
                decoration: const InputDecoration(
                  labelText: '품종 *',
                  hintText: '품종을 입력하세요',
                  prefixIcon: Icon(Icons.pets),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '품종을 입력해주세요.';
                  }
                  if (value.trim().length < 1) {
                    return '품종을 입력해주세요.';
                  }
                  if (value.trim().length > 30) {
                    return '품종은 30자 이하여야 합니다.';
                  }
                  return null;
                },
                maxLength: 30,
                enabled: !_isLoading && !provider.isUpdating,
              ),
              const SizedBox(height: 16),
              // 생년월일
              InkWell(
                onTap: _isLoading || provider.isUpdating ? null : _selectBirthDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: '생년월일 *',
                    prefixIcon: const Icon(Icons.calendar_today),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  child: Text(
                    _selectedBirthDate != null
                        ? '${_selectedBirthDate!.year}년 ${_selectedBirthDate!.month}월 ${_selectedBirthDate!.day}일'
                        : '생년월일을 선택하세요',
                    style: TextStyle(
                      color: _selectedBirthDate != null
                          ? AppColors.textDark
                          : Colors.grey[400],
                    ),
                  ),
                ),
              ),
              if (_selectedBirthDate != null)
                Text(
                  ValidationUtils.validateBirthDate(_selectedBirthDate) ?? '',
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 16),
              // 성별
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: const InputDecoration(
                  labelText: '성별 *',
                  prefixIcon: Icon(Icons.wc),
                ),
                items: _genders.map((String gender) {
                  return DropdownMenuItem<String>(
                    value: gender,
                    child: Text(gender),
                  );
                }).toList(),
                onChanged: (_isLoading || provider.isUpdating)
                    ? null
                    : (String? newValue) {
                  setState(() {
                    _selectedGender = newValue;
                  });
                },
                validator: ValidationUtils.validateGender,
              ),
              const SizedBox(height: 16),
              // 체중
              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(
                  labelText: '체중 (kg) *',
                  hintText: '체중을 입력하세요',
                  prefixIcon: Icon(Icons.monitor_weight),
                  suffixText: 'kg',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: ValidationUtils.validateWeight,
                enabled: !_isLoading && !provider.isUpdating,
              ),
              const SizedBox(height: 16),
              // 중성화 여부
              SwitchListTile(
                title: const Text('중성화 여부'),
                value: _isNeutered,
                onChanged: (_isLoading || provider.isUpdating)
                    ? null
                    : (bool value) {
                  setState(() {
                    _isNeutered = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              // 대표 동물 설정
              SwitchListTile(
                title: Row(
                  children: [
                    const Text('대표 동물 설정'),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.star,
                      size: 20,
                      color: _isPrimary
                          ? AppColors.primaryGreen
                          : AppColors.textSecondary,
                    ),
                  ],
                ),
                subtitle: const Text(
                  '대표 동물로 설정하면 목록의 맨 위에 표시됩니다',
                  style: TextStyle(fontSize: 12),
                ),
                value: _isPrimary,
                onChanged: (_isLoading || provider.isUpdating)
                    ? null
                    : (bool value) {
                  setState(() {
                    _isPrimary = value;
                  });
                },
              ),
              const SizedBox(height: 32),
              // 저장 버튼 (하단)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isLoading || provider.isUpdating) ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: (_isLoading || provider.isUpdating)
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          '저장',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}