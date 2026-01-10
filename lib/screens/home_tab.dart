import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/theme_config.dart';
import '../providers/animal_list_provider.dart';
import '../models/animal_data_model.dart';
import 'animal_list_view.dart';
import 'walk_map_view.dart';
import 'walk_history_list.dart';
import 'statistics_view.dart';
import 'feed/public_feed_view.dart';
import 'profile_view.dart';
import 'animal_form_page.dart';

/// 홈 탭 화면
class HomeTab extends StatefulWidget {
  final Function(int)? onTabChange;
  
  const HomeTab({super.key, this.onTabChange});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  @override
  void initState() {
    super.initState();
    // 반려동물 목록 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AnimalListProvider>(context, listen: false);
      provider.fetchAnimalList();
    });
  }

  /// 대표 반려동물 가져오기
  AnimalDataModel? _getPrimaryAnimal(AnimalListProvider provider) {
    if (provider.animalList.isEmpty) {
      return null;
    }
    // 대표 반려동물 찾기 (isPrimary가 true인 것)
    try {
      return provider.animalList.firstWhere(
        (animal) => animal.isPrimary,
        orElse: () => provider.animalList.first, // 대표가 없으면 첫 번째 반려동물
      );
    } catch (e) {
      // 대표 반려동물이 없으면 첫 번째 반려동물 반환
      return provider.animalList.isNotEmpty ? provider.animalList.first : null;
    }
  }

  /// 대표 반려동물 카드 위젯
  Widget _buildPrimaryAnimalCard(AnimalDataModel? primaryAnimal, AnimalListProvider provider) {
    if (primaryAnimal == null) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: InkWell(
          onTap: () {
            // 반려동물 탭으로 이동 (인덱스 1)
            _navigateToTab(context, 1);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.pets,
                    size: 40,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '반려동물 등록하기',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '첫 반려동물을 등록해보세요',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // 반려동물 탭으로 이동 (인덱스 1)
          _navigateToTab(context, 1);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 반려동물 사진
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: primaryAnimal.photoUrl != null
                    ? Image.network(
                        primaryAnimal.photoUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 80,
                            height: 80,
                            color: AppColors.primaryGreen.withOpacity(0.1),
                            child: const Icon(
                              Icons.pets,
                              size: 40,
                              color: AppColors.primaryGreen,
                            ),
                          );
                        },
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.pets,
                          size: 40,
                          color: AppColors.primaryGreen,
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          primaryAnimal.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (primaryAnimal.isPrimary) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '대표',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      primaryAnimal.breed ?? primaryAnimal.type,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${primaryAnimal.getAgeText()} • ${primaryAnimal.gender}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  /// 바로가기 메뉴 카드 위젯
  Widget _buildQuickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 120, // 고정 높이로 모든 카드 크기 통일
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 28),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 특정 탭으로 이동하는 헬퍼 메서드
  void _navigateToTab(BuildContext context, int tabIndex) {
    // 콜백을 통해 HomePage의 탭 인덱스 변경
    if (widget.onTabChange != null) {
      widget.onTabChange!(tabIndex);
    } else {
      // 콜백이 없으면 Navigator로 이동 (안전장치)
      switch (tabIndex) {
        case 1: // 반려동물 탭
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AnimalListView()),
          );
          break;
        case 2: // 산책 탭
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WalkMapView()),
          );
          break;
        case 3: // 소셜 탭
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PublicFeedView()),
          );
          break;
        case 4: // 프로필 탭
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileView()),
          );
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('홈'),
        automaticallyImplyLeading: false,
      ),
      body: Consumer<AnimalListProvider>(
        builder: (context, provider, child) {
          final primaryAnimal = _getPrimaryAnimal(provider);
          
          return RefreshIndicator(
            onRefresh: () => provider.refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 대표 반려동물 카드
                  _buildPrimaryAnimalCard(primaryAnimal, provider),
                  
                  const SizedBox(height: 8),
                  
                  // 산책 시작하기 (큰 카드)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const WalkMapView()),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primaryGreen,
                              AppColors.primaryGreen.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryGreen.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.directions_walk,
                              color: Colors.white,
                              size: 40,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '산책 시작하기',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    primaryAnimal != null
                                        ? '${primaryAnimal.name}와 함께 산책을 시작해보세요'
                                        : '반려동물과 함께 즐거운 산책을 떠나보세요',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 바로가기 메뉴 섹션
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '바로가기',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // 산책 관련 바로가기
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildQuickActionCard(
                            title: '산책 기록',
                            subtitle: '지난 기록 보기',
                            icon: Icons.history,
                            color: Colors.orange,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const WalkHistoryList(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildQuickActionCard(
                            title: '산책 통계',
                            subtitle: '활동 분석',
                            icon: Icons.bar_chart,
                            color: Colors.blue,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const StatisticsView(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // 반려동물 및 소셜 바로가기
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildQuickActionCard(
                            title: '반려동물',
                            subtitle: '관리하기',
                            icon: Icons.pets,
                            color: AppColors.primaryGreen,
                            onTap: () {
                              // 홈 페이지의 탭 인덱스 변경 (반려동물 탭으로 이동)
                              _navigateToTab(context, 1);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildQuickActionCard(
                            title: '소셜 피드',
                            subtitle: '다른 사용자 보기',
                            icon: Icons.feed,
                            color: Colors.purple,
                            onTap: () {
                              // 소셜 탭으로 이동
                              _navigateToTab(context, 3);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // 프로필 바로가기
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildQuickActionCard(
                            title: '내 프로필',
                            subtitle: '프로필 수정하기',
                            icon: Icons.person,
                            color: Colors.teal,
                            onTap: () {
                              // 프로필 탭으로 이동
                              _navigateToTab(context, 4);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(), // 빈 공간으로 같은 너비 유지
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
