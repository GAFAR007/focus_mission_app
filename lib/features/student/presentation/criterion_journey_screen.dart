/**
 * WHAT:
 * CriterionJourneyScreen renders the full student progression flow for one
 * criterion: learning, learning check, essay builder, submission, and review
 * status.
 * WHY:
 * The qualification journey needs an explicit ADHD-first screen so students can
 * move through one criterion with clear gates and one primary next step at a
 * time.
 * HOW:
 * Load criterion detail plus the active block set from the backend, then render
 * the current lifecycle state with the correct action for that stage.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

import '../../../core/constants/app_palette.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/focus_mission_api.dart';
import '../../../shared/models/focus_mission_models.dart';
import '../../../shared/widgets/focus_scaffold.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/soft_panel.dart';

class CriterionJourneyScreen extends StatefulWidget {
  const CriterionJourneyScreen({
    super.key,
    required this.session,
    required this.studentId,
    required this.criterionId,
  });

  final AuthSession session;
  final String studentId;
  final String criterionId;

  @override
  State<CriterionJourneyScreen> createState() => _CriterionJourneyScreenState();
}

class _CriterionJourneyScreenState extends State<CriterionJourneyScreen> {
  final FocusMissionApi _api = FocusMissionApi();

  late Future<_CriterionJourneyViewData> _future;
  final Map<String, int> _selectedAnswers = <String, int>{};
  bool _isActing = false;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<_CriterionJourneyViewData> _loadData() async {
    final detail = await _api.fetchCriterionDetail(
      token: widget.session.token,
      studentId: widget.studentId,
      criterionId: widget.criterionId,
    );

    CriterionBlocksData? learningCheck;
    CriterionBlocksData? essayBuilder;

    if (detail.progress.learningCheckActive && !detail.progress.learningLocked) {
      learningCheck = await _api.fetchLearningCheckBlocks(
        token: widget.session.token,
        studentId: widget.studentId,
        criterionId: widget.criterionId,
      );
    }

    if (detail.progress.essayBuilderUnlocked ||
        detail.progress.readyForSubmission ||
        detail.progress.revisionRequested) {
      essayBuilder = await _api.fetchEssayBuilderBlocks(
        token: widget.session.token,
        studentId: widget.studentId,
        criterionId: widget.criterionId,
      );
    }

    return _CriterionJourneyViewData(
      detail: detail,
      learningCheck: learningCheck,
      essayBuilder: essayBuilder,
    );
  }

  void _refresh() {
    setState(() {
      _selectedAnswers.clear();
      _future = _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FocusScaffold(
      child: FutureBuilder<_CriterionJourneyViewData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _CenteredState(
              label: 'Loading qualification journey...',
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _CenteredState(
              label: snapshot.error.toString(),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            );
          }

          final data = snapshot.data!;
          final detail = data.detail;
          final subjectName = detail.subject?.name ?? 'Subject';
          final stateLabel = _stateLabel(detail.progress);
          final progressValue = _progressValue(detail.progress, detail.flags);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _HeaderButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        detail.criterion.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    _TagPill(label: stateLabel),
                  ],
                ),
                const SizedBox(height: AppSpacing.section),
                SoftPanel(
                  colors: const [Color(0xFFF6FCFF), Color(0xFFE7F5FF)],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _StatPill(label: subjectName),
                          _StatPill(label: detail.unit?.title ?? 'Unit'),
                          _StatPill(
                            label:
                                'Pass rate ${detail.criterion.learningPassRate}%',
                          ),
                          _StatPill(
                            label:
                                'Essay ${detail.progress.wordCount}/${detail.criterion.requiredWordCount} words',
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.item),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: Stack(
                          children: [
                            Container(
                              height: 12,
                              width: double.infinity,
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                            FractionallySizedBox(
                              widthFactor: progressValue,
                              child: Container(
                                height: 12,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: AppPalette.progressGradient,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.item),
                      Text(
                        detail.criterion.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppPalette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                if (detail.progress.learningRequired)
                  _buildLearningStage(detail)
                else if (detail.progress.learningLocked)
                  _buildLockedLearningCheck(detail)
                else if (detail.progress.learningCheckActive)
                  _buildLearningCheckStage(data)
                else if (detail.progress.essayBuilderUnlocked ||
                    detail.progress.readyForSubmission ||
                    detail.progress.revisionRequested)
                  _buildEssayBuilderStage(data)
                else if (detail.progress.submitted)
                  _buildSubmittedStage(detail)
                else if (detail.progress.approved)
                  _buildApprovedStage(detail)
                else
                  const SoftPanel(
                    child: Text('This criterion does not have an active stage yet.'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLearningStage(CriterionDetailData detail) {
    final learningContent = detail.learningContent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SoftPanel(
          colors: const [Color(0xFFFFFEFB), Color(0xFFFFF1D8)],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Learn First',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                learningContent?.summary ??
                    'Read the teaching notes before you unlock the knowledge check.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppPalette.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.item),
        if (learningContent == null)
          const SoftPanel(
            child: Text(
              'Learning content is not approved yet. Ask the teacher to review it first.',
            ),
          )
        else
          ...learningContent.sections.map(
            (section) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.item),
              child: SoftPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.heading,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(section.body, style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              ),
            ),
          ),
        GradientButton(
          label: _isActing ? 'Unlocking...' : 'I Finished Learning',
          colors: AppPalette.progressGradient,
          onPressed: learningContent == null || _isActing
              ? () {}
              : () => _completeLearning(detail),
        ),
      ],
    );
  }

  Widget _buildLockedLearningCheck(CriterionDetailData detail) {
    return SoftPanel(
      colors: const [Color(0xFFFFF4F4), Color(0xFFFFE8E8)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Teacher Review Required',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'You have used all 3 learning-check attempts for this criterion. A teacher will reset it for you, and you can keep working on other subjects meanwhile.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.item),
          _StatPill(
            label: 'Last score ${detail.progress.latestLearningCheckScore}%',
          ),
        ],
      ),
    );
  }

  Widget _buildLearningCheckStage(_CriterionJourneyViewData data) {
    final detail = data.detail;
    final learningCheck = data.learningCheck;

    if (learningCheck == null) {
      return const SoftPanel(
        child: Text('The knowledge-check blocks are still loading.'),
      );
    }

    final allAnswered = learningCheck.blocks.every(
      (block) => _selectedAnswers.containsKey(block.id),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SoftPanel(
          colors: const [Color(0xFFF3FFFA), Color(0xFFE7FFF2)],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Knowledge Check',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Answer all ${learningCheck.blocks.length} questions. You have ${detail.flags.attemptsRemaining} attempt${detail.flags.attemptsRemaining == 1 ? '' : 's'} left, and you need ${detail.criterion.learningPassRate}% to unlock Essay Builder.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.item),
        ...learningCheck.blocks.map(
          (block) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.item),
            child: SoftPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    block.prompt,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.item),
                  ...List.generate(
                    block.options.length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ChoiceCard(
                        label: block.options[index],
                        selected: _selectedAnswers[block.id] == index,
                        onTap: () => setState(() {
                          _selectedAnswers[block.id] = index;
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        GradientButton(
          label: _isActing ? 'Submitting...' : 'Submit Knowledge Check',
          colors: const [AppPalette.primaryBlue, AppPalette.aqua],
          onPressed: !allAnswered || _isActing
              ? () {}
              : () => _submitLearningCheck(learningCheck),
        ),
      ],
    );
  }

  Widget _buildEssayBuilderStage(_CriterionJourneyViewData data) {
    final detail = data.detail;
    final essayBuilder = data.essayBuilder;

    if (essayBuilder == null) {
      return const SoftPanel(
        child: Text('Essay Builder is still loading.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SoftPanel(
          colors: const [Color(0xFFF8FCFF), Color(0xFFE9F4FF)],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.progress.revisionRequested
                    ? 'Essay Builder Reopened'
                    : 'Essay Builder',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                detail.progress.revisionRequested
                    ? 'Your teacher asked for revision. Learning Check stays passed, and you can improve the essay here.'
                    : 'Build your paragraph step by step. Each block adds one guided sentence to reduce blank-page anxiety.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.item),
        ...essayBuilder.blocks.map(
          (block) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.item),
            child: SoftPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    block.prompt,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    block.generatedSentence,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: AppPalette.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.item),
                  GradientButton(
                    label: detail.progress.appendedBlockIds.contains(block.id)
                        ? 'Sentence Added'
                        : 'Add to Essay',
                    colors: detail.progress.appendedBlockIds.contains(block.id)
                        ? const [Color(0xFFD9E6FF), Color(0xFFBFD7FF)]
                        : AppPalette.studentGradient,
                    onPressed: detail.progress.appendedBlockIds.contains(block.id) ||
                            _isActing
                        ? () {}
                        : () => _appendEssayBlock(block.id),
                  ),
                ],
              ),
            ),
          ),
        ),
        SoftPanel(
          colors: const [Color(0xFFFFFEFB), Color(0xFFFFF4E0)],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Live Essay',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '${detail.progress.wordCount} / ${detail.criterion.requiredWordCount} words',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
              ),
              const SizedBox(height: AppSpacing.item),
              Text(
                detail.progress.essayText.isEmpty
                    ? 'Your guided essay sentences will appear here as you add them.'
                    : detail.progress.essayText,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.item),
        GradientButton(
          label: _isActing
              ? 'Submitting...'
              : detail.flags.submissionReady
                  ? 'Submit Final'
                  : 'Keep Building Your Essay',
          colors: detail.flags.submissionReady
              ? AppPalette.progressGradient
              : const [Color(0xFFDCE7F8), Color(0xFFC8D8F5)],
          onPressed: !detail.flags.submissionReady || _isActing
              ? () {}
              : () => _submitCriterion(detail),
        ),
      ],
    );
  }

  Widget _buildSubmittedStage(CriterionDetailData detail) {
    return SoftPanel(
      colors: const [Color(0xFFF8FCFF), Color(0xFFE7F2FF)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Submitted for Teacher Review',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Your writing is locked while the teacher reviews it. Great work reaching the full submission stage.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.section),
          Text(
            detail.progress.essayText,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedStage(CriterionDetailData detail) {
    return SoftPanel(
      colors: const [Color(0xFFF3FFF7), Color(0xFFE4FFF1)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Criterion Approved',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'This qualification step is complete. Your teacher approved the final response.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.section),
          Text(
            detail.progress.essayText,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Future<void> _completeLearning(CriterionDetailData detail) async {
    setState(() => _isActing = true);

    try {
      await _api.completeCriterionLearning(
        token: widget.session.token,
        studentId: widget.studentId,
        criterionId: widget.criterionId,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${detail.criterion.title} is now ready for the knowledge check.',
          ),
        ),
      );
      _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isActing = false);
      }
    }
  }

  Future<void> _submitLearningCheck(CriterionBlocksData learningCheck) async {
    setState(() => _isActing = true);

    try {
      final result = await _api.submitLearningCheckAttempt(
        token: widget.session.token,
        studentId: widget.studentId,
        criterionId: widget.criterionId,
        answers: _selectedAnswers,
      );

      if (!mounted) {
        return;
      }

      final message = result.attemptResult.passed
          ? 'Great work. Essay Builder is now unlocked.'
          : result.progress.learningLocked
              ? 'A teacher will review and reset this knowledge check for you.'
              : 'You scored ${result.attemptResult.score}%. Read the learning again and try once more.';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isActing = false);
      }
    }
  }

  Future<void> _appendEssayBlock(String blockId) async {
    setState(() => _isActing = true);

    try {
      await _api.appendEssayBuilderBlock(
        token: widget.session.token,
        studentId: widget.studentId,
        criterionId: widget.criterionId,
        blockId: blockId,
      );

      if (!mounted) {
        return;
      }

      _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isActing = false);
      }
    }
  }

  Future<void> _submitCriterion(CriterionDetailData detail) async {
    setState(() => _isActing = true);

    try {
      final result = await _api.submitCriterion(
        token: widget.session.token,
        studentId: widget.studentId,
        criterionId: widget.criterionId,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Submitted successfully. You earned ${result.xpAwardedNow} XP for ${detail.criterion.title}.',
          ),
        ),
      );
      _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
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
        return progress.learningLocked ? 'Review needed' : 'Knowledge check';
      case 'essay_builder_unlocked':
        return 'Essay Builder';
      case 'ready_for_submission':
        return 'Ready to submit';
      case 'submitted':
        return 'Teacher review';
      case 'approved':
        return 'Approved';
      case 'revision_requested':
        return 'Revision';
      default:
        return 'Criterion';
    }
  }

  double _progressValue(CriterionProgress progress, CriterionFlags flags) {
    if (progress.approved) {
      return 1;
    }

    if (progress.submitted) {
      return 0.85;
    }

    if (flags.submissionReady) {
      return 0.72;
    }

    if (flags.essayBuilderUnlocked) {
      return 0.54;
    }

    if (flags.learningCheckUnlocked) {
      return 0.34;
    }

    return 0.15;
  }
}

class _CriterionJourneyViewData {
  const _CriterionJourneyViewData({
    required this.detail,
    this.learningCheck,
    this.essayBuilder,
  });

  final CriterionDetailData detail;
  final CriterionBlocksData? learningCheck;
  final CriterionBlocksData? essayBuilder;
}

class _CenteredState extends StatelessWidget {
  const _CenteredState({required this.child, required this.label});

  final Widget child;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: SoftPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              child,
              const SizedBox(height: AppSpacing.item),
              Text(label, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, this.onTap});

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

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppPalette.navy),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Ink(
        padding: const EdgeInsets.all(AppSpacing.item),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFE5F6FF)
              : Colors.white.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: selected ? AppPalette.primaryBlue : Colors.white,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? AppPalette.primaryBlue : AppPalette.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
