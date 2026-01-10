import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/profile_state_manager.dart';
import '../providers/user_auth_state.dart';
import '../models/user_profile.dart';
import '../utils/theme_config.dart';
import '../services/google_signin_handler.dart';
import '../screens/edit_profile_page.dart';
import '../screens/blocked_users_list.dart';
import '../screens/followers_page.dart';
import '../screens/following_page.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profileManager = Provider.of<ProfileStateManager>(context, listen: false);
      profileManager.loadProfileData();
    });
  }

  Future<void> _requestLocationPermission(ProfileStateManager profileManager) async {
    try {
      final status = await Permission.location.request();

      if (status.isGranted) {
        await profileManager.updateLocationEnabled(true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('위치 권한이 허용되었습니다.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else if (status.isDenied) {
        if (mounted) {
          _showPermissionDeniedDialog();
        }
      } else if (status.isPermanentlyDenied) {
        if (mounted) {
          _showPermissionPermanentlyDeniedDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('위치 권한 요청 중 오류가 발생했습니다: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('위치 권한 필요'),
          content: const Text('위치 기능을 사용하려면 위치 권한이 필요합니다.\n설정에서 위치 권한을 허용해주세요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('설정으로 이동'),
            ),
          ],
        );
      },
    );
  }

  void _showPermissionPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('위치 권한 필요'),
          content: const Text('위치 기능을 사용하려면 위치 권한이 필요합니다.\n설정 앱에서 위치 권한을 수동으로 허용해주세요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('설정으로 이동'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleLocationPermission(
      ProfileStateManager profileManager,
      bool currentStatus,
      ) async {
    if (profileManager.isUpdating) {
      return;
    }

    try {
      if (!currentStatus) {
        await _requestLocationPermission(profileManager);
      } else {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('위치 권한 비활성화'),
              content: const Text('위치 권한을 비활성화하시겠습니까?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('비활성화'),
                ),
              ],
            );
          },
        );

        if (confirmed == true && mounted) {
          final success = await profileManager.updateLocationEnabled(false);
          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('위치 권한이 비활성화되었습니다.'),
                backgroundColor: AppColors.success,
              ),
            );
          } else if (mounted && profileManager.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(profileManager.errorMessage!),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
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
    }
  }

  void _showFollowersList(BuildContext context, ProfileStateManager profileManager) {
    if (profileManager.profile == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FollowersPage(
          userId: profileManager.profile!.uid,
        ),
      ),
    );
  }

  void _showFollowingList(BuildContext context, ProfileStateManager profileManager) {
    if (profileManager.profile == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FollowingPage(
          userId: profileManager.profile!.uid,
        ),
      ),
    );
  }

  Widget _buildFollowerInfo(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ProfileStateManager, UserAuthState>(
      builder: (context, profileManager, authState, child) {
        final profile = profileManager.profile;
        final isLoading = profileManager.isLoading || authState.isLoading;

        if (isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (!profileManager.isLoading && profile == null) {
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    profileManager.errorMessage ?? '프로필을 불러올 수 없습니다.',
                    style: const TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: profileManager.isLoading
                      ? null
                      : () async {
                    profileManager.clearError();
                    await profileManager.loadProfileData();
                  },
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await profileManager.refresh();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                CircleAvatar(
                  radius: 60,
                  backgroundColor: AppColors.divider,
                  backgroundImage: (profile?.photoUrl != null && profile!.photoUrl!.isNotEmpty)
                      ? NetworkImage(profile.photoUrl!)
                      : null,
                  child: (profile?.photoUrl == null || profile!.photoUrl!.isEmpty)
                      ? const Icon(
                    Icons.person,
                    size: 60,
                    color: AppColors.textSecondary,
                  )
                      : null,
                ),
                const SizedBox(height: 24),
                Text(
                  profile?.nickname ?? '',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  (profile?.bio != null && profile!.bio.isNotEmpty) ? profile.bio : '한 줄 소개가 없습니다.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => _showFollowersList(context, profileManager),
                      child: _buildFollowerInfo('팔로워', profile?.followers ?? 0),
                    ),
                    const SizedBox(width: 40),
                    GestureDetector(
                      onTap: () => _showFollowingList(context, profileManager),
                      child: _buildFollowerInfo('팔로잉', profile?.following ?? 0),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: (profileManager.isUpdating || profileManager.isLoading)
                        ? null
                        : () async {
                      try {
                        if (profile == null) return;
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditProfilePage(
                              profile: profile,
                              profileManager: profileManager,
                            ),
                          ),
                        );

                        if (result == true && mounted) {
                          await profileManager.refresh();
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
                      }
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('프로필 수정'),
                  ),
                ),
                const SizedBox(height: 32),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.location_on),
                        title: const Text('위치 권한'),
                        subtitle: Text(
                          (profile?.locationEnabled ?? false) ? '활성화됨' : '비활성화됨',
                        ),
                        trailing: Switch(
                          value: profile?.locationEnabled ?? false,
                          onChanged: profileManager.isUpdating || profileManager.isLoading
                              ? null
                              : (value) => _toggleLocationPermission(
                            profileManager,
                            profile?.locationEnabled ?? false,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.block),
                        title: const Text('차단된 사용자'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const BlockedUsersList(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.logout, color: AppColors.error),
                        title: const Text(
                          '로그아웃',
                          style: TextStyle(color: AppColors.error),
                        ),
                        onTap: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('로그아웃'),
                                content: const Text('정말 로그아웃하시겠습니까?'),
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
                                    child: const Text('로그아웃'),
                                  ),
                                ],
                              );
                            },
                          );

                          if (confirmed == true && mounted) {
                            try {
                              final googleSignInHandler = GoogleSignInHandler();
                              await googleSignInHandler.signOut();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('로그아웃 중 오류가 발생했습니다: $e'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          }
                        },
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
    );
  }
}