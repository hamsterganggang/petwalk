import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../utils/theme_config.dart';
import 'full_screen_map_view.dart';

class WalkDetailView extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> walkData;

  const WalkDetailView({
    super.key,
    required this.docId,
    required this.walkData,
  });

  @override
  Widget build(BuildContext context) {
    final startTime = (walkData['startTime'] as Timestamp).toDate();
    final endTime = (walkData['endTime'] as Timestamp).toDate();
    final distance = (walkData['totalDistance'] as num).toDouble();
    final memo = walkData['memo'] as String? ?? '';
    final mood = walkData['mood'] as String? ?? '😊';
    final routeData = walkData['route'] as List<dynamic>? ?? [];
    final petNames = walkData['petNames'] as List<dynamic>? ?? [];
    final imageUrls = walkData['imageUrls'] as List<dynamic>? ?? [];

    final List<LatLng> points = routeData.map((p) {
      return LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble());
    }).toList();

    final duration = endTime.difference(startTime);

    return Scaffold(
      appBar: AppBar(
        title: const Text('산책 상세 정보'),
        actions: [
          IconButton(
            icon: const Icon(Icons.fullscreen),
            onPressed: () => _navigateToFullScreenMap(context, points),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 지도 영역 (크기 키움: 350)
            GestureDetector(
              onTap: () => _navigateToFullScreenMap(context, points),
              child: Stack(
                children: [
                  SizedBox(
                    height: 350,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: points.isNotEmpty 
                            ? points[points.length ~/ 2] 
                            : const LatLng(37.5665, 126.9780),
                        initialZoom: 15.0,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none, // 상세뷰에서는 조작 방지 (탭하여 이동 유도)
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.petwalk.app',
                        ),
                        if (points.isNotEmpty)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: points,
                                strokeWidth: 5.0,
                                color: AppColors.primaryGreen,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  // 지도 위에 안내 문구 표시
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.zoom_out_map, color: Colors.white, size: 14),
                          SizedBox(width: 6),
                          Text(
                            '지도를 눌러 크게 보기',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 함께한 친구들 표시
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.pets, color: AppColors.primaryGreen, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            petNames.isEmpty ? '혼자 산책함' : petNames.join(', '),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(startTime),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(mood, style: const TextStyle(fontSize: 24)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${DateFormat('HH:mm:ss').format(startTime)} ~ ${DateFormat('HH:mm:ss').format(endTime)}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const Divider(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoItem('거리', '${distance.toStringAsFixed(2)} km'),
                      _buildInfoItem('시간', _formatDuration(duration)),
                    ],
                  ),
                  const Divider(height: 32),
                  
                  // 인증 사진 표시
                  if (imageUrls.isNotEmpty) ...[
                    const Text(
                      '산책 인증 사진',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrls.first,
                        width: double.infinity,
                        height: 250,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 200,
                          color: Colors.grey[200],
                          child: const Icon(Icons.error),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  const Text(
                    '산책 메모',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(memo, style: const TextStyle(fontSize: 15)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToFullScreenMap(BuildContext context, List<LatLng> points) {
    if (points.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenMapView(points: points),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours시간 $minutes분 $seconds초';
    } else if (minutes > 0) {
      return '$minutes분 $seconds초';
    } else {
      return '$seconds초';
    }
  }
}
