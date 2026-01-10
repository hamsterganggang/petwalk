import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/walk_session_provider.dart';
import '../providers/animal_list_provider.dart';
import '../models/animal_data_model.dart';
import '../utils/location_permission_helper.dart';
import '../utils/theme_config.dart';
import 'package:geolocator/geolocator.dart';
import 'end_walk_dialog.dart';

class WalkMapView extends StatefulWidget {
  const WalkMapView({super.key});

  @override
  State<WalkMapView> createState() => _WalkMapViewState();
}

class _WalkMapViewState extends State<WalkMapView> {
  final MapController _mapController = MapController();
  LatLng _currentLocation = const LatLng(37.5665, 126.9780); // Default to Seoul
  bool _isLoading = true;
  bool _followUser = true;

  @override
  void initState() {
    super.initState();
    _initializeMap();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AnimalListProvider>(context, listen: false).fetchAnimalList();
    });
  }

  Future<void> _initializeMap() async {
    final hasPermission = await LocationPermissionHelper.requestLocationPermission();
    if (hasPermission) {
      try {
        // use last known position for faster initial loading
        final lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null && mounted) {
          setState(() {
            _currentLocation = LatLng(lastPosition.latitude, lastPosition.longitude);
            _isLoading = false;
          });
          _mapController.move(_currentLocation, 15.0);
        }

        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        if (mounted) {
          setState(() {
            _currentLocation = LatLng(position.latitude, position.longitude);
            _isLoading = false;
          });
          _mapController.move(_currentLocation, 15.0);
        }
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 권한이 필요합니다.')),
        );
      }
    }
  }

  /// Toggle tracking mode or move to location
  void _handleTrackingButton() async {
    if (_followUser) {
      setState(() => _followUser = false);
    } else {
      // 즉시 UI 반응을 위해 상태를 먼저 변경
      setState(() {
        _followUser = true;
      });

      try {
        // 이미 트래킹 중인 좌표가 있다면 가장 최근 좌표로 즉시 이동
        final walkProvider = Provider.of<WalkSessionProvider>(context, listen: false);
        if (walkProvider.routeCoordinates.isNotEmpty) {
          _mapController.move(walkProvider.routeCoordinates.last, _mapController.camera.zoom);
        }

        // 최신 위치 가져오기 (비동기 대기 최소화)
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 3),
        ).catchError((_) => Geolocator.getLastKnownPosition());
        
        if (position != null && mounted && _followUser) {
          final latLng = LatLng(position.latitude, position.longitude);
          _mapController.move(latLng, _mapController.camera.zoom);
        }
      } catch (e) {
        debugPrint('Error getting current location: $e');
      }
    }
  }

  /// 산책할 반려동물 선택 다이얼로그 (선택 사항)
  void _showPetSelectionDialog() {
    final animalProvider = Provider.of<AnimalListProvider>(context, listen: false);
    final walkProvider = Provider.of<WalkSessionProvider>(context, listen: false);
    
    List<AnimalDataModel> tempSelectedPets = [];
    final primaryPet = animalProvider.animalList.where((p) => p.isPrimary).firstOrNull;
    if (primaryPet != null) {
      tempSelectedPets.add(primaryPet);
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('함께 산책할 아이들'),
              content: animalProvider.animalList.isEmpty 
                ? const Text('등록된 반려동물이 없습니다. 혼자 산책하시겠습니까?')
                : SizedBox(
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: animalProvider.animalList.length,
                      itemBuilder: (context, index) {
                        final pet = animalProvider.animalList[index];
                        final isSelected = tempSelectedPets.contains(pet);
                        return CheckboxListTile(
                          title: Text(pet.name),
                          subtitle: Text(pet.breed ?? pet.type),
                          secondary: pet.photoUrl != null 
                              ? CircleAvatar(backgroundImage: NetworkImage(pet.photoUrl!))
                              : const CircleAvatar(child: Icon(Icons.pets)),
                          value: isSelected,
                          activeColor: AppColors.primaryGreen,
                          onChanged: (bool? value) {
                            setDialogState(() {
                              if (value == true) {
                                tempSelectedPets.add(pet);
                              } else {
                                tempSelectedPets.remove(pet);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
              actions: [
                TextButton(
                  onPressed: () {
                    // 선택 없이 시작 (혼자 산책)
                    walkProvider.startTracking([]);
                    Navigator.pop(context);
                  },
                  child: const Text('혼자 산책'),
                ),
                if (animalProvider.animalList.isNotEmpty)
                  ElevatedButton(
                    onPressed: () {
                      walkProvider.startTracking(tempSelectedPets);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('함께 산책 시작'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('산책하기')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                OSMMapWidget(
                  mapController: _mapController,
                  initialLocation: _currentLocation,
                  followUser: _followUser,
                  onMapEvent: (event) {
                    // 사용자가 지도를 직접 조작(드래그, 줌 등)할 때만 추적 모드 해제
                    // MapEventSource.mapController가 아닌 모든 소스는 사용자의 조작으로 간주
                    if (event is MapEventMoveStart && event.source != MapEventSource.mapController) {
                      if (_followUser) {
                        setState(() => _followUser = false);
                      }
                    }
                  },
                ),
                // Toggleable Tracking Button
                Positioned(
                  right: 20,
                  bottom: 220,
                  child: FloatingActionButton(
                    heroTag: 'tracking_btn', // Hero tag conflict 방지
                    onPressed: _handleTrackingButton,
                    backgroundColor: _followUser ? AppColors.primaryGreen : Colors.white,
                    child: Icon(
                      _followUser ? Icons.navigation : Icons.location_searching,
                      color: _followUser ? Colors.white : AppColors.primaryGreen,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: _buildControlPanel(),
                ),
              ],
            ),
    );
  }

  Widget _buildControlPanel() {
    final walkProvider = context.watch<WalkSessionProvider>();
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (walkProvider.isTracking)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  walkProvider.selectedPets.isEmpty 
                      ? '혼자 산책 중' 
                      : '${walkProvider.selectedPets.map((p) => p.name).join(', ')}와(과) 산책 중',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('시간', _formatDuration(walkProvider.elapsedTime)),
                _buildStat('거리', '${walkProvider.totalDistance.toStringAsFixed(2)} km'),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: walkProvider.isTracking
                    ? () => _showEndWalkDialog()
                    : () => _showPetSelectionDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: walkProvider.isTracking ? Colors.redAccent : AppColors.primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  walkProvider.isTracking ? '산책 종료' : '산책 시작',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  void _showEndWalkDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const EndWalkDialog(),
    );

    if (result == true && mounted) {
      Navigator.pop(context);
    }
  }
}

class OSMMapWidget extends StatefulWidget {
  final MapController mapController;
  final LatLng initialLocation;
  final bool followUser;
  final Function(MapEvent)? onMapEvent;

  const OSMMapWidget({
    super.key,
    required this.mapController,
    required this.initialLocation,
    this.followUser = false,
    this.onMapEvent,
  });

  @override
  State<OSMMapWidget> createState() => _OSMMapWidgetState();
}

class _OSMMapWidgetState extends State<OSMMapWidget> {
  @override
  Widget build(BuildContext context) {
    final walkProvider = context.watch<WalkSessionProvider>();

    if (widget.followUser && walkProvider.routeCoordinates.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.mapController.move(walkProvider.routeCoordinates.last, widget.mapController.camera.zoom);
        }
      });
    }

    return FlutterMap(
      mapController: widget.mapController,
      options: MapOptions(
        initialCenter: widget.initialLocation,
        initialZoom: 15.0,
        onMapEvent: widget.onMapEvent,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.petwalk.app',
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: walkProvider.routeCoordinates,
              strokeWidth: 5.0,
              color: AppColors.primaryGreen,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            if (walkProvider.routeCoordinates.isNotEmpty)
              Marker(
                point: walkProvider.routeCoordinates.last,
                width: 40,
                height: 40,
                child: const Icon(Icons.navigation, color: AppColors.primaryGreen, size: 40),
              )
            else
              Marker(
                point: widget.initialLocation,
                width: 40,
                height: 40,
                child: const Icon(Icons.navigation, color: AppColors.primaryGreen, size: 30),
              ),
          ],
        ),
      ],
    );
  }
}
