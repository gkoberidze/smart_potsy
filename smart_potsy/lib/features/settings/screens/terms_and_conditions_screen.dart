import 'package:flutter/material.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Terms and Conditions',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: January 2026',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Introduction',
              '''Welcome to Greenhouse IoT Application. These Terms and Conditions govern your use of our mobile application and services. By accessing and using this application, you accept and agree to be bound by the terms and provision of this agreement.

If you do not agree to abide by the above, please do not use this service.''',
            ),
            _buildSection(
              'User Accounts',
              '''When you create an account, you must provide accurate, complete, and current information. You are responsible for maintaining the confidentiality of your password and account information.

You agree to accept responsibility for all activities that occur under your account. You must notify us immediately of any unauthorized use of your account.''',
            ),
            _buildSection(
              'Device Registration',
              '''You are responsible for registering and managing your IoT devices through this application. You must ensure that you own or have permission to use all devices connected to your account.

We are not liable for any damages resulting from unauthorized device access or misuse.''',
            ),
            _buildSection(
              'Data and Privacy',
              '''Your use of the application is also governed by our Privacy Policy. Please review our Privacy Policy to understand our practices regarding the collection and use of your data.

We collect and process data from your devices to provide service functionality and improvements.''',
            ),
            _buildSection(
              'Limitation of Liability',
              '''In no event shall our company, its employees, or agents be liable for any indirect, incidental, special, consequential, or punitive damages, or any loss of profits or revenues, whether incurred directly or indirectly.

We provide the application on an "as-is" basis without warranties of any kind.''',
            ),
            _buildSection(
              'Changes to Terms',
              '''We reserve the right to modify these terms at any time. Your continued use of the application following the posting of revised terms means that you accept and agree to the changes.''',
            ),
            _buildSection(
              'Contact Us',
              '''If you have any questions about these Terms and Conditions, please contact us at support@greenhouse-iot.com''',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.6),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
