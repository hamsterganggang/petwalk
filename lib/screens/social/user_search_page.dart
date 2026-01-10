import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_profile.dart';
import '../../models/user_model.dart';
import '../../providers/profile_state_manager.dart';
import '../../services/follow_service.dart';
import '../../services/block_service.dart';
import '../../widgets/user_profile_card.dart';
import '../../utils/theme_config.dart';

class UserSearchPage extends StatefulWidget {
  const UserSearchPage({super.key});

  @override
  State<UserSearchPage> createState() => _UserSearchPageState();
}

class _UserSearchPageState extends State<UserSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FollowService _followService = FollowService();
  final BlockService _blockService = BlockService();
  List<UserProfile> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  /// 서비스 초기화
  Future<void> _initializeServices() async {
    await _blockService.initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchUsers(query);
    });
  }

  Future<void> _searchUsers(String query) async {
    if (!mounted) return;
    
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      // BlockService 초기화 확인
      await _blockService.initialize();
      
      // 현재 사용자 ID 가져오기 (ProfileStateManager 또는 Firebase Auth에서)
      String? currentUserId;
      try {
        final profileManager = Provider.of<ProfileStateManager>(context, listen: false);
        currentUserId = profileManager.profile?.uid;
      } catch (e) {
        print('ProfileStateManager에서 사용자 ID 가져오기 오류: $e');
      }
      
      // 프로필이 없으면 Firebase Auth에서 직접 가져오기
      if (currentUserId == null) {
        try {
          currentUserId = FirebaseAuth.instance.currentUser?.uid;
        } catch (e) {
          print('Firebase Auth에서 사용자 ID 가져오기 오류: $e');
        }
      }

      final searchDocs = await _followService.searchUsers(trimmedQuery);
      
      List<UserProfile> users = [];
      for (final doc in searchDocs) {
        final user = UserProfile.fromFirestore(doc);
        // 자신은 검색 결과에서 제외
        if (currentUserId == null || user.uid != currentUserId) {
          // 차단된 사용자도 제외
          if (!_blockService.isBlocked(user.uid)) {
            users.add(user);
          }
        }
      }

      if (mounted) {
        setState(() {
          _searchResults = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('검색 중 오류가 발생했습니다: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// UserProfile을 UserModel로 변환
  UserModel _convertToUserModel(UserProfile profile) {
    return UserModel(
      uid: profile.uid,
      nickname: profile.nickname,
      profileImageUrl: profile.photoUrl,
      followerCount: profile.followers,
      followingCount: profile.following,
    );
  }

  /// 차단된 사용자 필터링 및 검색 결과에서 제거
  void _onUserBlocked(String userId) {
    setState(() {
      _searchResults.removeWhere((user) => user.uid == userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('사용자 검색'),
      ),
      body: Column(
        children: [
          // 검색 입력 필드
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '닉네임으로 검색...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _hasSearched = false;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          
          // 검색 결과
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (!_hasSearched) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 16),
            Text(
              '닉네임으로 사용자를 검색해보세요',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              size: 64,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 16),
            Text(
              '검색 결과가 없습니다',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final userProfile = _searchResults[index];
        final userModel = _convertToUserModel(userProfile);
        return UserProfileCard(
          user: userModel,
          onBlocked: () => _onUserBlocked(userProfile.uid),
        );
      },
    );
  }
}
