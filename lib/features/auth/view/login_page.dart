import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lccu_finx/features/auth/viewmodel/auth_vm.dart';
import 'package:lccu_finx/features/admin/view/dashboard_shell.dart';
import 'package:lccu_finx/features/auth/view/forgot_password.dart';
import 'package:lccu_finx/features/legal/view/terms_of_use.dart';
import 'package:lccu_finx/features/legal/view/privacy_policy.dart';
import 'package:lccu_finx/app/app_constants.dart';
import 'package:lccu_finx/app/app_utils.dart';
import 'package:lccu_finx/core/widgets/widgets.dart';
import 'package:lccu_finx/core/widgets/friendly_error.dart';

/// Mobile-first login screen that applies the branded dashboard chrome.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardShell(welcomeText: 'Welcome', center: LoginForm());
  }
}

/// Login form widget suitable for embedding inside the dashboard shell.
class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  // Brute-force protection
  int _failedAttempts = 0;
  int _lockSecondsLeft = 0;
  DateTime? _lockedUntil;
  Timer? _lockTimer;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _lockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authVm = AuthScope.of(context);
    final signingIn = authVm.phase == AuthPhase.signingIn;

    // Fixed width for the left label "pill" so all labels match length
    const double pillWidth = 100;

    return SafeArea(
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
                  const SizedBox(height: 24),

                  // Email
                  PillLabeledTextField(
                    label: 'Email',
                    controller: _email,
                    hintText: 'Enter your email',
                    keyboardType: TextInputType.emailAddress,
                    blue: AppColors.primaryBlue,
                    pillWidth: pillWidth,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (!isValidEmail(v)) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password
                  PillLabeledTextField(
                    label: 'Password',
                    controller: _password,
                    hintText: 'Enter your password',
                    obscureText: _obscure,
                    blue: AppColors.primaryBlue,
                    pillWidth: pillWidth,
                    trailing: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!signingIn) _attemptLogin();
                    },
                  ),

                  const SizedBox(height: 24),

                  // Lockout indicator
                  if (_lockSecondsLeft > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Too many failed attempts. Try again in $_lockSecondsLeft seconds.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),

                  // Login button with gradient + rounded corners (smaller)
                  GradientButton(
                    onPressed: (signingIn || _lockSecondsLeft > 0) ? null : () => _attemptLogin(),
                    gradient: AppGradients.yellowGradient,
                    width: double.infinity,
                    height: 50,
                    child: signingIn
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
                        : const Text('Login'),
                  ),

                  const SizedBox(height: 16),

                  // Forgot password link
                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ForgotPasswordPage(),
                          ),
                        );
                      },
                      child: const Text('Forgot Password?'),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Terms and Privacy Policy links
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const TermsOfUsePage(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Terms of Use',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      const Text('•', style: TextStyle(color: Colors.grey)),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const PrivacyPolicyPage(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Privacy Policy',
                          style: TextStyle(fontSize: 12),
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
    );
  }

  Future<void> _attemptLogin() async {
    if (_lockSecondsLeft > 0) return;
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final authVm = AuthScope.of(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await authVm.signIn(_email.text.trim(), _password.text);
      // Reset counter on successful sign-in.
      if (mounted) setState(() { _failedAttempts = 0; _lockSecondsLeft = 0; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _failedAttempts++;
          if (_failedAttempts >= 5) {
            _lockSecondsLeft = 30;
            _lockedUntil = DateTime.now().add(const Duration(seconds: 30));
            _lockTimer?.cancel();
            _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
              if (!mounted) { timer.cancel(); return; }
              final remaining = _lockedUntil!.difference(DateTime.now()).inSeconds;
              setState(() { _lockSecondsLeft = remaining > 0 ? remaining : 0; });
              if (_lockSecondsLeft == 0) {
                timer.cancel();
                setState(() { _failedAttempts = 0; });
              }
            });
          }
        });
      }
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e, fallback: 'Sign in failed. Please check your details and try again.'))));
    }
  }


}

/// A text field with a left "pill" label joined to the input,
/// matching the screenshot’s look.
class PillLabeledTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? trailing;
  final Color blue;
  final double? pillWidth;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputAction? textInputAction;
  final TextAlign? labelTextAlign;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const PillLabeledTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.blue,
    this.pillWidth,
    this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.trailing,
    this.onFieldSubmitted,
    this.textInputAction,
    this.labelTextAlign,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
      borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.2)),
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        // Left blue pill label — use a constrained min width so all labels match
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: pillWidth ?? 110),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: blue,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(8),
              ),
            ),
            child: Text(
              label,
              textAlign: labelTextAlign ?? TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        // Input
        Expanded(
          child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              obscureText: obscureText,
              onFieldSubmitted: onFieldSubmitted,
              validator: validator ?? (v) => (v == null || v.isEmpty) ? 'Required' : null,
              autofillHints: keyboardType == TextInputType.emailAddress
                  ? [AutofillHints.email]
                  : (obscureText ? [AutofillHints.password] : null),
              inputFormatters: inputFormatters,
              decoration: InputDecoration(
                hintText: hintText,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                border: border,
                enabledBorder: border,
                focusedBorder: border.copyWith(
                  borderSide: const BorderSide(color: Colors.black54),
                ),
                suffixIcon: trailing,
              ),
            ),
          ),
      ],
    ),
  );
  }
}
