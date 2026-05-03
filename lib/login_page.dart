import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth_vm.dart';
// import 'package:url_launcher/url_launcher.dart';
import 'dashboard_shell.dart';
import 'forgot_password.dart';
import 'terms_of_use.dart';
import 'privacy_policy.dart';
import 'app_constants.dart';
import 'widgets.dart';
import 'friendly_error.dart';

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

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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

                  // Login button with gradient + rounded corners (smaller)
                  GradientButton(
                    onPressed: signingIn ? null : () => _attemptLogin(),
                    gradient: AppGradients.yellowGradient,
                    width: double.infinity,
                    height: 40,
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
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final authVm = AuthScope.of(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await authVm.signIn(_email.text.trim(), _password.text);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e, fallback: 'Sign in failed. Please check your details and try again.'))));
    }
  }

  // Future<void> _sendForgotPassword() async {
  //   final email = _email.text.trim();
  //   // Validate that the user entered an email before proceeding
  //   final emailPattern = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");
  //   if (email.isEmpty || !emailPattern.hasMatch(email)) {
  //     // Show a helpful message asking the user to enter a valid email
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Please enter a valid email address before requesting a password reset.')),
  //     );
  //     return;
  //   }
  //   // Build a mailto URI to open the user's mail client with a prefilled message.
  //   final subject = Uri.encodeComponent('Password reset request');
  //   final body = Uri.encodeComponent(
  //     'A password reset has been requested for the account with email: ${email.isEmpty ? '<unknown>' : email}.\n\nPlease process this request on behalf of the user.'
  //   );
  //   final uri = Uri.parse('mailto:schoolthrift@mylaboriecu.com?subject=$subject&body=$body');

  //   try {
  //     // Try to open the user's default mail app. On web this will open mail client or mailto handler.
  //     if (!await launchUrl(uri)) {
  //       // launchUrl returned false -> show fallback message
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('Unable to open mail app. Please email schoolthrift@mylaboriecu.com manually.')),
  //       );
  //     }
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Failed to open mail app. Please email schoolthrift@mylaboriecu.com manually.')),
  //     );
  //   }

  //   // Show a friendly confirmation dialog informing the user that the request was initiated
  //   showDialog<void>(
  //     context: context,
  //     builder: (ctx) => AlertDialog(
  //       backgroundColor: Colors.white,
  //       title: const Text('Password reset request sent'),
  //       content: Text(
  //         'A password reset request has been prepared and your mail app was opened.\n\nIf the mail app did not open, please send an email to schoolthrift@mylaboriecu.com and include your account email (${email.isEmpty ? 'your email' : email}).\n\nThe administrator will process the request.',
  //       ),
  //       actions: [
  //         TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
  //       ],
  //     ),
  //   );
  // }
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
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
      borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.2)),
    );

    return Row(
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
          child: SizedBox(
            height: 48,
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              obscureText: obscureText,
              onFieldSubmitted: onFieldSubmitted,
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
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
        ),
      ],
    );
  }
}
