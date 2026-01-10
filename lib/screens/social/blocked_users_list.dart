import 'package:flutter/material.dart';
import '../../services/block_service.dart';
import '../../utils/theme_config.dart';

/// 차단된 사용자 목록 화면
class BlockedUsersList extends StatefulWidget {
  const BlockedUsersList({super.key});

  @override
  State<BlockedUsersList> createState() => _BlockedUsersListState();
}

class _BlockedUsersListState extends State<BlockedUsersList> {
  final BlockService _blockService = BlockService();
  List<Map<String, dynamic>> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  /// 차단된 사용자 목록 로드
  Future<void> _loadBlockedUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final users = await _blockService.getBlockedList();
      if (mounted) {
        setState(() {
          _blockedUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('차단 목록을 불러오는 중 오류가 발생했습니다: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// 차단 해제
  Future<void> _unblockUser(String userId, String blockId) async {
    try {
      await _blockService.unblockUser(userId);
      await _blockService.refresh(); // 캐시 새로고침
      
      if (mounted) {
        setState(() {
          _blockedUsers.removeWhere((user) => user['blockId'] == blockId);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('차단이 해제되었습니다.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('차단 해제 중 오류가 발생했습니다: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('차단된 사용자'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _blockedUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.block,
                        size: 64,
                        color: AppColors.textGrey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '차단된 사용자가 없습니다',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadBlockedUsers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _blockedUsers.length,
                    itemBuilder: (context, index) {
                      final user = _blockedUsers[index];
                      final userId = user['uid'] as String? ?? 
                                   (user['id'] as String? ?? '');
                      final nickname = user['nickname'] as String? ?? '이름 없음';
                      final profileImageUrl = user['photoURL'] as String?;
                      final blockId = user['blockId'] as String? ?? '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundImage: profileImageUrl != null &&
                                    profileImageUrl.isNotEmpty
                                ? NetworkImage(profileImageUrl)
                                : null,
                            child: profileImageUrl == null ||
                                    profileImageUrl.isEmpty
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(
                            nickname,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: OutlinedButton(
                            onPressed: () => _unblockUser(userId, blockId),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textGrey,
                              side: BorderSide(color: AppColors.textGrey),
                            ),
                            child: const Text('차단 해제'),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
