import 'dart:async';
import 'package:flutter/material.dart';

import 'package:lccu_finx/features/auth/viewmodel/auth_vm.dart';
import 'package:lccu_finx/app/app_utils.dart';
import 'package:lccu_finx/features/legal/view/terms_of_use.dart';
import 'package:lccu_finx/features/legal/view/privacy_policy.dart';
import 'package:lccu_finx/app/app_constants.dart';
import 'package:lccu_finx/core/widgets/friendly_error.dart';

class WebLogin extends StatefulWidget {
  const WebLogin({super.key});
  @override
  State<WebLogin> createState() => _WebLoginState();
}

class _WebLoginState extends State<WebLogin> {
  static const _blue = AppColors.primaryBlue;
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 24),
              const Text(
                'Welcome!',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 24),
              _LabeledField(
                label: 'Email',
                child: TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (!isValidEmail(v)) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    hintText: 'Enter your email',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _LabeledField(
                label: 'Password',
                child: TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _attemptLogin(),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              if (_lockSecondsLeft > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Too many failed attempts. Try again in $_lockSecondsLeft seconds.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: (signingIn || _lockSecondsLeft > 0) ? null : () => _attemptLogin(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: signingIn
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Login',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
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
    );
  }

  Future<void> _attemptLogin() async {
    if (_lockSecondsLeft > 0) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final authVm = AuthScope.of(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await authVm.signIn(_email.text.trim(), _password.text);
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

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

// Factory for routing
Widget buildWebLogin() => const WebLogin();
