/**
 * WHAT:
 * MentorSavedSessionScreen shows one saved covered-session record with a simple
 * audit summary, target stars, and a downloadable copy.
 * WHY:
 * Mentors need one calm place to review what was saved after a covered lesson
 * instead of relying on a snackbar or reopening the editor to confirm details.
 * HOW:
 * Render the saved session note, teacher/conductor audit labels, current
 * target star summaries, and export the same content as a lightweight HTML
 * file through the shared download helper.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/constants/app_palette.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/download_text_file.dart';
import '../../../shared/models/focus_mission_models.dart';
import '../../../shared/widgets/focus_scaffold.dart';
import '../../../shared/widgets/soft_panel.dart';

class MentorSavedSessionScreen extends StatefulWidget {
  const MentorSavedSessionScreen({
    super.key,
    required this.studentName,
    required this.studentYearGroup,
    required this.session,
    required this.targets,
  });

  final String studentName;
  final String studentYearGroup;
  final MentorCoveredSession session;
  final List<TargetSummary> targets;

  @override
  State<MentorSavedSessionScreen> createState() =>
      _MentorSavedSessionScreenState();
}

class _MentorSavedSessionScreenState extends State<MentorSavedSessionScreen> {
  bool _isDownloading = false;

  MentorCoveredSessionLog get _log => widget.session.sessionLog!;

  @override
  Widget build(BuildContext context) {
    final subjectName = widget.session.subject?.name.trim().isNotEmpty == true
        ? widget.session.subject!.name.trim()
        : 'Covered lesson';
    final savedAtLabel = _formatAuditDateTime(_log.updatedAt ?? _log.createdAt);
    final targets = [...widget.targets]
      ..sort(
        (left, right) =>
            left.title.toLowerCase().compareTo(right.title.toLowerCase()),
      );

    return FocusScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _HeaderIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Saved Session',
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
                  Text(
                    subjectName,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Review the saved teaching note, the current target stars, and download a clean audit copy.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppPalette.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.item),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _SummaryPill(label: widget.studentName),
                      if (widget.studentYearGroup.trim().isNotEmpty)
                        _SummaryPill(label: widget.studentYearGroup.trim()),
                      _SummaryPill(
                        label: _sessionLabel(widget.session.sessionType),
                      ),
                      _SummaryPill(label: widget.session.dateKey.trim()),
                      _SummaryPill(label: '${_log.xpAwarded} XP'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.item),
            SoftPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Session Audit',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _AuditRow(label: 'Subject', value: subjectName),
                  _AuditRow(
                    label: 'Planned teacher',
                    value:
                        widget.session.plannedTeacher?.name.trim().isNotEmpty ==
                            true
                        ? widget.session.plannedTeacher!.name.trim()
                        : 'Not set',
                  ),
                  _AuditRow(
                    label: 'Conducted by',
                    value:
                        widget.session.coverStaff?.name.trim().isNotEmpty ==
                            true
                        ? widget.session.coverStaff!.name.trim()
                        : 'Mentor',
                  ),
                  _AuditRow(
                    label: 'Saved by',
                    value: _log.authorName.trim().isNotEmpty
                        ? _log.authorName.trim()
                        : 'Mentor',
                  ),
                  _AuditRow(
                    label: 'Session date',
                    value: widget.session.dateKey.trim().isEmpty
                        ? 'Not set'
                        : widget.session.dateKey.trim(),
                  ),
                  _AuditRow(
                    label: 'Saved at',
                    value: savedAtLabel.isEmpty ? 'Not recorded' : savedAtLabel,
                  ),
                  _AuditRow(label: 'Focus score', value: '${_log.focusScore}'),
                  _AuditRow(
                    label: 'Completed questions',
                    value: '${_log.completedQuestions}',
                  ),
                  _AuditRow(
                    label: 'Behaviour',
                    value: _displayBehaviourStatus(_log.behaviourStatus),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.item),
            SoftPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Teaching Comment',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.item),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Text(
                      _log.notes.trim().isEmpty
                          ? 'No teaching note was saved.'
                          : _log.notes.trim(),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppPalette.navy,
                        height: 1.55,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.item),
            SoftPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Target Stars',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      _SummaryPill(label: '${targets.length} targets'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Each target stays on the same 0 to 3 star scale so the saved session can be read quickly.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppPalette.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.item),
                  if (targets.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.item),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                      ),
                      child: Text(
                        'No targets were available for this student at save time.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  else
                    ...targets.map(
                      (target) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TargetSummaryCard(target: target),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isDownloading ? null : _downloadSavedSession,
                icon: Icon(
                  _isDownloading
                      ? Icons.hourglass_top_rounded
                      : Icons.download_rounded,
                ),
                label: Text(
                  _isDownloading
                      ? 'Preparing download...'
                      : 'Download saved session',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadSavedSession() async {
    setState(() => _isDownloading = true);
    try {
      final downloaded = await downloadTextFile(
        fileName: _buildFileName(),
        content: _buildHtmlExport(),
        mimeType: 'text/html;charset=utf-8',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            downloaded
                ? 'Saved session downloaded.'
                : 'Download is only available in the web app.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  String _buildFileName() {
    final studentSlug = _slugify(widget.studentName, fallback: 'student');
    final subjectSlug = _slugify(
      widget.session.subject?.name ?? 'covered-session',
      fallback: 'covered-session',
    );
    final dateSlug = _slugify(widget.session.dateKey, fallback: 'date');
    final sessionSlug = _slugify(
      widget.session.sessionType,
      fallback: 'session',
    );
    return '${studentSlug}_${subjectSlug}_${dateSlug}_${sessionSlug}_saved-session.html';
  }

  String _buildHtmlExport() {
    final escape = const HtmlEscape();
    final subjectName = widget.session.subject?.name.trim().isNotEmpty == true
        ? widget.session.subject!.name.trim()
        : 'Covered lesson';
    final plannedTeacher =
        widget.session.plannedTeacher?.name.trim().isNotEmpty == true
        ? widget.session.plannedTeacher!.name.trim()
        : 'Not set';
    final conductedBy =
        widget.session.coverStaff?.name.trim().isNotEmpty == true
        ? widget.session.coverStaff!.name.trim()
        : 'Mentor';
    final savedBy = _log.authorName.trim().isNotEmpty
        ? _log.authorName.trim()
        : 'Mentor';
    final savedAtLabel = _formatAuditDateTime(_log.updatedAt ?? _log.createdAt);

    final buffer = StringBuffer()
      ..writeln('<!DOCTYPE html>')
      ..writeln('<html lang="en">')
      ..writeln('<head>')
      ..writeln('<meta charset="utf-8" />')
      ..writeln(
        '<meta name="viewport" content="width=device-width, initial-scale=1" />',
      )
      ..writeln('<title>Saved Session</title>')
      ..writeln('<style>')
      ..writeln(
        'body{font-family:Arial,sans-serif;background:#f6f9ff;color:#243457;padding:32px;}',
      )
      ..writeln(
        '.card{background:#fff;border:1px solid #d7e6ff;border-radius:24px;padding:24px;margin-bottom:18px;}',
      )
      ..writeln(
        '.pill{display:inline-block;padding:8px 12px;margin:0 8px 8px 0;border-radius:999px;background:#edf5ff;color:#32456d;font-weight:700;}',
      )
      ..writeln('.label{color:#7a86a5;font-size:14px;margin-bottom:4px;}')
      ..writeln('.value{font-size:18px;font-weight:700;margin-bottom:14px;}')
      ..writeln(
        '.target{border:1px solid #d7e6ff;border-radius:18px;padding:16px;margin-bottom:12px;}',
      )
      ..writeln('.stars{color:#f0b94d;font-size:18px;letter-spacing:2px;}')
      ..writeln('</style>')
      ..writeln('</head>')
      ..writeln('<body>')
      ..writeln('<div class="card">')
      ..writeln('<h1>${escape.convert(subjectName)}</h1>')
      ..writeln(
        '<p>Saved covered session for ${escape.convert(widget.studentName)}.</p>',
      )
      ..writeln(
        '<span class="pill">${escape.convert(widget.session.dateKey)}</span>',
      )
      ..writeln(
        '<span class="pill">${escape.convert(_sessionLabel(widget.session.sessionType))}</span>',
      )
      ..writeln(
        '<span class="pill">${escape.convert('${_log.xpAwarded} XP')}</span>',
      )
      ..writeln('</div>')
      ..writeln('<div class="card">')
      ..writeln('<h2>Session Audit</h2>')
      ..writeln(
        '<div class="label">Subject</div><div class="value">${escape.convert(subjectName)}</div>',
      )
      ..writeln(
        '<div class="label">Planned teacher</div><div class="value">${escape.convert(plannedTeacher)}</div>',
      )
      ..writeln(
        '<div class="label">Conducted by</div><div class="value">${escape.convert(conductedBy)}</div>',
      )
      ..writeln(
        '<div class="label">Saved by</div><div class="value">${escape.convert(savedBy)}</div>',
      )
      ..writeln(
        '<div class="label">Session date</div><div class="value">${escape.convert(widget.session.dateKey.trim().isEmpty ? 'Not set' : widget.session.dateKey.trim())}</div>',
      )
      ..writeln(
        '<div class="label">Saved at</div><div class="value">${escape.convert(savedAtLabel.isEmpty ? 'Not recorded' : savedAtLabel)}</div>',
      )
      ..writeln(
        '<div class="label">Focus score</div><div class="value">${escape.convert('${_log.focusScore}')}</div>',
      )
      ..writeln(
        '<div class="label">Completed questions</div><div class="value">${escape.convert('${_log.completedQuestions}')}</div>',
      )
      ..writeln(
        '<div class="label">Behaviour</div><div class="value">${escape.convert(_displayBehaviourStatus(_log.behaviourStatus))}</div>',
      )
      ..writeln('</div>')
      ..writeln('<div class="card">')
      ..writeln('<h2>Teaching Comment</h2>')
      ..writeln('<p>${escape.convert(_log.notes.trim())}</p>')
      ..writeln('</div>')
      ..writeln('<div class="card">')
      ..writeln('<h2>Target Stars</h2>');

    if (widget.targets.isEmpty) {
      buffer.writeln(
        '<p>No targets were available for this student at save time.</p>',
      );
    } else {
      final sortedTargets = [...widget.targets]
        ..sort(
          (left, right) =>
              left.title.toLowerCase().compareTo(right.title.toLowerCase()),
        );
      for (final target in sortedTargets) {
        buffer
          ..writeln('<div class="target">')
          ..writeln('<div class="value">${escape.convert(target.title)}</div>')
          ..writeln(
            '<div class="label">${escape.convert(_targetTypeLabel(target.targetType))} · ${escape.convert(target.status.replaceAll('_', ' '))}</div>',
          )
          ..writeln(
            '<div class="stars">${escape.convert(_starText(target.stars))} (${target.stars}/3)</div>',
          );
        if (target.description.trim().isNotEmpty) {
          buffer.writeln('<p>${escape.convert(target.description.trim())}</p>');
        }
        if (target.createdByName.trim().isNotEmpty) {
          buffer.writeln(
            '<p><strong>Set by:</strong> ${escape.convert(target.createdByName.trim())}${target.createdByRole.trim().isNotEmpty ? ' (${escape.convert(target.createdByRole.trim())})' : ''}</p>',
          );
        }
        buffer.writeln('</div>');
      }
    }

    buffer
      ..writeln('</div>')
      ..writeln('</body>')
      ..writeln('</html>');
    return buffer.toString();
  }

  String _displayBehaviourStatus(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return 'Steady';
    }
    return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
  }

  String _sessionLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case 'morning':
        return 'Morning session';
      case 'afternoon':
        return 'Afternoon session';
      default:
        return value.trim().isEmpty ? 'Session' : value.trim();
    }
  }

  String _targetTypeLabel(String value) {
    switch (value.trim()) {
      case 'fixed_daily_mission':
        return 'Fixed daily mission';
      case 'fixed_assessment':
        return 'Fixed assessment';
      default:
        return 'Custom target';
    }
  }

  String _starText(int stars) {
    final safeStars = stars.clamp(0, 3);
    return List<String>.generate(
      3,
      (index) => index < safeStars ? '★' : '☆',
    ).join(' ');
  }

  String _formatAuditDateTime(String? rawValue) {
    final parsed = rawValue == null
        ? null
        : DateTime.tryParse(rawValue)?.toLocal();
    if (parsed == null) {
      return '';
    }
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '${parsed.year}-$month-$day $hour:$minute';
  }

  String _slugify(String value, {required String fallback}) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return normalized.isEmpty ? fallback : normalized;
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, this.onTap});

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
        child: Icon(icon, color: AppPalette.navy, size: 20),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppPalette.sky.withValues(alpha: 0.54)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppPalette.navy,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppPalette.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppPalette.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetSummaryCard extends StatelessWidget {
  const _TargetSummaryCard({required this.target});

  final TargetSummary target;

  @override
  Widget build(BuildContext context) {
    final stars = target.stars.clamp(0, 3);
    final typeLabel = target.targetType == 'fixed_daily_mission'
        ? 'Fixed daily mission'
        : target.targetType == 'fixed_assessment'
        ? 'Fixed assessment'
        : 'Custom target';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.item),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppPalette.sky.withValues(alpha: 0.48)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  target.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              _SummaryPill(label: '${target.xpAwarded} XP'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$typeLabel · ${target.status.replaceAll('_', ' ')}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
          ),
          if (target.description.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              target.description.trim(),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppPalette.navy),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              ...List<Widget>.generate(
                3,
                (index) => Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Icon(
                    index < stars
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: 22,
                    color: AppPalette.sun,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$stars/3',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppPalette.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (target.createdByName.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              target.createdByRole.trim().isNotEmpty
                  ? 'Set by ${target.createdByName.trim()} (${target.createdByRole.trim()})'
                  : 'Set by ${target.createdByName.trim()}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
