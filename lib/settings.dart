import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'terms_of_use.dart';
import 'privacy_policy.dart';
import 'auth_vm.dart';
import 'auth_gate.dart';
import 'admin_repo.dart';
import 'supabase_config.dart';
import 'app_constants.dart';
import 'friendly_error.dart';

class SettingsAboutPage extends StatelessWidget {
  const SettingsAboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authVm = AuthScope.of(context);
    final user = supabase.auth.currentUser;
    final userEmail = user?.email ?? 'Not logged in';
    final userRole = authVm.role?.name ?? 'N/A';
    const version = '1.0.0+1';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 8,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        children: [
          // App Info Section
          _buildSectionHeader('About LCCU FinX'),
          ListTile(
            leading: const Icon(
              Icons.info_outline,
              color: AppColors.primaryBlue,
            ),
            title: const Text('Version'),
            subtitle: const Text(version),
          ),
          ListTile(
            leading: Image.asset(
              AppAssets.lccuLogo,
              width: 40,
              height: 40,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.account_balance,
                color: AppColors.primaryBlue,
              ),
            ),
            title: const Text('Laborie Co-operative Credit Union Ltd'),
            subtitle: const Text('Financial management for students'),
          ),
          const Divider(),

          // Account Section
          _buildSectionHeader('Account Information'),
          ListTile(
            leading: const Icon(
              Icons.person_outline,
              color: AppColors.primaryBlue,
            ),
            title: const Text('Email'),
            subtitle: Text(userEmail),
          ),
          ListTile(
            leading: const Icon(
              Icons.badge_outlined,
              color: AppColors.primaryBlue,
            ),
            title: const Text('Role'),
            subtitle: Text(userRole.toUpperCase()),
          ),
          const Divider(),

          // Legal Section
          _buildSectionHeader('Legal & Privacy'),
          ListTile(
            leading: const Icon(
              Icons.description_outlined,
              color: AppColors.primaryBlue,
            ),
            title: const Text('Terms of Use'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const TermsOfUsePage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.privacy_tip_outlined,
              color: AppColors.primaryBlue,
            ),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PrivacyPolicyPage(),
                ),
              );
            },
          ),
          const Divider(),

          // Support Section
          _buildSectionHeader('Support'),
          ListTile(
            leading: const Icon(
              Icons.email_outlined,
              color: AppColors.primaryBlue,
            ),
            title: const Text('Contact Support'),
            subtitle: const Text('schoolthrift@mylaboriecu.com'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              final userName =
                  '${user?.userMetadata?['first_name'] ?? ''} ${user?.userMetadata?['last_name'] ?? ''}'
                      .trim();
              _openEmailClient(context, userEmail, userName);
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.help_outline,
              color: AppColors.primaryBlue,
            ),
            title: const Text('Help & Documentation'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Help documentation coming soon')),
              );
            },
          ),
          const Divider(),

          // Actions Section
          _buildSectionHeader('Actions'),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out'),
            trailing: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            onTap: () async {
              // Confirm sign out
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && context.mounted) {
                try {
                  await authVm.signOut();
                  if (context.mounted) {
                    Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) =>
                            AuthGate(adminRepo: SupabaseAdminRepo(supabase)),
                      ),
                      (r) => false,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(friendlyActionError('Error signing out.', e))),
                    );
                  }
                }
              }
            },
          ),

          const SizedBox(height: 24),

          // Footer
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Image.asset(
                  AppAssets.icon,
                  width: 60,
                  height: 60,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.savings,
                    size: 60,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '© 2025 Laborie Co-operative Credit Union Ltd',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const Text(
                  'All rights reserved',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Future<void> _openEmailClient(
    BuildContext context,
    String userEmail,
    String userName,
  ) async {
    final supportEmail = 'schoolthrift@mylaboriecu.com';
    final subject = Uri.encodeComponent('Support Request - LCCU FinX');
    final body = Uri.encodeComponent(
      'From: ${userName.isNotEmpty ? userName : 'User'}\n'
      'Reply to: $userEmail\n\n'
      'Please describe your issue:\n\n',
    );

    final emailUri = Uri.parse(
      'mailto:$supportEmail?subject=$subject&body=$body',
    );

    try {
      final launched = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open email client. Please ensure you have an email app installed.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyActionError('Error opening email.', e)),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

class _SupportFormDialog extends StatefulWidget {
  final String userEmail;
  final String userName;
  const _SupportFormDialog({required this.userEmail, required this.userName});

  @override
  State<_SupportFormDialog> createState() => _SupportFormDialogState();
}

class _SupportFormDialogState extends State<_SupportFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.userEmail;
    _nameController.text = widget.userName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSending = true);

    try {
      final supportEmail = 'schoolthrift@mylaboriecu.com';
      final subject = Uri.encodeComponent(_subjectController.text.trim());
      final body = Uri.encodeComponent(
        'From: ${_nameController.text.trim()}\n'
        'Email: ${_emailController.text.trim()}\n'
        'Subject: ${_subjectController.text.trim()}\n\n'
        'Message:\n${_messageController.text.trim()}',
      );

      final emailUri = Uri.parse(
        'mailto:$supportEmail?subject=$subject&body=$body',
      );

      final canLaunch = await canLaunchUrl(emailUri);
      if (canLaunch) {
        final launched = await launchUrl(
          emailUri,
          mode: LaunchMode.externalApplication,
        );
        if (!mounted) return;
        if (launched) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Opening email client...'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not open email client. Please email $supportEmail directly.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open email client. Please email $supportEmail directly.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyActionError('Action failed.', e)), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Contact Support'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Your Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                  counterText: '',
                ),
                maxLength: 100,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  if (value.length > 100) {
                    return 'Name must be 100 characters or less';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Your Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                  counterText: '',
                ),
                keyboardType: TextInputType.emailAddress,
                maxLength: 255,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.subject_outlined),
                  counterText: '',
                ),
                maxLength: 200,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a subject';
                  }
                  if (value.length > 200) {
                    return 'Subject must be 200 characters or less';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                  helperText: 'Maximum 2000 characters',
                ),
                maxLines: 5,
                maxLength: 2000,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your message';
                  }
                  if (value.length > 2000) {
                    return 'Message must be 2000 characters or less';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSending ? null : _sendEmail,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
          ),
          child: _isSending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}
