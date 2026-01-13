import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/theme_config.dart';
import '../services/like_service.dart';
import '../services/walk_record_service.dart';
import 'full_screen_map_view.dart';

class WalkDetailView extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> walkData;

  const WalkDetailView({
    super.key,
    required this.docId,
    required this.walkData,
  });

  @override
  State<WalkDetailView> createState() => _WalkDetailViewState();
}

class _WalkDetailViewState extends State<WalkDetailView> {
  final LikeService _likeService = LikeService();
  final WalkRecordService _walkService = WalkRecordService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isLikeLoading = true;
  late bool _isPublic;
  late String _memo;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.walkData['likeCount'] ?? 0;
    _isPublic = widget.walkData['isPublic'] ?? true;
    _memo = widget.walkData['memo'] as String? ?? '';
    _checkInitialLikeStatus();
  }

  Future<void> _checkInitialLikeStatus() async {
    try {
      final likesMap = await _likeService.checkLikesStatus([widget.docId]);
      if (mounted) {
        setState(() {
          _isLiked = likesMap[widget.docId] ?? false;
          _isLikeLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLikeLoading = false);
    }
  }

  Future<void> _toggleLike() async {
    final originalStatus = _isLiked;
    final originalCount = _likeCount;
    setState(() { _isLiked = !_isLiked; _likeCount += _isLiked ? 1 : -1; });
    try { await _likeService.toggleLike(widget.docId); } catch (e) {
      if (mounted) setState(() { _isLiked = originalStatus; _likeCount = originalCount; });
    }
  }

  /// 더보기 메뉴 표시
  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('메모 수정하기'),
              onTap: () {
                Navigator.pop(context);
                _showEditMemoDialog();
              },
            ),
            ListTile(
              leading: Icon(_isPublic ? Icons.lock_outline : Icons.public),
              title: Text(_isPublic ? '비공개로 전환' : '공개로 전환'),
              onTap: () async {
                Navigator.pop(context);
                await _toggleVisibility();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('삭제하기', style: TextStyle(color: AppColors.error)),
              onTap: () async {
                Navigator.pop(context);
                _confirmDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 메모 수정 다이얼로그
  void _showEditMemoDialog() {
    final controller = TextEditingController(text: _memo);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('메모 수정'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '산책에 대한 메모를 남겨주세요.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () async {
              final newMemo = controller.text.trim();
              Navigator.pop(context);
              await _updateMemo(newMemo);
            },
            child: const Text('저장', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateMemo(String newMemo) async {
    try {
      await _walkService.updateMemo(widget.docId, newMemo);
      if (mounted) {
        setState(() => _memo = newMemo);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('메모가 수정되었습니다.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('메모 수정 중 오류가 발생했습니다.')));
    }
  }

  Future<void> _toggleVisibility() async {
    try {
      final newStatus = !_isPublic;
      await _walkService.updateVisibility(widget.docId, newStatus);
      if (mounted) {
        setState(() => _isPublic = newStatus);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newStatus ? '게시물이 공개되었습니다.' : '게시물이 비공개 처리되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('설정 변경 중 오류가 발생했습니다.')));
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기록 삭제'),
        content: const Text('이 산책 기록을 정말 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteRecord();
            },
            child: const Text('삭제', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRecord() async {
    try {
      await _walkService.deleteWalkRecord(widget.docId);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('기록이 삭제되었습니다.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('삭제 중 오류가 발생했습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final startTime = (widget.walkData['startTime'] as Timestamp).toDate();
    final endTime = (widget.walkData['endTime'] as Timestamp).toDate();
    final distance = (widget.walkData['totalDistance'] as num).toDouble();
    final mood = widget.walkData['mood'] as String? ?? '😊';
    final routeData = widget.walkData['route'] as List<dynamic>? ?? [];
    final petNames = widget.walkData['petNames'] as List<dynamic>? ?? [];
    final imageUrls = widget.walkData['imageUrls'] as List<dynamic>? ?? [];
    final isMine = widget.walkData['userId'] == _currentUserId;

    final List<LatLng> points = routeData.map((p) {
      return LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('산책 상세 정보'),
        actions: [
          IconButton(icon: const Icon(Icons.fullscreen), onPressed: () => _navigateToFullScreenMap(context, points)),
          if (isMine)
            IconButton(icon: const Icon(Icons.more_vert), onPressed: _showMoreMenu),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMapSection(points),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLikeAndHeader(startTime, endTime),
                  const Divider(height: 32),
                  _buildPetInfo(petNames, mood),
                  const SizedBox(height: 24),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _buildInfoItem('거리', '${distance.toStringAsFixed(2)} km'),
                    _buildInfoItem('시간', _formatDuration(endTime.difference(startTime))),
                  ]),
                  const Divider(height: 32),
                  if (imageUrls.isNotEmpty) _buildImageSection(imageUrls.first),
                  const Text('산책 메모', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                    child: Text(_memo.isNotEmpty ? _memo : '기록된 메모가 없습니다.', style: const TextStyle(fontSize: 15)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSection(List<LatLng> points) {
    return GestureDetector(
      onTap: () => _navigateToFullScreenMap(context, points),
      child: Stack(
        children: [
          SizedBox(
            height: 350,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: points.isNotEmpty ? points[points.length ~/ 2] : const LatLng(37.5665, 126.9780),
                initialZoom: 15.0,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.petwalk.app'),
                if (points.isNotEmpty) PolylineLayer(polylines: [Polyline(points: points, strokeWidth: 5.0, color: AppColors.primaryGreen)]),
              ],
            ),
          ),
          Positioned(bottom: 16, right: 16, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(20)), child: const Row(children: [Icon(Icons.zoom_out_map, color: Colors.white, size: 14), SizedBox(width: 6), Text('지도를 눌러 크게 보기', style: TextStyle(color: Colors.white, fontSize: 12))]))),
        ],
      ),
    );
  }

  Widget _buildLikeAndHeader(DateTime start, DateTime end) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(start), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text('${DateFormat('HH:mm').format(start)} ~ ${DateFormat('HH:mm').format(end)}', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        ]),
        Row(children: [
          _isLikeLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : IconButton(icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border, color: _isLiked ? Colors.red : Colors.grey, size: 28), onPressed: _toggleLike),
          Text(_likeCount.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
      ],
    );
  }

  Widget _buildPetInfo(List petNames, String mood) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      decoration: BoxDecoration(color: AppColors.primaryGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3))),
      child: Row(children: [
        const Icon(Icons.pets, color: AppColors.primaryGreen, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(petNames.isEmpty ? '혼자 산책함' : petNames.join(', '), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen, fontSize: 15))),
        Text(mood, style: const TextStyle(fontSize: 20)),
      ]),
    );
  }

  Widget _buildImageSection(String url) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('산책 인증 사진', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(url, width: double.infinity, height: 250, fit: BoxFit.cover)),
      const SizedBox(height: 24),
    ]);
  }

  void _navigateToFullScreenMap(BuildContext context, List<LatLng> points) {
    if (points.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => FullScreenMapView(points: points)));
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(children: [Text(label, style: const TextStyle(color: Colors.grey)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]);
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    return hours > 0 ? '$hours시간 $minutes분' : '$minutes분';
  }
}
