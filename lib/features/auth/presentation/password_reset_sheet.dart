/**
 * WHAT:
 * password_reset_sheet guides the user through email-code password recovery.
 * WHY:
 * After repeated wrong-password attempts, the login screen needs one calm,
 * focused reset flow instead of sending the user out to a separate page.
 * HOW:
 * Request a Brevo-delivered reset code, collect the new password, and return
 * the authenticated session after the backend confirms the reset.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

import '../../../core/constants/app_palette.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/focus_mission_api.dart';
import '../../../shared/models/focus_mission_models.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/soft_panel.dart';

Future<AuthSession?> showPasswordResetSheet(
  BuildContext context, {
  required List<Color> colors,
  required String initialEmail,
  FocusMissionApi? api,
}) {
  return showModalBottomSheet<AuthSession>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PasswordResetSheet(
      colors: colors,
      initialEmail: initialEmail,
      api: api ?? FocusMissionApi(),
    ),
  );
}

class _PasswordResetSheet extends StatefulWidget {
  const _PasswordResetSheet({
    required this.colors,
    required this.initialEmail,
    required this.api,
  });

  final List<Color> colors;
  final String initialEmail;
  final FocusMissionApi api;

  @override
  State<_PasswordResetSheet> createState() => _PasswordResetSheetState();
}

class _PasswordResetSheetState extends State<_PasswordResetSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _codeController;
  late final TextEditingController _passwordController;

  bool _codeRequested = false;
  bool _isRequesting = false;
  bool _isConfirming = false;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail.trim());
    _codeController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.screen,
          AppSpacing.screen,
          AppSpacing.screen + bottomInset,
        ),
        child: SoftPanel(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Reset password',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'After 3 wrong password attempts, we can email a 6-digit reset code. The code expires after a short time.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
                ),
                const SizedBox(height: AppSpacing.section),
                if (_errorMessage != null) ...[
                  _StatusBanner(
                    message: _errorMessage!,
                    background: const Color(0xFFFFE8E8),
                    textColor: const Color(0xFFC75A5A),
                  ),
                  const SizedBox(height: AppSpacing.item),
                ],
                if (_infoMessage != null) ...[
                  _StatusBanner(
                    message: _infoMessage!,
                    background: const Color(0xFFEAF8FF),
                    textColor: AppPalette.navy,
                  ),
                  const SizedBox(height: AppSpacing.item),
                ],
                Text('Email', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'name@focusmission.app',
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) {
                      return 'Enter your email.';
                    }
                    if (!email.contains('@')) {
                      return 'Use a valid email address.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.item),
                GradientButton(
                  label: _isRequesting
                      ? 'Sending code...'
                      : _codeRequested
                      ? 'Resend reset code'
                      : 'Email reset code',
                  colors: widget.colors,
                  onPressed: _isRequesting ? () {} : _requestCode,
                ),
                if (_codeRequested) ...[
                  const SizedBox(height: AppSpacing.section),
                  Text(
                    'Reset code',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Enter the 6-digit code',
                    ),
                    validator: (value) {
                      if (!_codeRequested) {
                        return null;
                      }
                      final code = value?.trim() ?? '';
                      if (code.isEmpty) {
                        return 'Enter the reset code.';
                      }
                      if (code.length != 6) {
                        return 'Use the full 6-digit code.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.item),
                  Text(
                    'New password',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: 'Enter a new password',
                    ),
                    validator: (value) {
                      if (!_codeRequested) {
                        return null;
                      }
                      if ((value ?? '').trim().length < 8) {
                        return 'Use at least 8 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.item),
                  GradientButton(
                    label: _isConfirming
                        ? 'Resetting password...'
                        : 'Reset password and sign in',
                    colors: const [AppPalette.primaryBlue, AppPalette.aqua],
                    onPressed: _isConfirming ? () {} : _confirmReset,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _requestCode() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isRequesting = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final message = await widget.api.requestPasswordResetCode(
        email: _emailController.text.trim(),
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _codeRequested = true;
        _infoMessage = message.isEmpty
            ? 'Check your email for the reset code.'
            : message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isRequesting = false);
      }
    }
  }

  Future<void> _confirmReset() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isConfirming = true;
      _errorMessage = null;
    });

    try {
      final session = await widget.api.confirmPasswordReset(
        email: _emailController.text.trim(),
        code: _codeController.text.trim(),
        newPassword: _passwordController.text,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(session);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isConfirming = false);
      }
    }
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.message,
    required this.background,
    required this.textColor,
  });

  final String message;
  final Color background;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.item),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: textColor),
      ),
    );
  }
}
