import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

/// 산책 기록 공유 서비스
class ShareService {
  /// 산책 기록 공유
  /// 
  /// [walkData] 산책 기록 데이터 (Map 또는 객체)
  /// 반환: 공유 성공 여부
  Future<bool> shareWalkRecord(Map<String, dynamic> walkData) async {
    try {
      final startTime = walkData['startTime'];
      final endTime = walkData['endTime'];
      final totalDistance = walkData['totalDistance'] as num?;
      final memo = walkData['memo'] as String?;
      final mood = walkData['mood'] as String? ?? '😊';

      DateTime? startDateTime;
      DateTime? endDateTime;

      // Timestamp를 DateTime으로 변환
      if (startTime != null) {
        if (startTime is DateTime) {
          startDateTime = startTime;
        } else {
          // Timestamp인 경우
          try {
            startDateTime = (startTime as dynamic).toDate();
          } catch (e) {
            startDateTime = DateTime.now();
          }
        }
      }

      if (endTime != null) {
        if (endTime is DateTime) {
          endDateTime = endTime;
        } else {
          try {
            endDateTime = (endTime as dynamic).toDate();
          } catch (e) {
            endDateTime = DateTime.now();
          }
        }
      }

      // 산책 시간 계산
      String durationText = '';
      if (startDateTime != null && endDateTime != null) {
        final duration = endDateTime.difference(startDateTime);
        final hours = duration.inHours;
        final minutes = duration.inMinutes % 60;

        if (hours > 0) {
          durationText = '${hours}시간 ${minutes}분';
        } else {
          durationText = '${minutes}분';
        }
      }

      // 거리 포맷팅
      String distanceText = '';
      if (totalDistance != null) {
        final distance = totalDistance.toDouble();
        if (distance >= 1.0) {
          distanceText = '${distance.toStringAsFixed(1)}km';
        } else {
          distanceText = '${(distance * 1000).toStringAsFixed(0)}m';
        }
      }

      // 공유 텍스트 생성
      final shareText = _buildShareText(
        duration: durationText,
        distance: distanceText,
        mood: mood,
        memo: memo,
      );

      await Share.share(shareText);
      return true;
    } catch (e) {
      print('공유 오류: $e');
      return false;
    }
  }

  /// 공유 텍스트 생성
  String _buildShareText({
    required String duration,
    required String distance,
    required String mood,
    String? memo,
  }) {
    final buffer = StringBuffer();
    
    buffer.writeln('$mood 오늘 반려동물과 함께 산책 완료! 🐾');
    buffer.writeln('');
    
    if (duration.isNotEmpty) {
      buffer.writeln('⏱ 산책 시간: $duration');
    }
    
    if (distance.isNotEmpty) {
      buffer.writeln('📍 산책 거리: $distance');
    }
    
    if (memo != null && memo.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('💭 $memo');
    }
    
    buffer.writeln('');
    buffer.writeln('Paperlogy 앱에서 더 많은 산책 기록을 확인하세요!');

    return buffer.toString();
  }

  /// 간단한 텍스트 공유
  /// 
  /// [text] 공유할 텍스트
  Future<bool> shareText(String text) async {
    try {
      await Share.share(text);
      return true;
    } catch (e) {
      print('텍스트 공유 오류: $e');
      return false;
    }
  }
}
