import 'package:flutter/material.dart';

class RecommendationsScreen extends StatelessWidget {
  const RecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('რეკომენდაციები'),
        backgroundColor: const Color(0xFF2D6A4F),
      ),
      body: const Center(child: Text('რეკომენდაციები')),
    );
  }
}
