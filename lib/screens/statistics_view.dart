import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../services/walk_record_service.dart';
import '../utils/chart_data_helper.dart';
import '../utils/theme_config.dart';

class StatisticsView extends StatelessWidget {
  const StatisticsView({super.key});

  @override
  Widget build(BuildContext context) {
    final recordService = WalkRecordService();

    return Scaffold(
      appBar: AppBar(title: const Text('산책 통계')),
      body: StreamBuilder<QuerySnapshot>(
        stream: recordService.fetchWalkHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('통계를 위한 데이터가 부족합니다.'));
          }

          final docs = snapshot.data!.docs;
          final weeklyData = ChartDataHelper.calculateWeeklyStats(docs);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '이번 주 활동 (km)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 300,
                  child: _buildBarChart(weeklyData),
                ),
                const SizedBox(height: 40),
                _buildSummaryCard(docs),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBarChart(Map<String, double> data) {
    final days = ['월', '화', '수', '목', '금', '토', '일'];
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _getMaxY(data) + 1,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${days[group.x.toInt()]}\n',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                children: <TextSpan>[
                  TextSpan(
                    text: '${rod.toY.toStringAsFixed(2)} km',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value >= days.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    days[value.toInt()],
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(days.length, (index) {
          final day = days[index];
          final value = data[day] ?? 0.0;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: value,
                color: AppColors.primaryGreen,
                width: 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
      ),
    );
  }

  double _getMaxY(Map<String, double> data) {
    double max = 0;
    data.forEach((key, value) {
      if (value > max) max = value;
    });
    return max == 0 ? 5 : max;
  }

  Widget _buildSummaryCard(List<QueryDocumentSnapshot> docs) {
    double totalDistance = 0;
    for (var doc in docs) {
      totalDistance += (doc.data() as Map<String, dynamic>)['totalDistance'] ?? 0;
    }

    return Card(
      elevation: 0,
      color: AppColors.lightGreen.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSummaryItem('총 산책 횟수', '${docs.length}회'),
            Container(width: 1, height: 40, color: Colors.green.withOpacity(0.2)),
            _buildSummaryItem('총 이동 거리', '${totalDistance.toStringAsFixed(2)} km'),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
      ],
    );
  }
}
