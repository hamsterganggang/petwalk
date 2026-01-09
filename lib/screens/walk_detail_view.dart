import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../utils/theme_config.dart';

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

    final List<LatLng> points = routeData.map((p) {
      return LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble());
    }).toList();

    final duration = endTime.difference(startTime);

    return Scaffold(
      appBar: AppBar(
        title: const Text('산책 상세 정보'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 300,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: points.isNotEmpty 
                      ? points[points.length ~/ 2] 
                      : const LatLng(37.5665, 126.9780),
                  initialZoom: 15.0,
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
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
