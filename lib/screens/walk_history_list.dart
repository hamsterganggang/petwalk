import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/walk_record_service.dart';
import 'walk_detail_view.dart';

class WalkHistoryList extends StatelessWidget {
  const WalkHistoryList({super.key});

  @override
  Widget build(BuildContext context) {
    final recordService = WalkRecordService();

    return Scaffold(
      appBar: AppBar(title: const Text('산책 기록')),
      body: StreamBuilder<QuerySnapshot>(
        stream: recordService.fetchWalkHistory(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    const Text('데이터를 불러오지 못했습니다.'),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('저장된 산책 기록이 없습니다.'),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final docId = doc.id;
              
              final startTimeTimestamp = data['startTime'] as Timestamp?;
              if (startTimeTimestamp == null) return const SizedBox.shrink();
              
              final startTime = startTimeTimestamp.toDate();
              final distance = (data['totalDistance'] as num?)?.toDouble() ?? 0.0;
              final mood = data['mood'] as String? ?? '😊';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Text(mood, style: const TextStyle(fontSize: 20)),
                  ),
                  title: Text(
                    DateFormat('yyyy.MM.dd (E) HH:mm:ss', 'ko_KR').format(startTime),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${distance.toStringAsFixed(2)} km • ${data['memo'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WalkDetailView(
                          docId: docId,
                          walkData: data,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
