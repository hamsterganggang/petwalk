import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petwalk/models/user_model.dart';
import 'package:petwalk/services/follow_service.dart';
import 'package:petwalk/widgets/user_profile_card.dart';

class UserSearchPage extends StatefulWidget {
  const UserSearchPage({super.key});

  @override
  State<UserSearchPage> createState() => _UserSearchPageState();
}

class _UserSearchPageState extends State<UserSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FollowService _followService = FollowService();
  List<UserModel> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel(); // 위젯이 사라질 때 타이머도 취소
    super.dispose();
  }

  // 입력이 끝난 후 0.5초 뒤에 검색을 실행하는 함수 (디바운싱)
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchUsers(query);
    });
  }

  Future<void> _searchUsers(String query) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    // 검색어가 비어있으면 목록을 비우고 종료
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    final docs = await _followService.searchUsers(query);
    if (mounted) {
      setState(() {
        _searchResults = docs.map((doc) => UserModel.fromFirestore(doc)).toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('사용자 검색'),
        automaticallyImplyLeading: false,
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
                          setState(() {
                            _searchResults = [];
                            _hasSearched = false;
                          });
                        },
                      )
                    : null,
              ),
              onChanged: _onSearchChanged, // Enter 대신 텍스트가 변경될 때마다 함수 호출
            ),
          ),
          Expanded(
            child: _buildSearchResults(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 검색어가 있을 때만 "결과 없음" 표시
    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        child: Text('검색 결과가 없습니다.', style: theme.textTheme.bodyLarge),
      );
    }
    
    // 초기 화면 안내 (아직 검색하지 않았고, 검색어도 없을 때)
    if (!_hasSearched && _searchController.text.isEmpty) {
        return Center(
        child: Text('찾고 싶은 사용자의 닉네임을 입력하세요.', style: theme.textTheme.bodyLarge),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return UserProfileCard(user: _searchResults[index]);
      },
    );
  }
}
