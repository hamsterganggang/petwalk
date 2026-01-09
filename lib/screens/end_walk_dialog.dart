import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/walk_session_provider.dart';
import '../services/walk_record_service.dart';

class EndWalkDialog extends StatefulWidget {
  const EndWalkDialog({super.key});

  @override
  State<EndWalkDialog> createState() => _EndWalkDialogState();
}

class _EndWalkDialogState extends State<EndWalkDialog> {
  final _memoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedMood = '😊';
  final List<String> _moods = ['😊', '😎', '🐾', '😴', '🥵'];
  bool _isSaving = false;

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _saveAndFinish() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    
    final walkProvider = context.read<WalkSessionProvider>();
    final recordService = WalkRecordService();

    try {
      await recordService.saveWalkData(
        startTime: walkProvider.startTime ?? DateTime.now(),
        endTime: DateTime.now(),
        totalDistance: walkProvider.totalDistance,
        routeCoordinates: walkProvider.routeCoordinates,
        memo: _memoController.text,
        mood: _selectedMood,
      );
      
      walkProvider.reset();
      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('산책 종료'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _memoController,
                decoration: const InputDecoration(
                  labelText: '메모',
                  hintText: '오늘 산책은 어땠나요?',
                ),
                maxLines: 3,
                validator: (value) =>
                    (value == null || value.isEmpty) ? '메모를 입력해주세요' : null,
              ),
              const SizedBox(height: 16),
              const Text('오늘의 기분'),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _moods.map((mood) {
                  return GestureDetector(
                    onTap: () => setState(() => _selectedMood = mood),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _selectedMood == mood
                            ? Theme.of(context).primaryColor.withOpacity(0.2)
                            : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(mood, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveAndFinish,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('저장하기'),
        ),
      ],
    );
  }
}
