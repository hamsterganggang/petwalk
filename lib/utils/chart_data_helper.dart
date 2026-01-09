import 'package:cloud_firestore/cloud_firestore.dart';

class ChartDataHelper {
  static Map<String, double> calculateWeeklyStats(List<QueryDocumentSnapshot> docs) {
    Map<String, double> weeklyData = {
      '월': 0,
      '화': 0,
      '수': 0,
      '목': 0,
      '금': 0,
      '토': 0,
      '일': 0,
    };

    final now = DateTime.now();
    // Monday is 1 in DateTime.weekday
    final lastMonday = now.subtract(Duration(days: now.weekday - 1));
    final startOfMonday = DateTime(lastMonday.year, lastMonday.month, lastMonday.day);

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final startTimeTimestamp = data['startTime'] as Timestamp?;
      if (startTimeTimestamp == null) continue;
      
      final startTime = startTimeTimestamp.toDate(); // Converts UTC from Firebase to device local time (KST)
      
      if (startTime.isAfter(startOfMonday)) {
        final dayName = _getDayName(startTime.weekday);
        final distance = (data['totalDistance'] as num?)?.toDouble() ?? 0.0;
        weeklyData[dayName] = (weeklyData[dayName] ?? 0) + distance;
      }
    }

    return weeklyData;
  }

  static String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return '월';
      case 2: return '화';
      case 3: return '수';
      case 4: return '목';
      case 5: return '금';
      case 6: return '토';
      case 7: return '일';
      default: return '';
    }
  }
}
