import 'package:flutter/material.dart';
import '../utils/theme_config.dart';
import 'animal_list_view.dart';

/// 반려동물 탭 화면
class PetsTab extends StatelessWidget {
  const PetsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('반려동물'),
        automaticallyImplyLeading: false,
      ),
      body: const AnimalListView(),
    );
  }
}
