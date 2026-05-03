import 'package:flutter/material.dart';
import 'app_constants.dart';

class TermsOfUsePage extends StatelessWidget {
  const TermsOfUsePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Use'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terms of Use',
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
              '1. Acceptance of Terms',
              'By accessing and using the LCCU FinX application ("the App"), you accept and agree to be bound by these Terms of Use. If you do not agree to these terms, please do not use the App.',
            ),
            _buildSection(
              context,
              '2. Description of Service',
              'LCCU FinX is a financial management application provided by Laborie Co-operative Credit Union Ltd ("LCCU") for its members. The App provides:\n\n'
                  '• Account balance management\n'
                  '• Transaction history and reporting\n'
                  '• Deposit and withdrawal recording\n'
                  '• Financial tracking for students, guardians, teachers, principals, and tellers',
            ),
            _buildSection(
              context,
              '3. User Accounts and Access',
              '3.1 Account Registration\n'
                  '• Users are assigned accounts by LCCU administrators\n'
                  '• You are responsible for maintaining the confidentiality of your login credentials\n'
                  '• You must notify LCCU immediately of any unauthorized use of your account\n\n'
                  '3.2 User Roles\n'
                  'The App supports different user roles with varying permissions: Students, Guardians, Teachers, Principals, Tellers, and Administrators.',
            ),
            _buildSection(
              context,
              '4. Acceptable Use',
              'You agree to use the App only for lawful purposes and in accordance with these Terms. You agree NOT to:\n\n'
                  '• Use the App in any way that violates applicable laws or regulations\n'
                  '• Attempt to gain unauthorized access to any portion of the App\n'
                  '• Interfere with or disrupt the App\'s functionality\n'
                  '• Use the App to transmit any harmful code or malware\n'
                  '• Impersonate any person or entity\n'
                  '• Misrepresent your affiliation with LCCU',
            ),
            _buildSection(
              context,
              '5. Financial Transactions',
              '5.1 Transaction Accuracy\n'
                  '• All financial transactions processed through the App are subject to verification\n'
                  '• LCCU reserves the right to reverse transactions found to be erroneous or fraudulent\n'
                  '• Users are responsible for reviewing their transaction history regularly\n\n'
                  '5.2 Discrepancies\n'
                  '• Any discrepancies must be reported to LCCU within 30 days of the transaction date\n'
                  '• LCCU will investigate all reported discrepancies in good faith',
            ),
            _buildSection(
              context,
              '6. Data and Privacy',
              '• Your use of the App is also governed by our Privacy Policy\n'
                  '• LCCU collects and processes personal and financial data as described in the Privacy Policy\n'
                  '• You consent to such collection and processing by using the App',
            ),
            _buildSection(
              context,
              '7. Intellectual Property',
              '• The App and its original content, features, and functionality are owned by LCCU\n'
                  '• The App is protected by copyright, trademark, and other intellectual property laws\n'
                  '• You may not copy, modify, distribute, or reverse engineer any part of the App without written permission',
            ),
            _buildSection(
              context,
              '8. Disclaimers and Limitation of Liability',
              '8.1 Service Availability\n'
                  '• The App is provided "as is" and "as available"\n'
                  '• LCCU does not guarantee uninterrupted or error-free operation\n'
                  '• LCCU may suspend or discontinue the App at any time without notice\n\n'
                  '8.2 Limitation of Liability\n'
                  '• LCCU shall not be liable for any indirect, incidental, special, or consequential damages\n'
                  '• LCCU\'s total liability shall not exceed the amount of fees paid by you (if any) in the past 12 months',
            ),
            _buildSection(
              context,
              '9. Indemnification',
              'You agree to indemnify and hold LCCU harmless from any claims, damages, losses, liabilities, and expenses arising from:\n'
                  '• Your use of the App\n'
                  '• Your violation of these Terms\n'
                  '• Your violation of any rights of another party',
            ),
            _buildSection(
              context,
              '10. Modifications to Terms',
              'LCCU reserves the right to modify these Terms at any time. Changes will be effective immediately upon posting within the App. Your continued use of the App after changes constitutes acceptance of the modified Terms.',
            ),
            _buildSection(
              context,
              '11. Termination',
              'LCCU may terminate or suspend your access to the App immediately, without prior notice, for:\n'
                  '• Violation of these Terms\n'
                  '• Fraudulent or illegal activity\n'
                  '• At LCCU\'s sole discretion',
            ),
            _buildSection(
              context,
              '12. Governing Law',
              'These Terms shall be governed by and construed in accordance with the laws of the jurisdiction in which LCCU operates, without regard to conflict of law principles.',
            ),
            _buildSection(
              context,
              '13. Contact Information',
              'For questions about these Terms, please contact:\n\n'
                  'Laborie Co-operative Credit Union Ltd\n'
                  'Email: schoolthrift@mylaboriecu.com\n'
                  'Phone: 758-459-6900\n'
                  'Address: Allan Louisy Street, Laborie, Saint Lucia, W.I.',
            ),
            _buildSection(
              context,
              '14. Severability',
              'If any provision of these Terms is found to be unenforceable or invalid, that provision shall be limited or eliminated to the minimum extent necessary, and the remaining provisions shall remain in full force and effect.',
            ),
            _buildSection(
              context,
              '15. Entire Agreement',
              'These Terms, together with the Privacy Policy, constitute the entire agreement between you and LCCU regarding the use of the App.',
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'By using LCCU FinX, you acknowledge that you have read, understood, and agree to be bound by these Terms of Use.',
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
