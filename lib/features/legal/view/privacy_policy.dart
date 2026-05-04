import 'package:flutter/material.dart';
import 'package:lccu_finx/app/app_constants.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Last Updated: December 9, 2025',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              '1. Introduction',
              'Laborie Co-operative Credit Union Ltd ("LCCU", "we", "us", or "our") respects your privacy and is committed to protecting your personal information. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use the LCCU FinX application ("the App").\n\n'
                  'By using the App, you consent to the data practices described in this policy.',
            ),
            _buildSection(
              context,
              '2. Information We Collect',
              '2.1 Personal Information\n'
                  'We collect personal information that you provide directly:\n'
                  '• Account Information: Name, email address, phone number, date of birth\n'
                  '• Authentication Data: Username, password (encrypted), role assignment\n'
                  '• Student Information: Student ID, class assignment, school affiliation\n'
                  '• Guardian Information: Guardian-student relationships, contact details\n\n'
                  '2.2 Financial Information\n'
                  '• Account balances\n'
                  '• Transaction history (deposits, withdrawals, contributions)\n'
                  '• Pending deposits and discrepancies\n'
                  '• Payment information processed through the App\n\n'
                  '2.3 Usage Information\n'
                  '• Device information (model, operating system, unique device identifiers)\n'
                  '• Log data (IP address, access times, app features used)\n'
                  '• Error reports and performance data\n\n'
                  '2.4 Location Information\n'
                  'We may collect location data if you grant permission, used for security verification, fraud prevention, and service improvement.',
            ),
            _buildSection(
              context,
              '3. How We Use Your Information',
              '3.1 Service Provision\n'
                  '• Provide, operate, and maintain the App\n'
                  '• Process financial transactions\n'
                  '• Manage user accounts and authentication\n'
                  '• Generate reports and statements\n\n'
                  '3.2 Communication\n'
                  '• Send account notifications and updates\n'
                  '• Respond to inquiries and support requests\n'
                  '• Send administrative information about the App\n\n'
                  '3.3 Security and Fraud Prevention\n'
                  '• Detect and prevent fraudulent transactions\n'
                  '• Verify user identity\n'
                  '• Monitor for security threats\n'
                  '• Comply with legal obligations\n\n'
                  '3.4 Improvement and Analytics\n'
                  '• Analyze usage patterns to improve the App\n'
                  '• Develop new features and services\n'
                  '• Conduct research and data analysis',
            ),
            _buildSection(
              context,
              '4. Information Sharing and Disclosure',
              '4.1 Within LCCU\n'
                  'We share information internally on a need-to-know basis with administrators, principals, teachers, and tellers based on their role permissions.\n\n'
                  '4.2 Third-Party Service Providers\n'
                  'We may share information with trusted third parties who assist us in data storage and hosting (Supabase), authentication services, analytics, and technical support.\n\n'
                  '4.3 Legal Requirements\n'
                  'We may disclose information when required by law or to comply with legal processes, enforce our Terms of Use, protect rights and safety, or prevent fraud.\n\n'
                  '4.4 Business Transfers\n'
                  'In the event of a merger, acquisition, or sale of assets, user information may be transferred as part of that transaction.',
            ),
            _buildSection(
              context,
              '5. Data Security',
              '5.1 Security Measures\n'
                  '• Encryption of data in transit and at rest\n'
                  '• Secure authentication mechanisms\n'
                  '• Regular security assessments\n'
                  '• Access controls and user permissions\n'
                  '• Monitoring for suspicious activity\n\n'
                  '5.2 Limitations\n'
                  'While we strive to protect your information, no method of transmission or storage is 100% secure. We cannot guarantee absolute security.',
            ),
            _buildSection(
              context,
              '6. Data Retention',
              'We retain your information for as long as necessary to provide the App services, comply with legal, regulatory, and accounting requirements, resolve disputes, and enforce our agreements.\n\n'
                  'Account information and transaction history are typically retained for a minimum of 7 years for regulatory compliance.',
            ),
            _buildSection(
              context,
              '7. Your Rights and Choices',
              '7.1 Access and Correction\n'
                  'You have the right to access your personal information, request corrections to inaccurate data, and request a copy of your data.\n\n'
                  '7.2 Data Deletion\n'
                  'You may request deletion of your account and associated data, subject to legal and regulatory retention requirements.\n\n'
                  '7.3 Opt-Out Options\n'
                  'You may opt out of non-essential communications, location tracking, and analytics cookies. Note: Opting out of certain data collection may limit App functionality.',
            ),
            _buildSection(
              context,
              '8. Children\'s Privacy',
              'The App is designed for educational institutions and may be used by minors under the supervision of guardians and educators. We:\n'
                  '• Collect only necessary information from student accounts\n'
                  '• Require parental/guardian consent for student accounts\n'
                  '• Limit access to student information based on role permissions\n'
                  '• Do not use student data for marketing purposes\n\n'
                  'Parents/guardians have the right to review, modify, or delete their child\'s information by contacting LCCU.',
            ),
            _buildSection(
              context,
              '9. International Data Transfers',
              'Your information may be transferred to and processed in countries other than your country of residence. We ensure appropriate safeguards are in place to protect your information in accordance with this Privacy Policy.',
            ),
            _buildSection(
              context,
              '10. Changes to This Privacy Policy',
              'We may update this Privacy Policy from time to time. Changes will be posted within the App with an updated "Last Updated" date. Continued use of the App after changes constitutes acceptance of the updated policy.',
            ),
            _buildSection(
              context,
              '11. Contact Us',
              'For questions, concerns, or requests regarding this Privacy Policy or your personal information, please contact:\n\n'
                  'Laborie Co-operative Credit Union Ltd\n'
                  'Email: schoolthrift@mylaboriecu.com\n'
                  'Phone: 758-459-6900\n'
                  'Address: Allan Louisy Street, Laborie, Saint Lucia, W.I.',
            ),
            _buildSection(
              context,
              '12. Your Consent',
              'By using LCCU FinX, you acknowledge that you have read and understood this Privacy Policy and consent to the collection, use, and disclosure of your information as described herein.',
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Effective Date: December 9, 2025',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(content, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
