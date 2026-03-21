/**
 * WHAT:
 * standalone_paper_screen provides dedicated teacher screens for standalone
 * Test and Exam draft authoring outside the daily mission and assessment flows.
 * WHY:
 * Mixed-format standalone papers need a separate review surface with direct PDF
 * import, typed item editing, and clean teacher/student export controls.
 * HOW:
 * Load standalone paper drafts for the selected student and subject, let the
 * teacher populate from a structured upload or edit items manually, then save
 * and export the reviewed draft.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_palette.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/download_text_file.dart';
import '../../../core/utils/focus_mission_api.dart';
import '../../../shared/models/focus_mission_models.dart';
import '../../../shared/widgets/focus_scaffold.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/soft_panel.dart';
import '../models/standalone_paper_models.dart';

class StandaloneTestScreen extends StatelessWidget {
  const StandaloneTestScreen({
    super.key,
    required this.session,
    required this.student,
    required this.subject,
    required this.initialTargetDate,
    this.api,
  });

  final AuthSession session;
  final StudentSummary student;
  final SubjectSummary subject;
  final DateTime initialTargetDate;
  final FocusMissionApi? api;

  @override
  Widget build(BuildContext context) {
    return StandalonePaperScreen(
      session: session,
      student: student,
      subject: subject,
      initialTargetDate: initialTargetDate,
      paperKind: 'TEST',
      api: api,
    );
  }
}

class StandaloneExamScreen extends StatelessWidget {
  const StandaloneExamScreen({
    super.key,
    required this.session,
    required this.student,
    required this.subject,
    required this.initialTargetDate,
    this.api,
  });

  final AuthSession session;
  final StudentSummary student;
  final SubjectSummary subject;
  final DateTime initialTargetDate;
  final FocusMissionApi? api;

  @override
  Widget build(BuildContext context) {
    return StandalonePaperScreen(
      session: session,
      student: student,
      subject: subject,
      initialTargetDate: initialTargetDate,
      paperKind: 'EXAM',
      api: api,
    );
  }
}

class StandalonePaperScreen extends StatefulWidget {
  const StandalonePaperScreen({
    super.key,
    required this.session,
    required this.student,
    required this.subject,
    required this.initialTargetDate,
    required this.paperKind,
    this.api,
  });

  final AuthSession session;
  final StudentSummary student;
  final SubjectSummary subject;
  final DateTime initialTargetDate;
  final String paperKind;
  final FocusMissionApi? api;

  @override
  State<StandalonePaperScreen> createState() => _StandalonePaperScreenState();
}

class _StandalonePaperScreenState extends State<StandalonePaperScreen> {
  static const List<String> _allowedSourceExtensions = [
    'pdf',
    'docx',
    'txt',
    'png',
    'jpg',
    'jpeg',
    'webp',
    'bmp',
  ];

  late final FocusMissionApi _api;
  late final TextEditingController _titleController;
  late final TextEditingController _teacherNoteController;
  late final TextEditingController _unitTextController;
  late final TextEditingController _durationController;

  final List<_StandalonePaperItemController> _itemEditors = [];

  List<StandalonePaperDraft> _papers = const [];
  UploadedStandalonePaperDraft? _uploadedDraft;
  StandalonePaperImportReadiness? _importReadiness;
  String _rawUploadedSourceText = '';
  String _selectedSourceFileName = '';
  String _selectedSourceFileType = '';
  String _activePaperId = '';
  DateTime? _targetDate;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isImporting = false;
  String? _errorMessage;

  String get _paperKind => widget.paperKind.trim().toUpperCase();
  bool get _isExam => _paperKind == 'EXAM';
  String get _paperLabel => _isExam ? 'Exam' : 'Test';

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? FocusMissionApi();
    _titleController = TextEditingController();
    _teacherNoteController = TextEditingController();
    _unitTextController = TextEditingController();
    _durationController = TextEditingController(text: '0');
    _targetDate = _dateOnly(widget.initialTargetDate);
    _resetDraft(keepTargetDate: true);
    _loadPapers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _teacherNoteController.dispose();
    _unitTextController.dispose();
    _durationController.dispose();
    for (final editor in _itemEditors) {
      editor.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPapers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final papers = await _api.fetchStandalonePapers(
        token: widget.session.token,
        studentId: widget.student.id,
        paperKind: _paperKind,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _papers = papers;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  void _resetDraft({bool keepTargetDate = false}) {
    _titleController.text = '${widget.subject.name} $_paperLabel';
    _teacherNoteController.clear();
    _unitTextController.clear();
    _durationController.text = '0';
    _activePaperId = '';
    _uploadedDraft = null;
    _importReadiness = null;
    _rawUploadedSourceText = '';
    _selectedSourceFileName = '';
    _selectedSourceFileType = '';
    if (!keepTargetDate) {
      _targetDate = _dateOnly(widget.initialTargetDate);
    }
    for (final editor in _itemEditors) {
      editor.dispose();
    }
    _itemEditors
      ..clear()
      ..add(_StandalonePaperItemController.empty('OBJECTIVE'));
  }

  void _applyPaper(StandalonePaperDraft paper, {bool clearImportState = true}) {
    _titleController.text = paper.title;
    _teacherNoteController.text = paper.teacherNote;
    _unitTextController.text = paper.sourceUnitText;
    _durationController.text = paper.durationMinutes.toString();
    _activePaperId = paper.id;
    if (clearImportState) {
      _uploadedDraft = null;
      _importReadiness = null;
    }
    _rawUploadedSourceText = paper.sourceRawText;
    _selectedSourceFileName = paper.sourceFileName;
    _selectedSourceFileType = paper.sourceFileType;
    _targetDate = paper.targetDate.trim().isEmpty
        ? _dateOnly(widget.initialTargetDate)
        : _dateOnly(
            DateTime.tryParse(paper.targetDate) ?? widget.initialTargetDate,
          );
    for (final editor in _itemEditors) {
      editor.dispose();
    }
    _itemEditors
      ..clear()
      ..addAll(
        paper.items.isEmpty
            ? <_StandalonePaperItemController>[
                _StandalonePaperItemController.empty('OBJECTIVE'),
              ]
            : paper.items.map(_StandalonePaperItemController.fromItem),
      );
  }

  Future<void> _pickAndPopulateDraft() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        withData: true,
        allowedExtensions: _allowedSourceExtensions,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      final bytes = file.bytes;

      if (bytes == null || bytes.isEmpty) {
        throw Exception(
          'The selected file could not be read. Try another file or upload it again.',
        );
      }

      setState(() {
        _isImporting = true;
        _errorMessage = null;
        _importReadiness = null;
      });

      final uploaded = await _api.uploadStandalonePaperSourceDraft(
        token: widget.session.token,
        studentId: widget.student.id,
        subjectId: widget.subject.id,
        paperKind: _paperKind,
        fileBytes: bytes,
        fileName: file.name,
        title: _titleController.text.trim(),
        targetDate: _targetDateKey,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _uploadedDraft = uploaded;
        _importReadiness = uploaded.draftReadiness;
        _rawUploadedSourceText = uploaded.extractedText;
        _selectedSourceFileName = uploaded.fileName;
        _selectedSourceFileType = uploaded.mimeType;
        if (uploaded.prefilledPaper != null) {
          _applyPaper(uploaded.prefilledPaper!, clearImportState: false);
        } else {
          _errorMessage = uploaded.draftReadiness.summary;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _pickTargetDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? widget.initialTargetDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2032),
    );

    if (selected == null) {
      return;
    }

    setState(() => _targetDate = _dateOnly(selected));
  }

  void _addItem(String itemType) {
    setState(() {
      _itemEditors.add(_StandalonePaperItemController.empty(itemType));
    });
  }

  void _removeItem(int index) {
    if (_itemEditors.length <= 1) {
      return;
    }

    setState(() {
      final removed = _itemEditors.removeAt(index);
      removed.dispose();
    });
  }

  String get _targetDateKey {
    final resolved = _targetDate ?? widget.initialTargetDate;
    final date = _dateOnly(resolved);
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String? _validateDraft() {
    if (_titleController.text.trim().isEmpty) {
      return 'Add a title for this $_paperLabel draft.';
    }

    if (_unitTextController.text.trim().isEmpty) {
      return 'Add Unit text or populate the draft from a structured file.';
    }

    final durationMinutes = int.tryParse(_durationController.text.trim()) ?? -1;
    if (durationMinutes < 0 || durationMinutes > 600) {
      return 'Duration must be between 0 and 600 minutes.';
    }

    if (_itemEditors.isEmpty) {
      return 'Add at least one item to this $_paperLabel.';
    }

    for (var index = 0; index < _itemEditors.length; index += 1) {
      final error = _itemEditors[index].validate(index + 1);
      if (error != null) {
        return error;
      }
    }

    return null;
  }

  Future<void> _saveDraft() async {
    final validationError = _validateDraft();
    if (validationError != null) {
      setState(() => _errorMessage = validationError);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final items = _itemEditors.map((editor) => editor.toItem()).toList();
      final durationMinutes =
          int.tryParse(_durationController.text.trim()) ?? 0;
      final saved = _activePaperId.trim().isEmpty
          ? await _api.createStandalonePaper(
              token: widget.session.token,
              studentId: widget.student.id,
              subjectId: widget.subject.id,
              paperKind: _paperKind,
              title: _titleController.text.trim(),
              teacherNote: _teacherNoteController.text.trim(),
              sourceUnitText: _unitTextController.text.trim(),
              sourceRawText: _rawUploadedSourceText.trim(),
              sourceFileName: _selectedSourceFileName.trim(),
              sourceFileType: _selectedSourceFileType.trim(),
              targetDate: _targetDateKey,
              durationMinutes: durationMinutes,
              items: items,
            )
          : await _api.updateStandalonePaper(
              token: widget.session.token,
              paperId: _activePaperId,
              title: _titleController.text.trim(),
              teacherNote: _teacherNoteController.text.trim(),
              sourceUnitText: _unitTextController.text.trim(),
              sourceRawText: _rawUploadedSourceText.trim(),
              sourceFileName: _selectedSourceFileName.trim(),
              sourceFileType: _selectedSourceFileType.trim(),
              targetDate: _targetDateKey,
              durationMinutes: durationMinutes,
              items: items,
            );

      if (!mounted) {
        return;
      }

      final updatedPapers = <StandalonePaperDraft>[
        saved,
        ..._papers.where((paper) => paper.id != saved.id),
      ];

      setState(() {
        _papers = updatedPapers;
        _applyPaper(saved);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$_paperLabel draft saved.')));
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

  Future<void> _deleteDraft() async {
    if (_activePaperId.trim().isEmpty || _isDeleting) {
      return;
    }

    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });

    try {
      await _api.deleteStandalonePaper(
        token: widget.session.token,
        paperId: _activePaperId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _papers = _papers
            .where((paper) => paper.id != _activePaperId)
            .toList(growable: false);
        _resetDraft(keepTargetDate: true);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$_paperLabel draft deleted.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _downloadCopy({required bool includeAnswers}) async {
    final validationError = _validateDraft();
    if (validationError != null) {
      setState(() => _errorMessage = validationError);
      return;
    }

    final fileName = _buildFileName(includeAnswers: includeAnswers);
    final html = _buildHtmlExport(includeAnswers: includeAnswers);
    final downloaded = await downloadTextFile(
      fileName: fileName,
      mimeType: 'text/html;charset=utf-8',
      content: html,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          downloaded
              ? '${includeAnswers ? 'Teacher' : 'Student'} copy downloaded.'
              : 'Downloads are not available on this device.',
        ),
      ),
    );
  }

  String _buildFileName({required bool includeAnswers}) {
    final studentSlug = _sanitizeFileNameSegment(widget.student.name);
    final subjectSlug = _sanitizeFileNameSegment(widget.subject.name);
    final kindSlug = _sanitizeFileNameSegment(_paperLabel);
    final dateSlug = _sanitizeFileNameSegment(_targetDateKey);
    final audienceSlug = includeAnswers ? 'teacher-copy' : 'student-copy';
    return '${studentSlug}_${subjectSlug}_${kindSlug}_${dateSlug}_$audienceSlug.html';
  }

  String _buildHtmlExport({required bool includeAnswers}) {
    final audienceLabel = includeAnswers ? 'Teacher Copy' : 'Student Copy';
    final buffer = StringBuffer()
      ..writeln('<!DOCTYPE html>')
      ..writeln('<html lang="en">')
      ..writeln('<head>')
      ..writeln('<meta charset="utf-8" />')
      ..writeln(
        '<meta name="viewport" content="width=device-width, initial-scale=1" />',
      )
      ..writeln(
        '<title>${_escapeHtml(_titleController.text.trim())} · $audienceLabel</title>',
      )
      ..writeln('<style>${_buildExportStyles()}</style>')
      ..writeln('</head>')
      ..writeln('<body>')
      ..writeln('<main class="page">')
      ..writeln('<section class="hero">')
      ..writeln('<span class="copy-chip">${_escapeHtml(audienceLabel)}</span>')
      ..writeln('<h1>${_escapeHtml(_titleController.text.trim())}</h1>')
      ..writeln(
        '<p class="hero-summary">${_escapeHtml(includeAnswers ? 'Teacher-ready standalone $_paperLabel draft with answer keys.' : 'Student-ready standalone $_paperLabel copy without answers.')}</p>',
      )
      ..writeln('<div class="pill-row">')
      ..writeln(
        '<span class="soft-pill">${_escapeHtml(widget.student.name)}</span>',
      )
      ..writeln(
        '<span class="soft-pill">${_escapeHtml(widget.subject.name)}</span>',
      )
      ..writeln('<span class="soft-pill">${_escapeHtml(_paperLabel)}</span>')
      ..writeln('<span class="soft-pill">${_escapeHtml(_targetDateKey)}</span>')
      ..writeln(
        '<span class="soft-pill">${_escapeHtml('${_itemEditors.length} items')}</span>',
      )
      ..writeln('</div>')
      ..writeln('</section>');

    if (_teacherNoteController.text.trim().isNotEmpty && includeAnswers) {
      buffer
        ..writeln('<section class="section-card">')
        ..writeln('<h2>Teacher Note</h2>')
        ..writeln(_buildRichTextHtml(_teacherNoteController.text.trim()))
        ..writeln('</section>');
    }

    if (_unitTextController.text.trim().isNotEmpty) {
      buffer
        ..writeln('<section class="section-card">')
        ..writeln('<h2>Unit Text</h2>')
        ..writeln(
          '<p class="section-kicker">Reviewed unit text saved with this standalone $_paperLabel.</p>',
        )
        ..writeln(_buildRichTextHtml(_unitTextController.text.trim()))
        ..writeln('</section>');
    }

    buffer
      ..writeln('<section class="section-card">')
      ..writeln('<h2>${_escapeHtml(_paperLabel)} Items</h2>')
      ..writeln('</section>');

    for (var index = 0; index < _itemEditors.length; index += 1) {
      final item = _itemEditors[index].toItem();
      buffer
        ..writeln('<section class="section-card">')
        ..writeln('<div class="question-top">')
        ..writeln(
          '<span class="question-pill">Item ${index + 1}</span><span class="copy-pill">${_escapeHtml(item.itemType.replaceAll('_', ' '))}</span>',
        )
        ..writeln('</div>');
      if (item.learningText.trim().isNotEmpty) {
        buffer
          ..writeln('<div class="field-label">Learn First</div>')
          ..writeln(_buildRichTextHtml(item.learningText.trim()));
      }
      buffer
        ..writeln('<div class="field-label">Prompt</div>')
        ..writeln(_buildRichTextHtml(item.prompt.trim()));

      if (item.itemType == 'OBJECTIVE') {
        buffer
          ..writeln('<div class="field-label">Options</div>')
          ..writeln('<ul class="option-list">');
        for (
          var optionIndex = 0;
          optionIndex < item.options.length;
          optionIndex += 1
        ) {
          final label = String.fromCharCode(65 + optionIndex);
          final isCorrect = includeAnswers && item.correctIndex == optionIndex;
          buffer.writeln(
            '<li class="option-row ${isCorrect ? 'correct-option' : ''}"><span class="option-badge">$label</span><span>${_escapeHtml(item.options[optionIndex])}</span></li>',
          );
        }
        buffer.writeln('</ul>');
        if (includeAnswers) {
          final correctLabel = String.fromCharCode(
            65 + item.correctIndex.clamp(0, 3),
          );
          final correctAnswer = item.options[item.correctIndex.clamp(0, 3)];
          buffer
            ..writeln('<div class="answer-card">')
            ..writeln(
              '<p class="answer-inline"><strong>Correct Answer:</strong> ${_escapeHtml('$correctLabel) $correctAnswer')}</p>',
            );
          if (item.explanation.trim().isNotEmpty) {
            buffer
              ..writeln('<div class="field-label">Explanation</div>')
              ..writeln(_buildRichTextHtml(item.explanation.trim()));
          }
          buffer.writeln('</div>');
        }
      } else if (item.itemType == 'FILL_GAP') {
        if (includeAnswers) {
          buffer
            ..writeln('<div class="answer-card">')
            ..writeln(
              '<p class="answer-inline"><strong>Expected Answer:</strong> ${_escapeHtml(item.expectedAnswer.trim())}</p>',
            );
          if (item.acceptedAnswers.isNotEmpty) {
            buffer.writeln(
              '<p class="answer-inline"><strong>Accepted Answers:</strong> ${_escapeHtml(item.acceptedAnswers.join(', '))}</p>',
            );
          }
          if (item.explanation.trim().isNotEmpty) {
            buffer
              ..writeln('<div class="field-label">Explanation</div>')
              ..writeln(_buildRichTextHtml(item.explanation.trim()));
          }
          buffer.writeln('</div>');
        }
      } else {
        buffer.writeln(
          '<div class="pill-row"><span class="soft-pill">Minimum Words: ${_escapeHtml('${item.minWordCount}')}</span></div>',
        );
        if (includeAnswers) {
          buffer
            ..writeln('<div class="answer-card">')
            ..writeln('<div class="field-label">Expected Answer</div>')
            ..writeln(_buildRichTextHtml(item.expectedAnswer.trim()));
          if (item.explanation.trim().isNotEmpty) {
            buffer
              ..writeln('<div class="field-label">Teacher Guidance</div>')
              ..writeln(_buildRichTextHtml(item.explanation.trim()));
          }
          buffer.writeln('</div>');
        }
      }
      buffer.writeln('</section>');
    }

    buffer
      ..writeln('</main>')
      ..writeln('</body>')
      ..writeln('</html>');

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isLoading || _isSaving || _isDeleting || _isImporting;

    return FocusScaffold(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Standalone $_paperLabel',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.compact),
              Text(
                'Standalone $_paperLabel drafts stay outside Daily Missions and Assessment Mode. Mixed Objective, Fill Gap, and Theory items are allowed here.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
              ),
              const SizedBox(height: AppSpacing.section),
              SoftPanel(
                colors: const [Color(0xFFF7FBFF), Color(0xFFE6F3FF)],
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _InfoPill(label: widget.student.name),
                    _InfoPill(label: widget.subject.name),
                    _InfoPill(label: _paperLabel),
                    _InfoPill(label: _targetDateKey),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              _DraftListPanel(
                title: 'Saved $_paperLabel drafts',
                isLoading: _isLoading,
                papers: _papers,
                activePaperId: _activePaperId,
                emptyMessage:
                    'No standalone $_paperLabel drafts yet. Populate one from PDF or build it manually below.',
                onOpenPaper: _applyPaper,
                onCreateNew: () =>
                    setState(() => _resetDraft(keepTargetDate: true)),
              ),
              const SizedBox(height: AppSpacing.section),
              if (_errorMessage != null && _errorMessage!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.item),
                  child: SoftPanel(
                    colors: const [Color(0xFFFFF7F2), Color(0xFFFFECE1)],
                    child: Text(_errorMessage!),
                  ),
                ),
              _ActionPanel(
                paperLabel: _paperLabel,
                isSaving: _isSaving,
                isDeleting: _isDeleting,
                isImporting: _isImporting,
                hasSavedDraft: _activePaperId.trim().isNotEmpty,
                onPopulate: _pickAndPopulateDraft,
                onSave: _saveDraft,
                onDelete: _deleteDraft,
                onDownloadTeacher: () => _downloadCopy(includeAnswers: true),
                onDownloadStudent: () => _downloadCopy(includeAnswers: false),
              ),
              const SizedBox(height: AppSpacing.section),
              if (_importReadiness != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.section),
                  child: _ImportReadinessCard(
                    readiness: _importReadiness!,
                    hasPrefilledPaper: _uploadedDraft?.prefilledPaper != null,
                  ),
                ),
              SoftPanel(
                colors: const [Color(0xFFFFFCF7), Color(0xFFFFF4E4)],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_paperLabel setup',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: '$_paperLabel title',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _teacherNoteController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Teacher note',
                        hintText: 'Any invigilation or marking notes...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _MetaActionCard(
                            label: 'Target date',
                            value: _targetDateKey,
                            onTap: _pickTargetDate,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _durationController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Duration (minutes)',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _selectedSourceFileName.trim().isEmpty
                          ? 'Populate draft reads the uploaded file directly. Unit text stays teacher-reviewed here.'
                          : 'Imported from $_selectedSourceFileName${_selectedSourceFileType.trim().isEmpty ? '' : ' · $_selectedSourceFileType'}.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _unitTextController,
                      minLines: 8,
                      maxLines: 12,
                      decoration: const InputDecoration(
                        labelText: 'Unit text',
                        hintText:
                            'Paste the reading passage or teaching text for this standalone paper...',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              SoftPanel(
                colors: const [Color(0xFFF7FBFF), Color(0xFFE7F2FF)],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Paper items',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: _addItem,
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'OBJECTIVE',
                              child: Text('Add objective'),
                            ),
                            PopupMenuItem(
                              value: 'FILL_GAP',
                              child: Text('Add fill gap'),
                            ),
                            PopupMenuItem(
                              value: 'THEORY',
                              child: Text('Add theory'),
                            ),
                          ],
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_circle_outline_rounded,
                                  size: 18,
                                ),
                                SizedBox(width: 6),
                                Text('Add item'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mix objective, fill gap, and theory items in one standalone $_paperLabel.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.item),
                    ..._itemEditors.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.item),
                        child: _StandalonePaperItemCard(
                          index: entry.key,
                          editor: entry.value,
                          onChanged: () => setState(() {}),
                          onRemove: _itemEditors.length <= 1
                              ? null
                              : () => _removeItem(entry.key),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isBusy) ...[
                const SizedBox(height: AppSpacing.section),
                Center(
                  child: Text(
                    _isImporting
                        ? 'Populating $_paperLabel draft...'
                        : _isSaving
                        ? 'Saving $_paperLabel draft...'
                        : _isDeleting
                        ? 'Deleting $_paperLabel draft...'
                        : 'Loading $_paperLabel drafts...',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StandalonePaperItemController {
  _StandalonePaperItemController({
    required this.itemType,
    required this.learningTextController,
    required this.promptController,
    required this.optionControllers,
    required this.correctIndex,
    required this.expectedAnswerController,
    required this.acceptedAnswersController,
    required this.explanationController,
    required this.minWordCountController,
  });

  factory _StandalonePaperItemController.empty(String itemType) {
    return _StandalonePaperItemController(
      itemType: itemType,
      learningTextController: TextEditingController(),
      promptController: TextEditingController(),
      optionControllers: List<TextEditingController>.generate(
        4,
        (_) => TextEditingController(),
      ),
      correctIndex: 0,
      expectedAnswerController: TextEditingController(),
      acceptedAnswersController: TextEditingController(),
      explanationController: TextEditingController(),
      minWordCountController: TextEditingController(text: '0'),
    );
  }

  factory _StandalonePaperItemController.fromItem(StandalonePaperItem item) {
    return _StandalonePaperItemController(
      itemType: item.itemType,
      learningTextController: TextEditingController(text: item.learningText),
      promptController: TextEditingController(text: item.prompt),
      optionControllers: List<TextEditingController>.generate(
        4,
        (index) => TextEditingController(
          text: index < item.options.length ? item.options[index] : '',
        ),
      ),
      correctIndex: item.correctIndex.clamp(0, 3),
      expectedAnswerController: TextEditingController(
        text: item.expectedAnswer,
      ),
      acceptedAnswersController: TextEditingController(
        text: item.acceptedAnswers.join(', '),
      ),
      explanationController: TextEditingController(text: item.explanation),
      minWordCountController: TextEditingController(
        text: item.minWordCount.toString(),
      ),
    );
  }

  String itemType;
  final TextEditingController learningTextController;
  final TextEditingController promptController;
  final List<TextEditingController> optionControllers;
  int correctIndex;
  final TextEditingController expectedAnswerController;
  final TextEditingController acceptedAnswersController;
  final TextEditingController explanationController;
  final TextEditingController minWordCountController;

  StandalonePaperItem toItem() {
    final expectedAnswer = expectedAnswerController.text.trim();
    final acceptedAnswers = acceptedAnswersController.text
        .split(RegExp(r'[,;\n]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);

    return StandalonePaperItem(
      itemType: itemType,
      learningText: learningTextController.text.trim(),
      prompt: promptController.text.trim(),
      options: optionControllers
          .map((controller) => controller.text.trim())
          .toList(growable: false),
      correctIndex: itemType == 'OBJECTIVE' ? correctIndex : -1,
      expectedAnswer: itemType == 'OBJECTIVE' ? '' : expectedAnswer,
      acceptedAnswers: itemType == 'FILL_GAP'
          ? (acceptedAnswers.isNotEmpty
                ? acceptedAnswers
                : expectedAnswer.isEmpty
                ? const <String>[]
                : <String>[expectedAnswer])
          : const <String>[],
      explanation: explanationController.text.trim(),
      minWordCount: itemType == 'THEORY'
          ? int.tryParse(minWordCountController.text.trim()) ?? 0
          : 0,
    );
  }

  String? validate(int itemNumber) {
    final label = 'Item $itemNumber';

    if (promptController.text.trim().isEmpty) {
      return '$label prompt is required.';
    }

    if (itemType == 'OBJECTIVE') {
      if (optionControllers.any(
        (controller) => controller.text.trim().isEmpty,
      )) {
        return '$label objective items need four options.';
      }
      if (correctIndex < 0 || correctIndex > 3) {
        return '$label objective items need one correct answer.';
      }
      return null;
    }

    if (expectedAnswerController.text.trim().isEmpty) {
      return '$label ${itemType == 'THEORY' ? 'theory' : 'fill gap'} items need an expected answer.';
    }

    if (itemType == 'FILL_GAP' &&
        acceptedAnswersController.text.trim().isEmpty &&
        expectedAnswerController.text.trim().isEmpty) {
      return '$label fill gap items need an accepted answer.';
    }

    if (itemType == 'THEORY') {
      final minWordCount =
          int.tryParse(minWordCountController.text.trim()) ?? -1;
      if (minWordCount < 0 || minWordCount > 1000) {
        return '$label theory min word count must be between 0 and 1000.';
      }
    }

    return null;
  }

  void dispose() {
    learningTextController.dispose();
    promptController.dispose();
    for (final controller in optionControllers) {
      controller.dispose();
    }
    expectedAnswerController.dispose();
    acceptedAnswersController.dispose();
    explanationController.dispose();
    minWordCountController.dispose();
  }
}

class _StandalonePaperItemCard extends StatelessWidget {
  const _StandalonePaperItemCard({
    required this.index,
    required this.editor,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _StandalonePaperItemController editor;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.item),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _InfoPill(label: 'Item ${index + 1}'),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        initialValue: editor.itemType,
                        items: const [
                          DropdownMenuItem(
                            value: 'OBJECTIVE',
                            child: Text('Objective'),
                          ),
                          DropdownMenuItem(
                            value: 'FILL_GAP',
                            child: Text('Fill Gap'),
                          ),
                          DropdownMenuItem(
                            value: 'THEORY',
                            child: Text('Theory'),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Item type',
                        ),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          editor.itemType = value;
                          onChanged();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: editor.learningTextController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Learn First',
              hintText: 'Optional teaching cue for this item...',
            ),
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: editor.promptController,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: editor.itemType == 'FILL_GAP'
                  ? 'Prompt with blank'
                  : 'Prompt',
            ),
            onChanged: (_) => onChanged(),
          ),
          if (editor.itemType == 'OBJECTIVE') ...[
            const SizedBox(height: 12),
            ...editor.optionControllers.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextFormField(
                  controller: entry.value,
                  decoration: InputDecoration(
                    labelText: 'Option ${String.fromCharCode(65 + entry.key)}',
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
            ),
            DropdownButtonFormField<int>(
              initialValue: editor.correctIndex.clamp(0, 3),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Correct answer: A')),
                DropdownMenuItem(value: 1, child: Text('Correct answer: B')),
                DropdownMenuItem(value: 2, child: Text('Correct answer: C')),
                DropdownMenuItem(value: 3, child: Text('Correct answer: D')),
              ],
              decoration: const InputDecoration(labelText: 'Correct answer'),
              onChanged: (value) {
                editor.correctIndex = value ?? 0;
                onChanged();
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: editor.explanationController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Explanation'),
              onChanged: (_) => onChanged(),
            ),
          ] else ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: editor.expectedAnswerController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Expected answer'),
              onChanged: (_) => onChanged(),
            ),
            if (editor.itemType == 'FILL_GAP') ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: editor.acceptedAnswersController,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Accepted answers',
                  hintText: 'Comma-separated accepted answer list',
                ),
                onChanged: (_) => onChanged(),
              ),
            ],
            if (editor.itemType == 'THEORY') ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: editor.minWordCountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Minimum word count',
                ),
                onChanged: (_) => onChanged(),
              ),
            ],
            const SizedBox(height: 10),
            TextFormField(
              controller: editor.explanationController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: editor.itemType == 'THEORY'
                    ? 'Teacher guidance'
                    : 'Explanation',
              ),
              onChanged: (_) => onChanged(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.paperLabel,
    required this.isSaving,
    required this.isDeleting,
    required this.isImporting,
    required this.hasSavedDraft,
    required this.onPopulate,
    required this.onSave,
    required this.onDelete,
    required this.onDownloadTeacher,
    required this.onDownloadStudent,
  });

  final String paperLabel;
  final bool isSaving;
  final bool isDeleting;
  final bool isImporting;
  final bool hasSavedDraft;
  final VoidCallback onPopulate;
  final VoidCallback onSave;
  final VoidCallback onDelete;
  final VoidCallback onDownloadTeacher;
  final VoidCallback onDownloadStudent;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      colors: const [Color(0xFFF7FBFF), Color(0xFFE6F3FF)],
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          GradientButton(
            label: isImporting
                ? 'Populating from PDF...'
                : 'Populate draft with PDF',
            colors: AppPalette.teacherGradient,
            onPressed: isImporting ? () {} : onPopulate,
          ),
          GradientButton(
            label: isSaving ? 'Saving draft...' : 'Save $paperLabel draft',
            colors: const [Color(0xFF5BB87D), Color(0xFF3D9970)],
            onPressed: isSaving ? () {} : onSave,
          ),
          OutlinedButton.icon(
            onPressed: onDownloadTeacher,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Teacher copy'),
          ),
          OutlinedButton.icon(
            onPressed: onDownloadStudent,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Student copy'),
          ),
          if (hasSavedDraft)
            OutlinedButton.icon(
              onPressed: isDeleting ? () {} : onDelete,
              icon: Icon(
                isDeleting
                    ? Icons.hourglass_top_rounded
                    : Icons.delete_outline_rounded,
              ),
              label: Text(isDeleting ? 'Deleting...' : 'Delete draft'),
            ),
        ],
      ),
    );
  }
}

class _DraftListPanel extends StatelessWidget {
  const _DraftListPanel({
    required this.title,
    required this.isLoading,
    required this.papers,
    required this.activePaperId,
    required this.emptyMessage,
    required this.onOpenPaper,
    required this.onCreateNew,
  });

  final String title;
  final bool isLoading;
  final List<StandalonePaperDraft> papers;
  final String activePaperId;
  final String emptyMessage;
  final ValueChanged<StandalonePaperDraft> onOpenPaper;
  final VoidCallback onCreateNew;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      colors: const [Color(0xFFF7FBFF), Color(0xFFE6F3FF)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: onCreateNew,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const Text('New draft'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isLoading)
            const Text('Loading drafts...')
          else if (papers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.item),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.76),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Text(emptyMessage),
            )
          else
            ...papers.map(
              (paper) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => onOpenPaper(paper),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.item),
                    decoration: BoxDecoration(
                      color: paper.id == activePaperId
                          ? const Color(0xFFE9F4FF)
                          : Colors.white.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                        color: paper.id == activePaperId
                            ? AppPalette.primaryBlue
                            : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          paper.title,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _InfoPill(
                              label: paper.targetDate.isEmpty
                                  ? 'No date'
                                  : paper.targetDate,
                            ),
                            _InfoPill(label: '${paper.itemCount} items'),
                            _InfoPill(label: '${paper.durationMinutes} min'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImportReadinessCard extends StatelessWidget {
  const _ImportReadinessCard({
    required this.readiness,
    required this.hasPrefilledPaper,
  });

  final StandalonePaperImportReadiness readiness;
  final bool hasPrefilledPaper;

  @override
  Widget build(BuildContext context) {
    final needsAttention = readiness.needsAttention;

    return SoftPanel(
      colors: needsAttention
          ? const [Color(0xFFFFF7F2), Color(0xFFFFECE1)]
          : const [Color(0xFFF3FBFF), Color(0xFFE6F4FF)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasPrefilledPaper ? 'Draft populated from upload' : 'Import review',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            readiness.summary,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
          ),
          if (readiness.detectedSignals.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: readiness.detectedSignals
                  .map((item) => _InfoPill(label: item))
                  .toList(growable: false),
            ),
          ],
          if (readiness.missingRequirements.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Missing from the upload',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ...readiness.missingRequirements.map((item) => Text('• $item')),
          ],
          if (readiness.warningNotes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Review notes', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...readiness.warningNotes.map((item) => Text('• $item')),
          ],
        ],
      ),
    );
  }
}

class _MetaActionCard extends StatelessWidget {
  const _MetaActionCard({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.item),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _sanitizeFileNameSegment(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return normalized.isEmpty ? 'draft' : normalized;
}

String _escapeHtml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

String _buildInlineHtml(String value) {
  final escaped = _escapeHtml(value);
  return escaped.replaceAllMapped(
    RegExp(r'\*\*(.+?)\*\*'),
    (match) => '<strong>${match.group(1)}</strong>',
  );
}

String _buildRichTextHtml(String value) {
  final normalized = value
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .trim();
  if (normalized.isEmpty) {
    return '<p class="section-kicker">Not added yet.</p>';
  }

  final buffer = StringBuffer();
  final paragraphLines = <String>[];
  var inList = false;

  void flushParagraph() {
    if (paragraphLines.isEmpty) {
      return;
    }
    buffer.writeln('<p>${_buildInlineHtml(paragraphLines.join(' '))}</p>');
    paragraphLines.clear();
  }

  void closeList() {
    if (!inList) {
      return;
    }
    buffer.writeln('</ul>');
    inList = false;
  }

  for (final rawLine in normalized.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      flushParagraph();
      closeList();
      continue;
    }

    final bulletMatch = RegExp(r'^[-*]\s+(.+)$').firstMatch(line);
    if (bulletMatch != null) {
      flushParagraph();
      if (!inList) {
        buffer.writeln('<ul class="bullet-list">');
        inList = true;
      }
      buffer.writeln(
        '<li>${_buildInlineHtml(bulletMatch.group(1)!.trim())}</li>',
      );
      continue;
    }

    closeList();
    paragraphLines.add(line);
  }

  flushParagraph();
  closeList();
  return buffer.toString();
}

String _buildExportStyles() {
  return '''
    :root { color-scheme: light; }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: "Avenir Next", "Segoe UI", Arial, sans-serif;
      background: linear-gradient(180deg, #f6fbff 0%, #eef4ff 52%, #f9f4ea 100%);
      color: #263854;
    }
    .page { max-width: 980px; margin: 0 auto; padding: 32px 20px 48px; }
    .hero, .section-card {
      background: rgba(255, 252, 246, 0.94);
      border: 1px solid #e8decb;
      border-radius: 28px;
      box-shadow: 0 18px 40px rgba(83, 108, 152, 0.12);
      padding: 24px;
      margin-bottom: 18px;
    }
    .copy-chip, .question-pill, .copy-pill, .soft-pill {
      display: inline-flex;
      align-items: center;
      border-radius: 999px;
      font-weight: 700;
    }
    .copy-chip {
      padding: 8px 14px;
      background: linear-gradient(135deg, #7fddeb, #6b8cff);
      color: white;
      margin-bottom: 14px;
    }
    .hero-summary, .section-kicker, p, li, .answer-inline {
      font-size: 16px;
      line-height: 1.65;
    }
    .hero h1, .section-card h2 { margin: 0; color: #23334d; }
    .field-label {
      margin-top: 18px;
      margin-bottom: 10px;
      font-size: 13px;
      font-weight: 800;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      color: #6a7287;
    }
    .pill-row { display: flex; flex-wrap: wrap; gap: 10px; align-items: center; }
    .soft-pill { padding: 8px 12px; background: #f2eee1; color: #5b6580; }
    .question-top { display: flex; flex-wrap: wrap; gap: 10px; align-items: center; }
    .question-pill { padding: 7px 12px; background: #eaf3ff; color: #36507d; }
    .copy-pill { padding: 7px 12px; background: #fff4d5; color: #8d6418; }
    .option-list, .bullet-list { margin: 0; padding: 0; list-style: none; }
    .bullet-list li {
      position: relative;
      padding-left: 20px;
      margin-bottom: 10px;
    }
    .bullet-list li::before { content: "•"; position: absolute; left: 0; color: #5b7fd8; }
    .option-row {
      display: flex;
      gap: 12px;
      align-items: flex-start;
      padding: 12px 14px;
      margin-bottom: 10px;
      border: 1px solid #ece3d2;
      border-radius: 16px;
      background: #fffdfa;
    }
    .option-row.correct-option { background: #eef9ea; border-color: #b7ddb1; }
    .option-badge {
      min-width: 30px;
      height: 30px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      border-radius: 999px;
      background: #eaf1ff;
      color: #36507d;
      font-weight: 800;
    }
    .answer-card {
      margin-top: 16px;
      padding: 16px;
      background: #f2f7ff;
      border-left: 4px solid #7d9cff;
    }
    @media print {
      body { background: white; }
      .page { max-width: none; padding: 0; }
      .hero, .section-card, .option-row { box-shadow: none; }
    }
  ''';
}
