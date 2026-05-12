import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lccu_finx/features/auth/viewmodel/auth_vm.dart';
import 'package:lccu_finx/features/auth/view/login_page.dart';
import 'package:lccu_finx/app/app_constants.dart';
import 'package:lccu_finx/core/widgets/widgets.dart';

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
  void initState() {
    super.initState();
    // Rebuild whenever the password changes so requirement checklist updates live.
    _passwordController.addListener(() => setState(() {}));
  }

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
                      const SizedBox(height: 8),
                      _PasswordRequirements(
                        password: _passwordController.text,
                      ),
                      const SizedBox(height: 8),
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

    if (!_PasswordRequirements.isValid(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password does not meet all requirements. Please check the checklist above.',
          ),
        ),
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
      // Sign out the OTP-created session so the user starts fresh with their
      // new password. This prevents the need to restart the app.
      await AuthScope.of(context, listen: false).signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset successful! Please log in with your new password.'),
          backgroundColor: Colors.green,
        ),
      );
      // Navigate back to login, clearing the reset flow from the stack.
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

/// Discreet password requirements checklist that updates live as the user types.
class _PasswordRequirements extends StatelessWidget {
  const _PasswordRequirements({required this.password});

  final String password;

  static bool _meetsLength(String p) => p.length >= 8;
  static bool _meetsUpper(String p) => RegExp(r'[A-Z]').hasMatch(p);
  static bool _meetsLower(String p) => RegExp(r'[a-z]').hasMatch(p);
  static bool _meetsNumber(String p) => RegExp(r'[0-9]').hasMatch(p);
  static bool _meetsSpecial(String p) =>
      RegExp(r'[!@#\$%^&*()\-_=+\[\]{};:"\\|,.<>?/~`]').hasMatch(p);

  /// Returns true only when every requirement is satisfied.
  static bool isValid(String p) =>
      _meetsLength(p) &&
      _meetsUpper(p) &&
      _meetsLower(p) &&
      _meetsNumber(p) &&
      _meetsSpecial(p);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Password requirements:',
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          _req('At least 8 characters', _meetsLength(password)),
          _req('Uppercase letter (A–Z)', _meetsUpper(password)),
          _req('Lowercase letter (a–z)', _meetsLower(password)),
          _req('Number (0–9)', _meetsNumber(password)),
          _req('Special character (e.g. !@#\$)', _meetsSpecial(password)),
        ],
      ),
    );
  }

  Widget _req(String label, bool met) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 13,
            color: met ? Colors.green[700] : Colors.grey[400],
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: met ? Colors.green[700] : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }
}
