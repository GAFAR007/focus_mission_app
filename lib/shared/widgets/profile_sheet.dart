/**
 * WHAT:
 * profile_sheet shows the modal profile editor with the curated avatar set.
 * WHY:
 * Avatar selection needs one contained flow so profile edits stay simple,
 * playful, and separate from academic actions.
 * HOW:
 * Present a bottom sheet, load the selected avatar preset, and save updates
 * through the profile API boundary.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

import '../../core/constants/app_palette.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/avatar_presets.dart';
import '../../core/utils/focus_mission_api.dart';
import '../models/focus_mission_models.dart';
import 'avatar_badge.dart';
import 'gradient_button.dart';
import 'soft_panel.dart';

Future<AppUser?> showProfileSheet(
  BuildContext context, {
  required AuthSession session,
  FocusMissionApi? api,
}) {
  return showModalBottomSheet<AppUser>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _ProfileSheet(session: session, api: api ?? FocusMissionApi()),
  );
}

class _ProfileSheet extends StatefulWidget {
  const _ProfileSheet({required this.session, required this.api});

  final AuthSession session;
  final FocusMissionApi api;

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  late AvatarPreset _selectedPreset;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedPreset = _initialPreset();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.94,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: AppPalette.backgroundGradient,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -40,
                right: -20,
                child: _GlowBubble(
                  size: 160,
                  color: AppPalette.aqua.withValues(alpha: 0.16),
                ),
              ),
              Positioned(
                bottom: -60,
                left: -10,
                child: _GlowBubble(
                  size: 180,
                  color: AppPalette.sun.withValues(alpha: 0.10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.screen),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 60,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.section),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Profile',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        _SheetButton(
                          icon: Icons.close_rounded,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.section),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SoftPanel(
                              colors: const [
                                Color(0xF3F8FEFF),
                                Color(0xDCEEFFFB),
                              ],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      AvatarBadge(
                                        imageUrl: _selectedPreset.url,
                                        colors: const [
                                          AppPalette.sky,
                                          AppPalette.aqua,
                                        ],
                                        size: 86,
                                      ),
                                      const SizedBox(width: AppSpacing.item),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              widget.session.user.name,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleLarge,
                                            ),
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                _MetaPill(
                                                  label: _roleLabel(
                                                    widget.session.user.role,
                                                  ),
                                                ),
                                                if ((widget
                                                            .session
                                                            .user
                                                            .yearGroup ??
                                                        '')
                                                    .trim()
                                                    .isNotEmpty)
                                                  _MetaPill(
                                                    label: widget
                                                        .session
                                                        .user
                                                        .yearGroup!
                                                        .trim(),
                                                  ),
                                                if ((widget
                                                            .session
                                                            .user
                                                            .subjectSpecialty ??
                                                        '')
                                                    .isNotEmpty)
                                                  _MetaPill(
                                                    label: widget
                                                        .session
                                                        .user
                                                        .subjectSpecialty!,
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              widget.session.user.email ??
                                                  'No email',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    color: AppPalette.textMuted,
                                                  ),
                                            ),
                                            if (widget
                                                    .session
                                                    .user
                                                    .firstLoginAt !=
                                                null) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                'Started ${_formatJourneyStart(widget.session.user.firstLoginAt)}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color:
                                                          AppPalette.textMuted,
                                                    ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.section),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      _ProfileStat(
                                        label: 'XP',
                                        value: '${widget.session.user.xp}',
                                        colors: AppPalette.studentGradient,
                                      ),
                                      _ProfileStat(
                                        label: 'Streak',
                                        value: '${widget.session.user.streak}',
                                        colors: const [
                                          AppPalette.primaryBlue,
                                          AppPalette.aqua,
                                        ],
                                      ),
                                      _ProfileStat(
                                        label: 'Journey day',
                                        value:
                                            'Day ${_journeyDayValue(widget.session.user)}',
                                        colors: const [
                                          AppPalette.sun,
                                          AppPalette.orange,
                                        ],
                                      ),
                                      _ProfileStat(
                                        label: 'Login days',
                                        value:
                                            '${widget.session.user.loginDayCount}',
                                        colors: const [
                                          AppPalette.sky,
                                          AppPalette.primaryBlue,
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.section),
                            Text(
                              'Choose avatar',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Pick a brighter profile image for this account. Changes are saved to the live backend.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppPalette.textMuted),
                            ),
                            const SizedBox(height: AppSpacing.item),
                            if (_errorMessage != null) ...[
                              _StatusBanner(message: _errorMessage!),
                              const SizedBox(height: AppSpacing.item),
                            ],
                            _AvatarSection(
                              title: 'Boys',
                              presets: AvatarPresets.boys,
                              selectedSeed: _selectedPreset.seed,
                              onSelect: _selectPreset,
                            ),
                            const SizedBox(height: AppSpacing.section),
                            _AvatarSection(
                              title: 'Girls',
                              presets: AvatarPresets.girls,
                              selectedSeed: _selectedPreset.seed,
                              onSelect: _selectPreset,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.item),
                    GradientButton(
                      label: _isSaving ? 'Updating Profile...' : 'Save Avatar',
                      colors: AppPalette.progressGradient,
                      onPressed: _isSaving ? () {} : _saveProfile,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  AvatarPreset _initialPreset() {
    final currentSeed = widget.session.user.avatarSeed ?? '';
    final match = AvatarPresets.all.where(
      (preset) => preset.seed == currentSeed,
    );

    if (match.isNotEmpty) {
      return match.first;
    }

    return AvatarPresets.all.first;
  }

  void _selectPreset(AvatarPreset preset) {
    setState(() {
      _selectedPreset = preset;
      _errorMessage = null;
    });
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // WHY: Avatar changes are persisted immediately so the selected identity
      // stays consistent across future sessions and shared role screens.
      final user = await widget.api.updateProfileAvatar(
        token: widget.session.token,
        avatar: _selectedPreset.url,
        avatarSeed: _selectedPreset.seed,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(user);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  int _journeyDayValue(AppUser user) {
    return user.daysSinceFirstLogin > 0 ? user.daysSinceFirstLogin : 1;
  }

  String _formatJourneyStart(String? value) {
    if (value == null || value.isEmpty) {
      return 'today';
    }

    final startedAt = DateTime.tryParse(value)?.toLocal();

    if (startedAt == null) {
      return 'today';
    }

    return '${_monthLabel(startedAt.month)} ${startedAt.day}, ${startedAt.year}';
  }

  String _monthLabel(int month) {
    const labels = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    if (month < 1 || month > labels.length) {
      return 'Jan';
    }

    return labels[month - 1];
  }
}

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({
    required this.title,
    required this.presets,
    required this.selectedSeed,
    required this.onSelect,
  });

  final String title;
  final List<AvatarPreset> presets;
  final String selectedSeed;
  final ValueChanged<AvatarPreset> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 1180
                ? 5
                : constraints.maxWidth > 860
                ? 4
                : constraints.maxWidth > 560
                ? 3
                : 2;
            const spacing = 12.0;
            final itemWidth =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: presets
                  .map(
                    (preset) => SizedBox(
                      width: itemWidth,
                      child: _AvatarChoiceCard(
                        preset: preset,
                        selected: preset.seed == selectedSeed,
                        onTap: () => onSelect(preset),
                      ),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }
}

class _AvatarChoiceCard extends StatelessWidget {
  const _AvatarChoiceCard({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final AvatarPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.item),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: selected
                  ? [
                      AppPalette.aqua.withValues(alpha: 0.28),
                      AppPalette.sky.withValues(alpha: 0.20),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.88),
                      Colors.white.withValues(alpha: 0.70),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: selected
                  ? AppPalette.primaryBlue
                  : Colors.white.withValues(alpha: 0.76),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              AvatarBadge(
                imageUrl: preset.url,
                colors: const [AppPalette.sky, AppPalette.aqua],
                size: 66,
              ),
              const SizedBox(height: 10),
              Text(
                preset.label,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: AppPalette.navy),
              ),
              const SizedBox(height: 4),
              Text(
                selected ? 'Selected' : preset.group,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: selected
                      ? AppPalette.primaryBlue
                      : AppPalette.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppPalette.navy),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.label,
    required this.value,
    required this.colors,
  });

  final String label;
  final String value;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: SoftPanel(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.compact,
          vertical: AppSpacing.item,
        ),
        colors: [
          colors.first.withValues(alpha: 0.24),
          colors.last.withValues(alpha: 0.16),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.78),
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

class _GlowBubble extends StatelessWidget {
  const _GlowBubble({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

String _roleLabel(String? role) {
  switch (role) {
    case 'student':
      return 'Student';
    case 'teacher':
      return 'Teacher';
    case 'mentor':
      return 'Learning Mentor';
    case 'management':
      return 'Management';
    default:
      return 'Profile';
  }
}
