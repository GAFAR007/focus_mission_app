/**
 * WHAT:
 * CriterionReviewSheet lets the assigned teacher inspect one criterion and act
 * on teacher-owned progression steps such as reset, approve, or request
 * revision.
 * WHY:
 * The backend progression path is complete, but teachers still need a focused
 * UI to intervene when a knowledge check locks or when a submission reaches
 * review.
 * HOW:
 * Load criterion detail for the selected student, show the current progress
 * state, and call the teacher review endpoints from a modal sheet.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/constants/app_palette.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/focus_mission_api.dart';
import '../../../shared/models/focus_mission_models.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/soft_panel.dart';

Future<bool?> showCriterionReviewSheet(
  BuildContext context, {
  required AuthSession session,
  required String studentId,
  required String criterionId,
  required FocusMissionApi api,
  VoidCallback? onDraftDailyMission,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _CriterionReviewSheet(
      session: session,
      studentId: studentId,
      criterionId: criterionId,
      api: api,
      onDraftDailyMission: onDraftDailyMission,
    ),
  );
}

class _CriterionReviewSheet extends StatefulWidget {
  const _CriterionReviewSheet({
    required this.session,
    required this.studentId,
    required this.criterionId,
    required this.api,
    this.onDraftDailyMission,
  });

  final AuthSession session;
  final String studentId;
  final String criterionId;
  final FocusMissionApi api;
  final VoidCallback? onDraftDailyMission;

  @override
  State<_CriterionReviewSheet> createState() => _CriterionReviewSheetState();
}

class _CriterionReviewSheetState extends State<_CriterionReviewSheet> {
  late Future<CriterionDetailData> _future;
  final TextEditingController _unitTextController = TextEditingController();
  bool _isActing = false;
  bool _isExtractingSource = false;
  bool _isGeneratingAiDraft = false;
  CriterionAiDraft? _criterionAiDraft;
  UploadedCriterionSourceDraft? _uploadedSource;
  String? _aiDraftError;

  @override
  void initState() {
    super.initState();
    _future = _loadDetail();
  }

  @override
  void dispose() {
    _unitTextController.dispose();
    super.dispose();
  }

  Future<CriterionDetailData> _loadDetail() {
    return widget.api.fetchCriterionDetail(
      token: widget.session.token,
      studentId: widget.studentId,
      criterionId: widget.criterionId,
    );
  }

  void _refresh() {
    setState(() {
      _future = _loadDetail();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
      child: FutureBuilder<CriterionDetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SoftPanel(
              child: SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          if (snapshot.hasError) {
            return SoftPanel(
              child: SizedBox(
                height: 220,
                child: Center(child: Text(snapshot.error.toString())),
              ),
            );
          }

          final detail = snapshot.data!;

          return SoftPanel(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            detail.criterion.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.item),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _InfoPill(label: detail.studentName),
                        _InfoPill(label: detail.subject?.name ?? 'Subject'),
                        _InfoPill(label: _stateLabel(detail.progress)),
                        _InfoPill(
                          label:
                              '${detail.progress.wordCount}/${detail.criterion.requiredWordCount} words',
                        ),
                        _InfoPill(
                          label:
                              'Score ${detail.progress.latestLearningCheckScore}%',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.section),
                    SoftPanel(
                      colors: const [Color(0xFFF9FCFF), Color(0xFFE9F5FF)],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unit Draft Builder',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Upload the unit booklet or scan here. Groq drafts unit learning content and criterion blocks from this source. Daily mission drafting stays separate.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppPalette.textMuted),
                          ),
                          const SizedBox(height: AppSpacing.item),
                          GradientButton(
                            label: _isExtractingSource
                                ? 'Extracting source text...'
                                : 'Upload Unit Source (PDF/DOC/Scan)',
                            colors: AppPalette.teacherGradient,
                            onPressed: _isExtractingSource
                                ? () {}
                                : () => _uploadCriterionSource(detail),
                          ),
                          const SizedBox(height: AppSpacing.item),
                          if (_uploadedSource != null)
                            SoftPanel(
                              colors: const [
                                Color(0xFFFFFFFF),
                                Color(0xFFF2F9FF),
                              ],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _uploadedSource!.fileName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_uploadedSource!.extractedCharacterCount} chars · ${_uploadedSource!.unitPlan.suggestedQuestionCount} questions · ${_uploadedSource!.unitPlan.suggestedXpReward} XP',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: AppPalette.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _unitTextController,
                            minLines: 5,
                            maxLines: 8,
                            decoration: const InputDecoration(
                              hintText:
                                  'Unit source text appears here after upload. You can adjust it before generating the criterion draft.',
                            ),
                          ),
                          const SizedBox(height: 10),
                          GradientButton(
                            label: _isGeneratingAiDraft
                                ? 'Generating criterion draft...'
                                : 'Generate Unit Draft with Groq',
                            colors: AppPalette.teacherGradient,
                            onPressed: _isGeneratingAiDraft
                                ? () {}
                                : () => _generateCriterionAiDraft(detail),
                          ),
                          if (_aiDraftError != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              _aiDraftError!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: const Color(0xFFB93B3B)),
                            ),
                          ],
                          if (_criterionAiDraft != null) ...[
                            const SizedBox(height: AppSpacing.item),
                            SoftPanel(
                              colors: const [
                                Color(0xFFFFFEFA),
                                Color(0xFFFFF2DF),
                              ],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _criterionAiDraft!
                                            .learningContent
                                            .title
                                            .isEmpty
                                        ? 'Generated Criterion Draft'
                                        : _criterionAiDraft!
                                              .learningContent
                                              .title,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _criterionAiDraft!.learningContent.summary,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      _InfoPill(
                                        label:
                                            '${_criterionAiDraft!.learningCheckBlocks.length} learning-check blocks',
                                      ),
                                      _InfoPill(
                                        label:
                                            '${_criterionAiDraft!.essayBuilderBlocks.length} essay-builder blocks',
                                      ),
                                      if ((_criterionAiDraft!.aiModel ?? '')
                                          .isNotEmpty)
                                        _InfoPill(
                                          label: _criterionAiDraft!.aiModel!,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  GradientButton(
                                    label: _isActing
                                        ? 'Approving...'
                                        : 'Approve Unit Draft',
                                    colors: AppPalette.progressGradient,
                                    onPressed: _isActing
                                        ? () {}
                                        : _approveCriterionAiDraft,
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (widget.onDraftDailyMission != null) ...[
                            const SizedBox(height: 12),
                            GradientButton(
                              label: 'Draft Daily Mission with Groq',
                              colors: const [
                                AppPalette.primaryBlue,
                                AppPalette.aqua,
                              ],
                              onPressed: () {
                                Navigator.of(context).pop(false);
                                widget.onDraftDailyMission?.call();
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.section),
                    if (detail.learningContent != null)
                      SoftPanel(
                        colors: const [Color(0xFFF8FCFF), Color(0xFFEAF6FF)],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Learning Content',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              detail.learningContent!.summary,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: AppSpacing.item),
                    SoftPanel(
                      colors: const [Color(0xFFFFFEFB), Color(0xFFFFF3DE)],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Essay Draft',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            detail.progress.essayText.isEmpty
                                ? 'The student has not built the essay text yet.'
                                : detail.progress.essayText,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.section),
                    if (detail.progress.learningLocked) ...[
                      GradientButton(
                        label: _isActing
                            ? 'Resetting...'
                            : 'Reset Knowledge Check',
                        colors: AppPalette.teacherGradient,
                        onPressed: _isActing
                            ? () {}
                            : () => _resetLearningCheck(),
                      ),
                      const SizedBox(height: AppSpacing.compact),
                      Text(
                        'WHY: Reset reopens only this criterion, clears used attempts, and reshuffles the block order so the student cannot memorize positions.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppPalette.textMuted,
                        ),
                      ),
                    ] else if (detail.progress.submitted) ...[
                      Row(
                        children: [
                          Expanded(
                            child: GradientButton(
                              label: _isActing
                                  ? 'Saving...'
                                  : 'Request Revision',
                              colors: const [
                                AppPalette.primaryBlue,
                                AppPalette.aqua,
                              ],
                              onPressed: _isActing
                                  ? () {}
                                  : () => _reviewCriterion('request_revision'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GradientButton(
                              label: _isActing ? 'Saving...' : 'Approve',
                              colors: AppPalette.progressGradient,
                              onPressed: _isActing
                                  ? () {}
                                  : () => _reviewCriterion('approve'),
                            ),
                          ),
                        ],
                      ),
                    ] else
                      Text(
                        _teacherStatusMessage(detail.progress),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppPalette.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _resetLearningCheck() async {
    setState(() => _isActing = true);

    try {
      await widget.api.resetLearningCheck(
        token: widget.session.token,
        studentId: widget.studentId,
        criterionId: widget.criterionId,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Knowledge check reset successfully.')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      _refresh();
    } finally {
      if (mounted) {
        setState(() => _isActing = false);
      }
    }
  }

  Future<void> _uploadCriterionSource(CriterionDetailData detail) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: const [
          'pdf',
          'docx',
          'txt',
          'png',
          'jpg',
          'jpeg',
          'webp',
          'bmp',
        ],
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final pickedFile = result.files.single;
      final bytes = pickedFile.bytes;

      if (bytes == null || bytes.isEmpty) {
        throw Exception('The selected file is empty or could not be read.');
      }

      setState(() {
        _isExtractingSource = true;
        _aiDraftError = null;
      });

      final uploaded = await widget.api.uploadCriterionSourceDraft(
        token: widget.session.token,
        criterionId: detail.criterion.id,
        fileBytes: bytes,
        fileName: pickedFile.name,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _uploadedSource = uploaded;
        _unitTextController.text = uploaded.extractedText;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _aiDraftError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isExtractingSource = false);
      }
    }
  }

  Future<void> _generateCriterionAiDraft(CriterionDetailData detail) async {
    final sourceText = _unitTextController.text.trim();

    if (sourceText.length < 120) {
      setState(() {
        _aiDraftError =
            'Paste at least 120 characters of unit content before generating.';
      });
      return;
    }

    setState(() {
      _isGeneratingAiDraft = true;
      _aiDraftError = null;
    });

    try {
      final draft = await widget.api.generateCriterionLearningDraft(
        token: widget.session.token,
        criterionId: detail.criterion.id,
        unitText: sourceText,
      );

      if (!mounted) {
        return;
      }

      setState(() => _criterionAiDraft = draft);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _aiDraftError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isGeneratingAiDraft = false);
      }
    }
  }

  Future<void> _approveCriterionAiDraft() async {
    final draft = _criterionAiDraft;

    if (draft == null) {
      setState(() => _aiDraftError = 'Generate a criterion draft first.');
      return;
    }

    setState(() => _isActing = true);

    try {
      // WHY: AI output must remain draft-only until the teacher explicitly
      // approves it, so this call is the controlled publish boundary.
      final approved = await widget.api.approveCriterionLearningDraft(
        token: widget.session.token,
        draft: draft,
      );

      if (!mounted) {
        return;
      }

      setState(() => _criterionAiDraft = approved);
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unit draft approved for this criterion.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _aiDraftError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isActing = false);
      }
    }
  }

  Future<void> _reviewCriterion(String action) async {
    setState(() => _isActing = true);

    try {
      await widget.api.reviewCriterion(
        token: widget.session.token,
        studentId: widget.studentId,
        criterionId: widget.criterionId,
        action: action,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'approve'
                ? 'Criterion approved.'
                : 'Revision requested. Essay Builder is reopened for the student.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      _refresh();
    } finally {
      if (mounted) {
        setState(() => _isActing = false);
      }
    }
  }

  String _stateLabel(CriterionProgress progress) {
    switch (progress.criterionState) {
      case 'learning_required':
        return 'Learning';
      case 'learning_check_active':
        return progress.learningLocked
            ? 'Locked for review'
            : 'Knowledge check';
      case 'essay_builder_unlocked':
        return 'Essay Builder';
      case 'ready_for_submission':
        return 'Ready to submit';
      case 'submitted':
        return 'Submitted';
      case 'approved':
        return 'Approved';
      case 'revision_requested':
        return 'Revision requested';
      default:
        return 'Criterion';
    }
  }

  String _teacherStatusMessage(CriterionProgress progress) {
    switch (progress.criterionState) {
      case 'learning_required':
        return 'The student is still in the learning phase for this criterion.';
      case 'learning_check_active':
        return 'The student is working through the knowledge check.';
      case 'essay_builder_unlocked':
        return 'The student has unlocked Essay Builder and is still drafting.';
      case 'ready_for_submission':
        return 'The student has met the essay requirements but has not submitted yet.';
      case 'approved':
        return 'This criterion is fully approved.';
      case 'revision_requested':
        return 'Revision has been requested. Essay Builder is reopened for the student.';
      default:
        return 'No teacher action is required right now.';
    }
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
