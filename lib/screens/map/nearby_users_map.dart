import 'dart:async';
import 'dart:math' as math;
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
import '../other_user_profile_view.dart';

/// 주변 산책러 및 맞팔 친구 지도 화면
class NearbyUsersMap extends StatefulWidget {
  const NearbyUsersMap({super.key});

  @override
  State<NearbyUsersMap> createState() => _NearbyUsersMapState();
}

class _NearbyUsersMapState extends State<NearbyUsersMap> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final LocationQueryService _locationService = LocationQueryService();
  final BlockService _blockService = BlockService();
  late TabController _tabController;

  LatLng _currentLocation = const LatLng(37.5665, 126.9780);
  List<UserLocationModel> _displayWalkers = []; 
  bool _isLoading = true;
  bool _hasPermission = false;
  bool _isTracking = false;
  bool _showInfoCard = true; 
  StreamSubscription<List<UserLocationModel>>? _walkersSubscription;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _initializeLocation();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _walkersSubscription?.cancel();
    _locationService.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    _startTracking();
  }

  Future<void> _initializeLocation() async {
    await _blockService.initialize();
    final hasPermission = await LocationPermissionHelper.requestLocationPermission();
    if (!hasPermission) {
      if (mounted) {
        setState(() { _isLoading = false; _hasPermission = false; });
        _showPermissionDeniedDialog();
      }
      return;
    }
    setState(() => _hasPermission = true);
    try {
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _currentPosition = position;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startTracking() {
    if (_currentPosition == null) return;
    
    setState(() {
      _isTracking = true;
      _displayWalkers = []; 
    });

    _locationService.startLocationUpdates((position) {
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _currentPosition = position;
        });
        _locationService.updateUserLocation(position, false);
      }
    });

    _walkersSubscription?.cancel();
    
    final int currentTabIndex = _tabController.index;
    final walkerStream = currentTabIndex == 0
        ? _locationService.findNearbyWalkers(_currentPosition!)
        : _locationService.findMutualFollowers(_currentPosition!);

    _walkersSubscription = walkerStream.listen((walkers) {
      if (mounted && _tabController.index == currentTabIndex) {
        final filteredWalkers = _blockService.filterBlockedUsers(walkers);
        setState(() => _displayWalkers = filteredWalkers);
      }
    });
  }

  void _stopTracking() {
    setState(() {
      _isTracking = false;
      _displayWalkers = [];
    });
    _locationService.stopLocationUpdates();
    _walkersSubscription?.cancel();
    _walkersSubscription = null;
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 권한 필요'),
        content: const Text('산책러를 찾으려면 위치 권한이 필요합니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(onPressed: () { Navigator.pop(context); LocationPermissionHelper.requestLocationPermission(); }, child: const Text('설정')),
        ],
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)}km';
    return '${meters.toStringAsFixed(0)}m';
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    markers.add(
      Marker(
        point: _currentLocation,
        width: 50, height: 50,
        child: Container(
          decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))]),
          child: const Icon(Icons.person, color: Colors.white, size: 30),
        ),
      ),
    );

    final Map<String, List<UserLocationModel>> groupedWalkers = {};
    for (var walker in _displayWalkers) {
      final key = '${walker.latitude.toStringAsFixed(5)},${walker.longitude.toStringAsFixed(5)}';
      groupedWalkers.putIfAbsent(key, () => []).add(walker);
    }

    groupedWalkers.forEach((key, walkers) {
      for (int i = 0; i < walkers.length; i++) {
        final walker = walkers[i];
        double lat = walker.latitude;
        double lng = walker.longitude;
        if (walkers.length > 1) {
          double angle = (2 * math.pi / walkers.length) * i;
          double distance = 0.00008;
          lat += distance * math.cos(angle);
          lng += distance * math.sin(angle);
        }

        markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 55, height: 55,
            child: GestureDetector(
              onTap: () {
                // 마커 클릭 시 정보 카드를 자동으로 숨김
                setState(() => _showInfoCard = false);
                
                _mapController.move(LatLng(walker.latitude, walker.longitude), 17.0);
                if (walkers.length > 1) { _showUserList(walkers); } else { _showUserInfo(walker); }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: walker.profileImageUrl != null ? Colors.white : AppColors.primaryGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: _tabController.index == 1 ? Colors.orangeAccent : Colors.white, width: 3),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: walker.profileImageUrl != null
                    ? ClipOval(child: Image.network(walker.profileImageUrl!, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: AppColors.primaryGreen, child: const Icon(Icons.pets, color: Colors.white, size: 24))))
                    : const Icon(Icons.pets, color: Colors.white, size: 24),
              ),
            ),
          ),
        );
      }
    });
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('산책 탐색'),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryGreen,
          labelColor: AppColors.primaryGreen,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: '주변 산책러', icon: Icon(Icons.location_on)),
            Tab(text: '맞팔 친구', icon: Icon(Icons.people)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isTracking ? Icons.pause : Icons.play_arrow, color: _isTracking ? AppColors.primaryGreen : AppColors.textGrey),
            onPressed: _isTracking ? _stopTracking : _startTracking,
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
              onMapReady: () { if (_currentPosition != null && mounted) { _mapController.move(_currentLocation, 15.0); _startTracking(); } },
            ),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.petwalk.app'),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),
          
          if (_displayWalkers.isNotEmpty && _showInfoCard)
            Positioned(
              bottom: 20, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 2))]),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(_tabController.index == 0 ? '주변 산책러 ${_displayWalkers.length}명' : '맞팔 친구 ${_displayWalkers.length}명', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                          onPressed: () => setState(() => _showInfoCard = false),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._displayWalkers.take(3).map((walker) {
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: CircleAvatar(radius: 18, backgroundColor: AppColors.lightGreen, backgroundImage: walker.profileImageUrl != null ? NetworkImage(walker.profileImageUrl!) : null, child: walker.profileImageUrl == null ? const Icon(Icons.person, size: 20, color: Colors.white) : null),
                        title: Text(walker.nickname ?? '이름 없음', style: const TextStyle(fontWeight: FontWeight.w500)),
                        trailing: Text(_formatDistance(walker.distanceInMeters), style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                        onTap: () { 
                          // 리스트 아이템 클릭 시에도 정보 카드를 숨김
                          setState(() => _showInfoCard = false);
                          _mapController.move(LatLng(walker.latitude, walker.longitude), 17.0); 
                          _showUserInfo(walker); 
                        },
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
            
          if (_displayWalkers.isNotEmpty && !_showInfoCard)
            Positioned(
              bottom: 20,
              right: 16,
              child: FloatingActionButton.small(
                onPressed: () => setState(() => _showInfoCard = true),
                backgroundColor: AppColors.primaryGreen,
                child: const Icon(Icons.list, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  void _showUserList(List<UserLocationModel> walkers) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), child: Text('이 위치의 산책러 ${walkers.length}명', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            const Divider(),
            Flexible(child: ListView.builder(shrinkWrap: true, itemCount: walkers.length, itemBuilder: (context, index) {
              final walker = walkers[index];
              return ListTile(leading: CircleAvatar(backgroundImage: walker.profileImageUrl != null ? NetworkImage(walker.profileImageUrl!) : null, child: walker.profileImageUrl == null ? const Icon(Icons.person) : null), title: Text(walker.nickname ?? '이름 없음', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${_formatDistance(walker.distanceInMeters)} 떨어짐'), trailing: const Icon(Icons.chevron_right), onTap: () { Navigator.pop(context); _showUserInfo(walker); });
            })),
          ],
        ),
      ),
    );
  }

  void _showUserInfo(UserLocationModel walker) {
    final profileManager = Provider.of<ProfileStateManager>(context, listen: false);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            Row(
              children: [
                CircleAvatar(radius: 35, backgroundImage: walker.profileImageUrl != null ? NetworkImage(walker.profileImageUrl!) : null, child: walker.profileImageUrl == null ? const Icon(Icons.person, size: 35) : null),
                const SizedBox(width: 20),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(walker.nickname ?? '이름 없음', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Row(children: [const Icon(Icons.location_on, size: 14, color: AppColors.primaryGreen), const SizedBox(width: 4), Text('${_formatDistance(walker.distanceInMeters)} 거리에 있음', style: const TextStyle(color: AppColors.textGrey))])])),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OtherUserProfileView(
                            userId: walker.userId,
                            nickname: walker.nickname,
                            profileImageUrl: walker.profileImageUrl,
                          ),
                        ),
                      );
                    }, 
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), 
                    child: const Text('프로필 보기', style: TextStyle(fontWeight: FontWeight.bold))
                  ),
                ),
                const SizedBox(width: 12),
                FutureBuilder<bool>(
                  future: profileManager.isFollowing(walker.userId),
                  builder: (context, snapshot) {
                    final isFollowing = snapshot.data ?? false;
                    return Expanded(child: OutlinedButton(onPressed: () async { if (isFollowing) { await profileManager.unfollowUser(walker.userId); } else { await profileManager.followUser(walker.userId); } if (mounted) Navigator.pop(context); }, style: OutlinedButton.styleFrom(side: BorderSide(color: isFollowing ? Colors.grey : AppColors.primaryGreen), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(isFollowing ? '언팔로우' : '팔로우', style: TextStyle(color: isFollowing ? Colors.grey : AppColors.primaryGreen, fontWeight: FontWeight.bold))));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
