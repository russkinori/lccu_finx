import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth_vm.dart';
import 'login_page.dart';
import 'app_constants.dart';
import 'widgets.dart';

/// Page where users enter OTP code and new password to reset their password
class VerifyOTPPasswordPage extends StatefulWidget {
  const VerifyOTPPasswordPage({super.key, required this.email});

  final String email;

  @override
  State<VerifyOTPPasswordPage> createState() => _VerifyOTPPasswordPageState();
}

class _VerifyOTPPasswordPageState extends State<VerifyOTPPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double pillWidth = 120;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Verify & Reset Password'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.security,
                        size: 48,
                        color: AppColors.primaryBlue,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'We sent a reset token to ${widget.email}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Copy the token from your email and paste it below',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      PillLabeledTextField(
                        label: 'Reset Token',
                        controller: _otpController,
                        hintText: 'Paste token from email',
                        keyboardType: TextInputType.text,
                        blue: AppColors.primaryBlue,
                        pillWidth: pillWidth,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [LengthLimitingTextInputFormatter(6)],
                        onFieldSubmitted: (_) =>
                            FocusScope.of(context).nextFocus(),
                      ),
                      const SizedBox(height: 16),
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
                          onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                        ),
                        onFieldSubmitted: (_) {
                          if (!_isLoading) _verifyAndReset();
                        },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: GradientButton(
                              onPressed: _isLoading ? null : _verifyAndReset,
                              gradient: AppGradients.yellowGradient,
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Text('Reset Password'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      Navigator.of(context).pop();
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[600],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _verifyAndReset() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final otp = _otpController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the reset token')),
      );
      return;
    }

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
    final success = await authVm.verifyOTPAndResetPassword(
      widget.email,
      otp,
      password,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset successful! Please log in.'),
          backgroundColor: Colors.green,
        ),
      );
      // Navigate back to login
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    } else {
      final error = authVm.takeError();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Invalid token or failed to reset password'),
        ),
      );
    }
  }
}
