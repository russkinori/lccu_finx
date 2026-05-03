import 'package:flutter/material.dart';
import 'auth_vm.dart';
import 'dashboard_shell.dart';
import 'login_page.dart';
import 'verify_otp_password.dart';
import 'app_constants.dart';
import 'widgets.dart';

/// Page where users can request a password reset OTP
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double pillWidth = 100;

    return DashboardShell(
      welcomeText: 'Reset Password',
      center: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _buildFormView(context, pillWidth),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView(BuildContext context, double pillWidth) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Enter your email address and we\'ll send you a verification code to reset your password.',
            style: TextStyle(fontSize: 14, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          PillLabeledTextField(
            label: 'Email',
            controller: _emailController,
            hintText: 'Enter your email',
            keyboardType: TextInputType.emailAddress,
            blue: AppColors.primaryBlue,
            pillWidth: pillWidth,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!_isLoading) _sendOTP();
            },
          ),
          const SizedBox(height: 24),
          GradientButton(
            onPressed: _isLoading ? null : _sendOTP,
            gradient: AppGradients.yellowGradient,
            width: double.infinity,
            height: 40,
            child: _isLoading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Send Code'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to Login'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendOTP() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final email = _emailController.text.trim();
    setState(() => _isLoading = true);

    final authVm = AuthScope.of(context, listen: false);
    final success = await authVm.sendPasswordResetOTP(email);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      // Navigate to OTP verification page
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => VerifyOTPPasswordPage(email: email),
        ),
      );
    } else {
      final error = authVm.takeError();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Failed to send verification code')),
      );
    }
  }
}
