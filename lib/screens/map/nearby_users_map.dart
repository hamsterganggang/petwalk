import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../services/location_query_service.dart';
import '../../services/block_service.dart';
import '../../models/user_location_model.dart';
import '../../utils/location_permission_helper.dart';
import '../../utils/theme_config.dart';
import '../../providers/profile_state_manager.dart';

/// 주변 산책러 지도 화면
class NearbyUsersMap extends StatefulWidget {
  const NearbyUsersMap({super.key});

  @override
  State<NearbyUsersMap> createState() => _NearbyUsersMapState();
}

class _NearbyUsersMapState extends State<NearbyUsersMap> {
  final MapController _mapController = MapController();
  final LocationQueryService _locationService = LocationQueryService();
  final BlockService _blockService = BlockService();
  
  LatLng _currentLocation = const LatLng(37.5665, 126.9780); // 기본값: 서울
  List<UserLocationModel> _nearbyWalkers = [];
  bool _isLoading = true;
  bool _hasPermission = false;
  bool _isTracking = false;
  StreamSubscription<List<UserLocationModel>>? _walkersSubscription;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    _walkersSubscription?.cancel();
    _locationService.dispose();
    super.dispose();
  }

  /// 위치 초기화 및 권한 확인
  Future<void> _initializeLocation() async {
    // BlockService 초기화
    await _blockService.initialize();
    
    final hasPermission = await LocationPermissionHelper.requestLocationPermission();
    
    if (!hasPermission) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasPermission = false;
        });
        _showPermissionDeniedDialog();
      }
      return;
    }

    setState(() {
      _hasPermission = true;
    });

    try {
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _currentPosition = position;
          _isLoading = false;
        });
        // MapController는 onMapReady 콜백에서만 사용
        // onMapReady에서 지도 이동 및 추적 시작이 처리됨
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('위치를 가져올 수 없습니다: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// 주변 사용자 추적 시작
  void _startTracking() {
    if (_currentPosition == null) return;

    setState(() {
      _isTracking = true;
    });

    // 내 위치 업데이트 시작 (산책 중이 아닐 때도 위치만 업데이트)
    _locationService.startLocationUpdates((position) {
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _currentPosition = position;
        });
        // Firestore에 위치 업데이트 (산책 중이 아닐 때는 isWalking: false)
        _locationService.updateUserLocation(position, false);
      }
    });

    // 주변 사용자 스트림 구독
    _walkersSubscription?.cancel();
    _walkersSubscription = _locationService
        .findNearbyWalkers(_currentPosition!)
        .listen((walkers) {
      if (mounted) {
        // 차단된 사용자 필터링 (동기적으로 처리)
        final filteredWalkers = _blockService.filterBlockedUsers(walkers);
        
        setState(() {
          _nearbyWalkers = filteredWalkers;
        });
      }
    });
  }

  /// 추적 중지
  void _stopTracking() {
    setState(() {
      _isTracking = false;
    });
    _locationService.stopLocationUpdates();
    _walkersSubscription?.cancel();
    _walkersSubscription = null;
  }

  /// 위치 권한 거부 다이얼로그
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('위치 권한 필요'),
          content: const Text(
            '주변 산책러를 찾으려면 위치 권한이 필요합니다.\n설정에서 위치 권한을 허용해주세요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                LocationPermissionHelper.requestLocationPermission();
              },
              child: const Text('설정으로 이동'),
            ),
          ],
        );
      },
    );
  }

  /// 거리 포맷팅 (미터 → km 또는 m)
  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    } else {
      return '${meters.toStringAsFixed(0)}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasPermission) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('주변 산책러'),
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_off,
                size: 64,
                color: AppColors.textGrey,
              ),
              const SizedBox(height: 16),
              Text(
                '위치 권한이 필요합니다',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '주변 산책러를 찾으려면\n위치 권한을 허용해주세요',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textGrey,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initializeLocation,
                child: const Text('권한 요청'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('주변 산책러'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(
              _isTracking ? Icons.pause : Icons.play_arrow,
              color: _isTracking ? AppColors.primaryGreen : AppColors.textGrey,
            ),
            onPressed: _isTracking ? _stopTracking : _startTracking,
            tooltip: _isTracking ? '추적 중지' : '추적 시작',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 15.0,
              onMapReady: () {
                // 지도가 준비되면 현재 위치로 이동하고 추적 시작
                if (_currentPosition != null && mounted) {
                  _mapController.move(_currentLocation, 15.0);
                  _startTracking();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.petwalk.app',
              ),
              MarkerLayer(
                markers: [
                  // 내 위치 마커 (파란색)
                  Marker(
                    point: _currentLocation,
                    width: 50,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                  // 주변 사용자 마커 (초록색)
                  ..._nearbyWalkers.map((walker) {
                    return Marker(
                      point: LatLng(walker.latitude, walker.longitude),
                      width: 50,
                      height: 50,
                      child: GestureDetector(
                        onTap: () {
                          _showUserInfo(walker);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(
                            Icons.pets,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ],
          ),
          // 주변 사용자 정보 카드
          if (_nearbyWalkers.isNotEmpty)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '주변 산책러 ${_nearbyWalkers.length}명',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ..._nearbyWalkers.take(3).map((walker) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: walker.profileImageUrl != null
                                  ? NetworkImage(walker.profileImageUrl!)
                                  : null,
                              child: walker.profileImageUrl == null
                                  ? const Icon(Icons.person, size: 16)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                walker.nickname ?? '이름 없음',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            Text(
                              _formatDistance(walker.distanceInMeters),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textGrey,
                                  ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 사용자 정보 표시
  void _showUserInfo(UserLocationModel walker) {
    final profileManager = Provider.of<ProfileStateManager>(context, listen: false);

    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          bool isLoading = false;

          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 프로필 이미지
                CircleAvatar(
                  radius: 40,
                  backgroundImage: walker.profileImageUrl != null
                      ? NetworkImage(walker.profileImageUrl!)
                      : null,
                  child: walker.profileImageUrl == null
                      ? const Icon(Icons.person, size: 40)
                      : null,
                ),
                const SizedBox(height: 16),
                // 닉네임
                Text(
                  walker.nickname ?? '이름 없음',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                // 거리 정보
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on, size: 16, color: AppColors.primaryGreen),
                    const SizedBox(width: 4),
                    Text(
                      '${_formatDistance(walker.distanceInMeters)} 떨어져 있음',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textGrey,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // 팔로우/언팔로우 버튼
                FutureBuilder<bool>(
                  future: profileManager.isFollowing(walker.userId),
                  builder: (context, snapshot) {
                    final isFollowingUser = snapshot.data ?? false;
                    
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                setState(() {
                                  isLoading = true;
                                });

                                try {
                                  bool success;
                                  if (isFollowingUser) {
                                    success = await profileManager.unfollowUser(walker.userId);
                                  } else {
                                    success = await profileManager.followUser(walker.userId);
                                  }

                                  if (mounted && context.mounted) {
                                    setState(() {
                                      isLoading = false;
                                    });

                                    if (success) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            isFollowingUser
                                                ? '언팔로우했습니다'
                                                : '팔로우했습니다',
                                          ),
                                          backgroundColor: AppColors.primaryGreen,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                      // 상태 새로고침을 위해 다이얼로그 닫고 다시 열기
                                      Navigator.pop(context);
                                      _showUserInfo(walker);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            profileManager.errorMessage ??
                                                '오류가 발생했습니다',
                                          ),
                                          backgroundColor: Colors.red,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  if (mounted && context.mounted) {
                                    setState(() {
                                      isLoading = false;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('오류가 발생했습니다: $e'),
                                        backgroundColor: Colors.red,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowingUser
                              ? Colors.grey
                              : AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                isFollowingUser ? '언팔로우' : '팔로우',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                // 위치 보기 버튼
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      // 지도에서 해당 위치로 이동
                      _mapController.move(
                        LatLng(walker.latitude, walker.longitude),
                        16.0,
                      );
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('위치 보기'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
