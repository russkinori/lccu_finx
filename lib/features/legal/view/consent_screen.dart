import 'package:flutter/material.dart';
import 'package:lccu_finx/app/app_constants.dart';
import 'package:lccu_finx/features/legal/service/consent_service.dart';
import 'package:lccu_finx/features/legal/view/privacy_policy.dart';
import 'package:lccu_finx/features/legal/view/terms_of_use.dart';

/// Full-screen, non-dismissible consent gate shown on first login.
///
/// The user must check the acknowledgement box and tap Accept before they
/// can access the app. Acceptance is persisted via [ConsentService] so
/// subsequent logins skip this screen.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key, required this.onAccepted});

  /// Called after the user taps Accept and consent is persisted.
  final VoidCallback onAccepted;

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _checked = false;
  bool _saving = false;

  Future<void> _accept() async {
    if (!_checked || _saving) return;
    setState(() => _saving = true);
    await ConsentService.accept();
    if (mounted) widget.onAccepted();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.primaryBlue,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                child: Column(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Before you continue',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'LCCU FinX collects and processes personal and financial '
                      'information to operate the Schoolthrift programme. '
                      'Please review our policies before using the app.',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Scrollable policy links + checkbox
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // What we collect summary
                        _SummaryItem(
                          icon: Icons.person_outline,
                          title: 'Account & financial data',
                          description:
                              'Name, email, account balances, and transaction history — used solely to operate your savings account.',
                        ),
                        const SizedBox(height: 16),
                        _SummaryItem(
                          icon: Icons.storage_outlined,
                          title: 'Stored securely with Supabase',
                          description:
                              'Data is hosted in the United States and Singapore under a Data Processing Agreement with Supabase Inc.',
                        ),
                        const SizedBox(height: 16),
                        _SummaryItem(
                          icon: Icons.block_outlined,
                          title: 'Never sold or used for marketing',
                          description:
                              'Your data is never used for advertising, behavioural profiling, or shared with third parties for commercial purposes.',
                        ),
                        const SizedBox(height: 16),
                        _SummaryItem(
                          icon: Icons.child_care_outlined,
                          title: 'Children\'s privacy protected',
                          description:
                              'Student accounts are provisioned only by authorised staff. Guardian consent is required for all student enrolments.',
                        ),

                        const Divider(height: 32),

                        // Policy links
                        Text(
                          'Read the full documents',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        _PolicyLink(
                          label: 'Privacy Policy',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PrivacyPolicyPage(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        _PolicyLink(
                          label: 'Terms of Use',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TermsOfUsePage(),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Acknowledgement checkbox
                        InkWell(
                          onTap: () => setState(() => _checked = !_checked),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: _checked,
                                  onChanged: _saving
                                      ? null
                                      : (v) => setState(
                                            () => _checked = v ?? false,
                                          ),
                                  activeColor: AppColors.primaryBlue,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(top: 12),
                                    child: Text(
                                      'I have read and agree to the Privacy Policy '
                                      'and Terms of Use.',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Accept button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed:
                                (_checked && !_saving) ? _accept : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              disabledBackgroundColor: Colors.grey[300],
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Accept & Continue',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primaryBlue),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PolicyLink extends StatelessWidget {
  const _PolicyLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(Icons.open_in_new, size: 16, color: AppColors.primaryBlue),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.primaryBlue,
                decoration: TextDecoration.underline,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
