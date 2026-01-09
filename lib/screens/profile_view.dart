import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/profile_state_manager.dart';
import '../providers/user_auth_state.dart';
import '../screens/edit_profile_page.dart';
import '../services/google_signin_handler.dart';
import '../utils/theme_config.dart';

/// 프로필 조회 화면
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  @override
  void initState() {
    super.initState();
    // 프로필 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profileManager = Provider.of<ProfileStateManager>(context, listen: false);
      profileManager.loadProfileData();
    });
  }

  /// 위치 권한 요청
  Future<void> _requestLocationPermission(ProfileStateManager profileManager) async {
    try {
      final status = await Permission.location.request();

      if (status.isGranted) {
        // 권한 허용 시 프로필 업데이트
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

  /// 위치 권한 상태 확인
  Future<bool> _checkLocationPermission() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  /// 권한 거부 다이얼로그 표시
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

  /// 권한 영구 거부 다이얼로그 표시
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

  /// 위치 권한 토글
  Future<void> _toggleLocationPermission(
      ProfileStateManager profileManager,
      bool currentStatus,
      ) async {
    if (profileManager.isUpdating) {
      return;
    }

    try {
      if (!currentStatus) {
        // 위치 권한 요청
        await _requestLocationPermission(profileManager);
      } else {
        // 위치 권한 비활성화
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
                  onPressed: profileManager.isLoading ? null : () async {
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
          onRefresh: () => profileManager.refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                // 프로필 사진
                CircleAvatar(
                  radius: 60,
                  backgroundColor: AppColors.divider,
                  backgroundImage: profile!.photoUrl != null
                      ? NetworkImage(profile.photoUrl!)
                      : null,
                  child: profile.photoUrl == null
                      ? const Icon(
                    Icons.person,
                    size: 60,
                    color: AppColors.textSecondary,
                  )
                      : null,
                ),
                const SizedBox(height: 24),
                // 닉네임
                Text(
                  profile.nickname,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),
                // 프로필 수정 버튼
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: (profileManager.isUpdating || profileManager.isLoading)
                        ? null
                        : () async {
                      try {
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
                // 설정 메뉴
                Card(
                  child: Column(
                    children: [
                      // 위치 권한 설정
                      ListTile(
                        leading: const Icon(Icons.location_on),
                        title: const Text('위치 권한'),
                        subtitle: Text(
                          profile.locationEnabled ? '활성화됨' : '비활성화됨',
                        ),
                        trailing: Switch(
                          value: profile.locationEnabled,
                          onChanged: profileManager.isUpdating || profileManager.isLoading
                              ? null
                              : (value) => _toggleLocationPermission(
                            profileManager,
                            profile.locationEnabled,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      // 로그아웃
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