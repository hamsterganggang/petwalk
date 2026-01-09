import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/walk_session_provider.dart';
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
  }

  Future<void> _initializeMap() async {
    final hasPermission = await LocationPermissionHelper.requestLocationPermission();
    if (hasPermission) {
      try {
        final position = await Geolocator.getCurrentPosition();
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
      // If already following, turn it off (toggle off)
      setState(() => _followUser = false);
    } else {
      // If not following, turn it on and move to current location
      try {
        final position = await Geolocator.getCurrentPosition();
        final latLng = LatLng(position.latitude, position.longitude);
        setState(() {
          _currentLocation = latLng;
          _followUser = true;
        });
        _mapController.move(latLng, _mapController.camera.zoom);
      } catch (e) {
        debugPrint('Error getting current location: $e');
      }
    }
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
                    // Manual drag/pinch by user disables follow mode
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
                    : () => walkProvider.startTracking(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: walkProvider.isTracking ? Colors.redAccent : AppColors.primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  walkProvider.isTracking ? '산책 종료' : '산책 시작',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
        widget.mapController.move(walkProvider.routeCoordinates.last, widget.mapController.camera.zoom);
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
