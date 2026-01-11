import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Policy',
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
              '''Greenhouse IoT Application ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application.

Please read this Privacy Policy carefully. If you do not agree with our policies and practices, please do not use our application.''',
            ),
            _buildSection(
              'Information We Collect',
              '''We may collect information about you in a variety of ways. The information we may collect on the application includes:

Personal Information:
- Email address
- Name (optional)
- Account credentials

Device Information:
- Device IDs (ESP32 identifiers)
- Device names and locations
- Sensor readings (temperature, humidity, soil moisture, light levels)
- Device status and connection information

Usage Information:
- Application interactions and features used
- Access times and duration
- Device and browser information''',
            ),
            _buildSection(
              'How We Use Your Information',
              '''We use the information we collect in the following ways:

1. To Provide Services:
   - Enable device registration and management
   - Display real-time sensor data
   - Send alerts and notifications based on alert rules
   - Maintain account functionality

2. To Improve Services:
   - Analyze usage patterns to improve application features
   - Perform troubleshooting and debugging
   - Ensure application security and stability

3. To Communicate:
   - Send service notifications and updates
   - Respond to your inquiries
   - Send important account information

4. To Protect:
   - Prevent fraudulent activity
   - Enforce our terms and conditions
   - Protect user safety and rights''',
            ),
            _buildSection(
              'Data Storage and Security',
              '''Your information is stored on secure servers with appropriate safeguards. We implement industry-standard security measures including:

- Encryption of data in transit and at rest
- Secure authentication mechanisms
- Regular security audits
- Access controls and authentication

However, no method of transmission over the Internet or electronic storage is completely secure. While we strive to protect your information, we cannot guarantee absolute security.''',
            ),
            _buildSection(
              'Data Retention',
              '''We retain your personal information for as long as your account is active or as long as necessary to provide you with our services.

You may request deletion of your account and associated data at any time. Upon request, we will delete your personal information within 30 days, except where we are required to retain it by law.

Historical sensor data will be retained for 1 year to enable analytics and trending.''',
            ),
            _buildSection(
              'Third-Party Services',
              '''Our application integrates with third-party services including:

- Firebase Cloud Messaging (for push notifications)
- Google Sign-In (for authentication)
- Facebook Login (for authentication)

These services have their own privacy policies. We recommend reviewing their policies as we are not responsible for their privacy practices.''',
            ),
            _buildSection('User Rights', '''You have the right to:

- Access your personal information
- Correct inaccurate information
- Request deletion of your data
- Opt-out of marketing communications
- Request a copy of your data in portable format

To exercise these rights, please contact us at privacy@greenhouse-iot.com'''),
            _buildSection(
              'Children\'s Privacy',
              '''Our application is not intended for users under 13 years of age. We do not knowingly collect information from children under 13. If we become aware that we have collected information from a child under 13, we will take steps to delete such information immediately.''',
            ),
            _buildSection(
              'Changes to Privacy Policy',
              '''We may update this Privacy Policy periodically. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last updated" date.

Your continued use of the application following the posting of changes constitutes your acceptance of those changes.''',
            ),
            _buildSection(
              'Contact Us',
              '''If you have any questions about this Privacy Policy or our privacy practices, please contact us at:

Email: privacy@greenhouse-iot.com
Support: support@greenhouse-iot.com

We will respond to your inquiries within 30 days.''',
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
