/**
 * WHAT:
 * LoginScreen handles role-specific sign-in and routes the user into the
 * correct workspace after authentication.
 * WHY:
 * The app starts with explicit role login, so auth needs one focused screen
 * that keeps sign-in simple and low-friction.
 * HOW:
 * Validate the form, call the auth API, and route the authenticated session to
 * the correct role dashboard.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

import '../../../core/constants/app_palette.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/seed_credentials.dart';
import '../../../core/utils/focus_mission_api.dart';
import '../../../shared/models/focus_mission_models.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/widgets/avatar_badge.dart';
import '../../../shared/widgets/focus_scaffold.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/soft_panel.dart';
import '../../mentor/presentation/mentor_overview_screen.dart';
import '../../student/presentation/student_dashboard_screen.dart';
import '../../teacher/presentation/teacher_session_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.role});

  final UserRole role;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FocusMissionApi _api = FocusMissionApi();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final demoAccounts = SeedCredentials.forRole(widget.role);
    _emailController = TextEditingController(
      text: demoAccounts.isEmpty ? '' : demoAccounts.first.email,
    );
    // WHY: Password should never be auto-filled so sign-in always requires
    // explicit user entry.
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final demoAccounts = SeedCredentials.forRole(widget.role);

    return FocusScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _RoundIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    widget.role.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.section),
            SoftPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AvatarBadge(
                        icon: widget.role.icon,
                        colors: widget.role.colors,
                        size: 64,
                      ),
                      const SizedBox(width: AppSpacing.item),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sign in to your space',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.role.subtitle,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppPalette.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.section),
                  if (_errorMessage != null) ...[
                    _StatusBanner(message: _errorMessage!),
                    const SizedBox(height: AppSpacing.item),
                  ],
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Email',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.username],
                          decoration: const InputDecoration(
                            hintText: 'name@focusmission.app',
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty) {
                              return 'Enter an email address.';
                            }

                            if (!email.contains('@')) {
                              return 'Use a valid email address.';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.item),
                        Text(
                          'Password',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          decoration: const InputDecoration(
                            hintText: 'Enter your password',
                          ),
                          validator: (value) {
                            if ((value ?? '').isEmpty) {
                              return 'Enter a password.';
                            }

                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  if (widget.role == UserRole.student) ...[
                    const SizedBox(height: AppSpacing.item),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.item),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                      ),
                      child: Text(
                        'Seeded demo password: ${SeedCredentials.passwordForRole(widget.role)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppPalette.navy,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.section),
                  GradientButton(
                    label: _isSubmitting ? 'Signing In...' : 'Enter Mission',
                    colors: widget.role.colors,
                    onPressed: _isSubmitting ? () {} : _submit,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            SoftPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick fill demo accounts',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use the seeded logins while you test the live backend.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppPalette.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.item),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: demoAccounts
                        .map(
                          (account) => _DemoAccountChip(
                            account: account,
                            isSelected:
                                _emailController.text.trim() == account.email,
                            onTap: () => _applyDemoAccount(account),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _applyDemoAccount(DemoAccount account) {
    setState(() {
      _emailController.text = account.email;
      _passwordController.clear();
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // WHY: Role routing happens only after the backend confirms the session,
      // so the workspace reflects the real authenticated user instead of the
      // selected chip alone.
      final session = await _api.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => _destinationForSession(session),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _destinationForSession(AuthSession session) {
    switch (session.user.role) {
      case 'student':
        return StudentDashboardScreen(session: session);
      case 'teacher':
        return TeacherSessionScreen(session: session);
      case 'mentor':
      case 'management':
        return MentorOverviewScreen(session: session);
      default:
        throw const FocusMissionApiException('Unsupported user role.');
    }
  }
}

class _DemoAccountChip extends StatelessWidget {
  const _DemoAccountChip({
    required this.account,
    required this.isSelected,
    required this.onTap,
  });

  final DemoAccount account;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? AppPalette.primaryBlue
        : Colors.white.withValues(alpha: 0.18);
    final background = isSelected
        ? Colors.white.withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.68);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                account.name,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: AppPalette.navy),
              ),
              const SizedBox(height: 4),
              Text(
                _accountLabel(account),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _accountLabel(DemoAccount account) {
    if (account.subject == null || account.subject!.isEmpty) {
      return account.email;
    }

    final suffix = account.isPlaceholder ? ' bot' : '';
    return '${account.subject}$suffix · ${account.email}';
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.74),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(icon, color: AppPalette.navy),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.item),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE4DE),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF8A3A32)),
      ),
    );
  }
}
