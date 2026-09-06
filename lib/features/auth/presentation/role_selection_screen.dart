/**
 * WHAT:
 * RoleSelectionScreen presents School Access before any role or account data.
 * WHY:
 * Public visitors must not see school login choices or Quick Fill identities
 * until the backend confirms their student, staff, or management group.
 * HOW:
 * Restore a session-scoped gate grant, verify new codes through the auth API,
 * then render only the roles permitted by the signed access-group token.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

import '../../../core/constants/app_palette.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/focus_mission_api.dart';
import '../../../core/utils/school_access_session_store.dart';
import '../../../shared/models/school_access_session.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/widgets/avatar_badge.dart';
import '../../../shared/widgets/focus_scaffold.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/role_card.dart';
import '../../../shared/widgets/soft_panel.dart';
import 'login_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key, this.api, this.accessStore});

  final FocusMissionApi? api;
  final SchoolAccessSessionStore? accessStore;

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _codeController = TextEditingController();
  late final FocusMissionApi _api;
  late final SchoolAccessSessionStore _accessStore;

  SchoolAccessSession? _accessSession;
  bool _isRestoring = true;
  bool _isSubmitting = false;
  bool _isCodeVisible = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? FocusMissionApi();
    _accessStore = widget.accessStore ?? SchoolAccessSessionStore();
    _restoreAccess();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _restoreAccess() async {
    final restoredSession = await _accessStore.restoreSession();
    if (!mounted) {
      return;
    }
    setState(() {
      // WHY: No role content is built until an unexpired stored grant has been
      // checked, preventing a brief anonymous flash of protected choices.
      _accessSession = restoredSession;
      _isRestoring = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FocusScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth < 600
              ? AppSpacing.item
              : AppSpacing.screen;
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              AppSpacing.screen,
              horizontalPadding,
              AppSpacing.screen,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _BrandHeader(centered: _accessSession == null),
                    const SizedBox(height: AppSpacing.section),
                    if (_isRestoring)
                      const _AccessLoadingPanel()
                    else if (_accessSession == null)
                      _buildAccessGate(context)
                    else
                      _buildAllowedRoles(context, _accessSession!),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccessGate(BuildContext context) {
    return SoftPanel(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'School Access',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'This area is for authorised Focus Mission users.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppPalette.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.section),
            TextFormField(
              key: const Key('school_access_code_field'),
              controller: _codeController,
              obscureText: !_isCodeVisible,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Access code',
                hintText: 'Enter your access code',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  key: const Key('school_access_visibility_toggle'),
                  tooltip: _isCodeVisible
                      ? 'Hide access code'
                      : 'Show access code',
                  onPressed: () => setState(() {
                    _isCodeVisible = !_isCodeVisible;
                  }),
                  icon: Icon(
                    _isCodeVisible
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                ),
              ),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Enter your access code.'
                  : null,
              onFieldSubmitted: (_) {
                if (!_isSubmitting) {
                  _submitAccessCode();
                }
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.compact),
              Text(
                _errorMessage!,
                key: const Key('school_access_error'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF9D3647),
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.section),
            IgnorePointer(
              ignoring: _isSubmitting,
              child: GradientButton(
                label: _isSubmitting ? 'Checking...' : 'Continue',
                colors: AppPalette.studentGradient,
                onPressed: _submitAccessCode,
              ),
            ),
            const SizedBox(height: AppSpacing.compact),
            Text(
              'Need access? Speak to staff.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllowedRoles(BuildContext context, SchoolAccessSession session) {
    final heading = switch (session.accessGroup) {
      SchoolAccessGroup.student =>
        '🚀 You’re in! Choose your account and start your mission.',
      SchoolAccessGroup.staff => 'Staff Access',
      SchoolAccessGroup.management => 'Management Access',
    };
    final supportingText = switch (session.accessGroup) {
      SchoolAccessGroup.student => 'Your mission space is ready.',
      SchoolAccessGroup.staff => 'Select your role to continue.',
      SchoolAccessGroup.management =>
        'Authorised management users may continue below.',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(heading, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          supportingText,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
        ),
        const SizedBox(height: AppSpacing.section),
        for (final role in session.allowedRoles) ...[
          RoleCard(role: role, onTap: () => _openRole(context, role, session)),
          if (role != session.allowedRoles.last)
            const SizedBox(height: AppSpacing.item),
        ],
        const SizedBox(height: AppSpacing.compact),
        TextButton(
          onPressed: _useDifferentCode,
          child: const Text('Use a different access code'),
        ),
      ],
    );
  }

  Future<void> _submitAccessCode() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final session = await _api.verifySchoolAccess(
        code: _codeController.text.trim(),
      );
      await _accessStore.saveSession(session);
      if (!mounted) {
        return;
      }
      setState(() {
        // WHY: Only a backend-signed group response can transition the screen
        // from the public gate to protected role choices.
        _accessSession = session;
        _codeController.clear();
      });
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

  Future<void> _useDifferentCode() async {
    await _accessStore.clearSession();
    if (!mounted) {
      return;
    }
    setState(() {
      _accessSession = null;
      _errorMessage = null;
      _isCodeVisible = false;
    });
  }

  void _openRole(
    BuildContext context,
    UserRole role,
    SchoolAccessSession session,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            LoginScreen(role: role, gateToken: session.gateToken, api: _api),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.centered});

  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AvatarBadge(
          icon: Icons.track_changes_rounded,
          colors: AppPalette.studentGradient,
          size: 68,
        ),
        const SizedBox(height: AppSpacing.compact),
        Text(
          'Focus Mission',
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: centered ? TextAlign.center : TextAlign.start,
        ),
      ],
    );
  }
}

class _AccessLoadingPanel extends StatelessWidget {
  const _AccessLoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const SoftPanel(
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
  }
}
