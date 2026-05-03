import 'package:flutter/material.dart';
import 'auth_vm.dart';
import 'dashboard_shell.dart';
import 'login_page.dart';
import 'supabase_config.dart';
import 'app_constants.dart';
import 'widgets.dart';
import 'app_logger.dart';

/// Page where users set their new password after clicking the reset link
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double pillWidth = 120;

    // Check if user has active session (from password reset link)
    final hasSession = supabase.auth.currentUser != null;

    appLog('ResetPasswordPage: active reset session: $hasSession');

    return DashboardShell(
      welcomeText: 'New Password',
      center: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Enter your new password below.',
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    PillLabeledTextField(
                      label: 'New Password',
                      controller: _passwordController,
                      hintText: 'Enter new password',
                      obscureText: _obscurePassword,
                      blue: AppColors.primaryBlue,
                      pillWidth: pillWidth,
                      textInputAction: TextInputAction.next,
                      trailing: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).nextFocus(),
                    ),
                    const SizedBox(height: 16),
                    PillLabeledTextField(
                      label: 'Confirm',
                      controller: _confirmPasswordController,
                      hintText: 'Confirm new password',
                      obscureText: _obscureConfirm,
                      blue: AppColors.primaryBlue,
                      pillWidth: pillWidth,
                      textInputAction: TextInputAction.done,
                      trailing: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                      onFieldSubmitted: (_) {
                        if (!_isLoading) _updatePassword();
                      },
                    ),
                    const SizedBox(height: 24),
                    GradientButton(
                      onPressed: _isLoading ? null : _updatePassword,
                      gradient: AppGradients.yellowGradient,
                      width: double.infinity,
                      height: 40,
                      child: _isLoading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('Update Password'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updatePassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 8 characters')),
      );
      return;
    }

    if (password != confirm) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    setState(() => _isLoading = true);

    final authVm = AuthScope.of(context, listen: false);
    final success = await authVm.updatePassword(password);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      // Navigate back to login or home
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      final error = authVm.takeError();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Failed to update password')),
      );
    }
  }
}
