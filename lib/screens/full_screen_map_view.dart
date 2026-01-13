import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../utils/theme_config.dart';

/// 지도 전체 화면 보기
class FullScreenMapView extends StatelessWidget {
  final List<LatLng> points;

  const FullScreenMapView({
    super.key,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('산책 경로'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: points.isNotEmpty 
              ? points[points.length ~/ 2] 
              : const LatLng(37.5665, 126.9780),
          initialZoom: 16.0,
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
                  strokeWidth: 6.0,
                  color: AppColors.primaryGreen,
                ),
              ],
            ),
          // 시작점과 끝점 표시 (선택 사항)
          if (points.isNotEmpty) ...[
            MarkerLayer(
              markers: [
                Marker(
                  point: points.first,
                  width: 12,
                  height: 12,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
                    ),
                  ),
                ),
                Marker(
                  point: points.last,
                  width: 12,
                  height: 12,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
