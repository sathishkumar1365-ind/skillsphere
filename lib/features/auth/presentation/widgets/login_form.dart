import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/app_colors.dart';

typedef SignInCallback = Future<void> Function(
  String email,
  String password,
  bool rememberMe,
);

/// Right side of the card: logo, "WELCOME BACK", email/password fields,
/// remember me + forgot password and the Sign In button.
class LoginForm extends StatefulWidget {
  const LoginForm({
    super.key,
    this.onSignIn,
    this.onForgotPassword,
  });

  final SignInCallback? onSignIn;
  final VoidCallback? onForgotPassword;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _rememberMe = false;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- actions

  Future<void> _submit() async {
    if (_loading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      if (widget.onSignIn != null) {
        await widget.onSignIn!(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
          _rememberMe,
        );
      } else {
        // Demo behaviour until the Spring Boot API is wired in.
        await Future<void>.delayed(const Duration(milliseconds: 900));
        _toast('Signed in as ${_emailCtrl.text.trim()} (demo)');
      }
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        width: 360,
      ));
  }

  // -------------------------------------------------------------- validators

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  String? _validateEmail(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Please enter your email';
    if (!_emailRegex.hasMatch(value)) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Please enter your password';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _BrandLogo(),
            const SizedBox(height: 22),
            Text(
              'WELCOME BACK',
              textAlign: TextAlign.center,
              style: GoogleFonts.anton(
                fontSize: 30,
                letterSpacing: 0.4,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter your email and password to access your account',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 30),

            // Email
            const _FieldLabel('Email'),
            const SizedBox(height: 8),
            _InputField(
              controller: _emailCtrl,
              hint: 'Enter your email',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: _validateEmail,
              onSubmitted: (_) => _passwordFocus.requestFocus(),
            ),
            const SizedBox(height: 16),

            // Password
            const _FieldLabel('Password'),
            const SizedBox(height: 8),
            _InputField(
              controller: _passwordCtrl,
              focusNode: _passwordFocus,
              hint: 'Enter your password',
              obscureText: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              validator: _validatePassword,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 14),

            // Remember me + Forgot password
            Row(
              children: [
                SizedBox.square(
                  dimension: 16,
                  child: Checkbox(
                    value: _rememberMe,
                    onChanged: (v) => setState(() => _rememberMe = v ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    activeColor: AppColors.black,
                    side: const BorderSide(
                        color: AppColors.checkboxBorder, width: 1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => setState(() => _rememberMe = !_rememberMe),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Text(
                          'Remember me',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Align fills the Flexible's share, so the link sits at the
                // right edge (a bare loose Flexible would leave the unused
                // space after it and stop the link short of the edge).
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _TextLink(
                      'Forgot Password',
                      onTap: widget.onForgotPassword ??
                          () => _toast('Forgot password tapped'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Sign In
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.black,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.black.withAlpha(200),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: _loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Sign In',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================== sub-widgets

class _BrandLogo extends StatelessWidget {
  const _BrandLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.textPrimary, width: 1.4),
          ),
          child: const Icon(
            Icons.hub_outlined,
            size: 18,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'SKILLSPHERE',
          style: GoogleFonts.inter(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hint,
    this.focusNode,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;

  OutlineInputBorder _border([Color? color, double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: color == null
            ? BorderSide.none
            : BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      cursorColor: AppColors.black,
      cursorWidth: 1.4,
      style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 12.5, color: AppColors.hint),
        errorStyle: GoogleFonts.inter(fontSize: 11.5, color: AppColors.error),
        filled: true,
        fillColor: AppColors.fieldFill,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: _border(),
        enabledBorder: _border(),
        focusedBorder: _border(const Color(0xFF9AA3AF)),
        errorBorder: _border(AppColors.error),
        focusedErrorBorder: _border(AppColors.error, 1.2),
      ),
    );
  }
}

class _TextLink extends StatelessWidget {
  const _TextLink(this.text, {required this.onTap}) : bold = false;

  final String text;
  final VoidCallback onTap;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}