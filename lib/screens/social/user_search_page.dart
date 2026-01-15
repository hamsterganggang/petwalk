import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../models/user_profile.dart';
import '../../providers/profile_state_manager.dart';
import '../../services/follow_service.dart';
import '../../utils/theme_config.dart';
import '../other_user_profile_view.dart';

class UserSearchPage extends StatefulWidget {
  const UserSearchPage({super.key});

  @override
  State<UserSearchPage> createState() => _UserSearchPageState();
}

class _UserSearchPageState extends State<UserSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FollowService _followService = FollowService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  
  List<UserProfile> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  Timer? _debounce;

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
    if (query.trim().isEmpty) {
      setState(() { _searchResults = []; _hasSearched = false; _isLoading = false; });
      return;
    }

    setState(() { _isLoading = true; _hasSearched = true; });

    try {
      final searchDocs = await _followService.searchUsers(query.trim());
      
      List<UserProfile> users = [];
      for (final doc in searchDocs) {
        final user = UserProfile.fromFirestore(doc);
        
        // 1. 자신은 검색 결과에서 절대 제외 (FirebaseAuth UID 기준)
        if (user.uid == _currentUserId) continue;
        
        // 2. 비공개 계정도 검색은 되도록 함 (프로필에서 필터링)
        users.add(user);
      }

      setState(() {
        _searchResults = users;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _searchResults = []; _isLoading = false; });
    }
  }

  Future<void> _toggleFollow(UserProfile user) async {
    final profileManager = Provider.of<ProfileStateManager>(context, listen: false);
    try {
      bool isFollowingUser = await profileManager.isFollowing(user.uid);
      if (isFollowingUser) {
        await profileManager.unfollowUser(user.uid);
      } else {
        await profileManager.followUser(user.uid);
      }
      setState(() {}); // UI 갱신 (FutureBuilder 재실행)
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('사용자 검색'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
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
                          setState(() { _searchResults = []; _hasSearched = false; });
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(child: _buildSearchResults()),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (!_hasSearched) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: AppColors.textSecondary),
            SizedBox(height: 16),
            Text('닉네임으로 사용자를 검색해보세요', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, size: 64, color: AppColors.textSecondary),
            SizedBox(height: 16),
            Text('검색 결과가 없습니다', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        // 중복 방지를 위한 Unique Key 설정
        return ListTile(
          key: ValueKey(user.uid),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtherUserProfileView(
                userId: user.uid,
                nickname: user.nickname,
                profileImageUrl: user.photoUrl,
              ),
            ),
          ),
          leading: CircleAvatar(
            backgroundColor: AppColors.divider,
            backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
            child: user.photoUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
          ),
          title: Row(
            children: [
              Text(user.nickname, style: const TextStyle(fontWeight: FontWeight.bold)),
              if (user.isPrivate) ...[
                const SizedBox(width: 4),
                const Icon(Icons.lock, size: 14, color: Colors.grey),
              ],
            ],
          ),
          trailing: FutureBuilder<bool>(
            future: Provider.of<ProfileStateManager>(context, listen: false).isFollowing(user.uid),
            builder: (context, snapshot) {
              final isFollowingUser = snapshot.data ?? false;
              return ElevatedButton(
                onPressed: () => _toggleFollow(user),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFollowingUser ? Colors.grey[200] : AppColors.primaryGreen,
                  foregroundColor: isFollowingUser ? Colors.black : Colors.white,
                  elevation: 0,
                  minimumSize: const Size(80, 32),
                ),
                child: Text(isFollowingUser ? '언팔로우' : '팔로우'),
              );
            },
          ),
        );
      },
    );
  }
}
