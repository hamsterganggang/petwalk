import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/animal_data_model.dart';
import '../providers/animal_list_provider.dart';
import '../screens/animal_form_page.dart';
import '../utils/theme_config.dart';

/// 반려동물 리스트 화면
class AnimalListView extends StatefulWidget {
  const AnimalListView({super.key});

  @override
  State<AnimalListView> createState() => _AnimalListViewState();
}

class _AnimalListViewState extends State<AnimalListView> {
  @override
  void initState() {
    super.initState();
    // 반려동물 목록 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AnimalListProvider>(context, listen: false);
      provider.fetchAnimalList();
    });
  }

  /// 반려동물 카드 위젯
  Widget _buildAnimalCard(AnimalDataModel animal, AnimalListProvider provider) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 사진 영역
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: animal.photoUrl != null
                    ? Image.network(
                  animal.photoUrl!,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildDefaultPlaceholder();
                  },
                )
                    : _buildDefaultPlaceholder(),
              ),
              // 정보 영역
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 이름
                      Text(
                        animal.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // 품종 또는 종류
                      Text(
                        animal.breed ?? animal.type,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      // 나이
                      Text(
                        animal.getAgeText(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // 점 3개 메뉴 버튼
          Positioned(
            top: 8,
            right: 8,
            child: PopupMenuButton<String>(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.more_vert,
                  size: 20,
                  color: AppColors.textDark,
                ),
              ),
              onSelected: (String value) {
                if (value == 'edit') {
                  _navigateToEditPage(animal, provider);
                } else if (value == 'delete') {
                  _showDeleteConfirmDialog(animal).then((confirmed) async {
                    if (confirmed == true && mounted) {
                      final success = await provider.deleteAnimal(animal.id);
                      if (success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('반려동물 정보가 삭제되었습니다.'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      } else if (mounted && provider.errorMessage != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(provider.errorMessage!),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  });
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20, color: AppColors.textDark),
                      SizedBox(width: 12),
                      Text('수정'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: AppColors.error),
                      SizedBox(width: 12),
                      Text('삭제', style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 기본 이미지 플레이스홀더 빌더
  Widget _buildDefaultPlaceholder() {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryGreen.withOpacity(0.3),
            AppColors.accentLightGreen.withOpacity(0.3),
          ],
        ),
      ),
      child: const Icon(
        Icons.pets,
        size: 70,
        color: AppColors.primaryGreen,
      ),
    );
  }

  /// 수정 페이지로 이동
  Future<void> _navigateToEditPage(
      AnimalDataModel animal,
      AnimalListProvider provider,
      ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnimalFormPage(
          animal: animal,
          isEditMode: true,
        ),
      ),
    );

    if (result == true && mounted) {
      await provider.refresh();
    }
  }

  /// 삭제 확인 다이얼로그
  Future<bool?> _showDeleteConfirmDialog(AnimalDataModel animal) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('반려동물 삭제'),
          content: Text('${animal.name}의 정보를 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
              ),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AnimalListProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (provider.errorMessage != null && provider.animalList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    provider.errorMessage!,
                    style: const TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      provider.clearError();
                      provider.fetchAnimalList();
                    },
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          if (provider.animalList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.pets,
                    size: 80,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '등록된 반려동물이 없습니다',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '우측 상단의 + 버튼을 눌러\n반려동물을 등록해보세요',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.refresh(),
            child: GridView.builder(
              padding: const EdgeInsets.all(16.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.35,
              ),
              itemCount: provider.animalList.length,
              itemBuilder: (context, index) {
                final animal = provider.animalList[index];
                return _buildAnimalCard(animal, provider);
              },
            ),
          );
        },
      ),
      floatingActionButton: Consumer<AnimalListProvider>(
        builder: (context, provider, child) {
          return FloatingActionButton(
            onPressed: provider.isLoading || provider.isUpdating
                ? null
                : () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AnimalFormPage(isEditMode: false),
                ),
              );

              if (result == true && mounted) {
                await provider.refresh();
              }
            },
            backgroundColor: AppColors.primaryGreen,
            child: const Icon(Icons.add, color: Colors.white),
          );
        },
      ),
    );
  }
}