import 'package:flutter/material.dart';

class RecommendationsScreen extends StatelessWidget {
  final String language;

  const RecommendationsScreen({super.key, this.language = 'ka'});

  String _t(String georgian, String english) {
    return language == 'en' ? english : georgian;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('რეკომენდაციები', 'Recommendations')),
        backgroundColor: const Color(0xFF2D6A4F),
      ),
      body: Center(child: Text(_t('რეკომენდაციები', 'Recommendations'))),
    );
  }
}
