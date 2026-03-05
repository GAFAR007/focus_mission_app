/**
 * WHAT:
 * assessment_mode_screen captures assessment-specific mission setup before the
 * teacher applies it back into the mission builder sheet.
 * WHY:
 * Assessment mode has fixed constraints (10 questions, hard difficulty, 50 XP)
 * and required task focus, so a focused screen prevents accidental mismatch.
 * HOW:
 * Render fixed assessment settings, collect task focus selection, validate it,
 * and return the chosen task codes to the caller.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_palette.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/focus_mission_api.dart';
import '../../../shared/models/focus_mission_models.dart';

class AssessmentModeSelectionResult {
  const AssessmentModeSelectionResult({
    required this.taskCodes,
    required this.targetDate,
    required this.sessionType,
    this.sourceRawText = '',
    this.taskScopedSourceText = '',
    this.sourceFileName = '',
    this.sourceFileType = '',
  });

  final List<String> taskCodes;
  final DateTime targetDate;
  final String sessionType;
  final String sourceRawText;
  final String taskScopedSourceText;
  final String sourceFileName;
  final String sourceFileType;
}

class _DateSlotOption {
  const _DateSlotOption({required this.date, required this.sessionType});

  final DateTime date;
  final String sessionType;

  String get key {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day|$sessionType';
  }

  String get sessionLabel => sessionType == 'morning' ? 'Morning' : 'Afternoon';
}

class AssessmentModeScreen extends StatefulWidget {
  const AssessmentModeScreen({
    super.key,
    required this.studentName,
    required this.subjectName,
    required this.sessionType,
    required this.targetDateLabel,
    required this.taskCodeOptions,
    required this.initialTaskCodes,
    required this.timetableEntries,
    required this.initialTargetDate,
    required this.currentTeacherId,
    required this.authToken,
    required this.subjectId,
    this.lockedTaskCodes = const [],
    this.api,
  });

  final String studentName;
  final String subjectName;
  final String sessionType;
  final String targetDateLabel;
  final List<String> taskCodeOptions;
  final List<String> initialTaskCodes;
  final List<TodaySchedule> timetableEntries;
  final DateTime initialTargetDate;
  final String currentTeacherId;
  final String authToken;
  final String subjectId;
  final List<String> lockedTaskCodes;
  final FocusMissionApi? api;

  @override
  State<AssessmentModeScreen> createState() => _AssessmentModeScreenState();
}

class _AssessmentModeScreenState extends State<AssessmentModeScreen> {
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

  late List<String> _selectedTaskCodes;
  late List<_DateSlotOption> _availableDateOptions;
  _DateSlotOption? _selectedDateOption;
  late final FocusMissionApi _api;
  late final Set<String> _lockedTaskCodes;
  UploadedSourceDraft? _uploadedSource;
  String _rawUploadedSourceText = '';
  bool _showFullRawUploadText = false;
  bool _isExtractingSource = false;
  String? _errorMessage;
  String? _sourceErrorMessage;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? FocusMissionApi();
    _lockedTaskCodes = widget.lockedTaskCodes
        .map((code) => code.trim().toUpperCase())
        .where((code) => code.isNotEmpty)
        .toSet();
    _selectedTaskCodes = widget.initialTaskCodes
        .map((code) => code.trim().toUpperCase())
        .where((code) => code.isNotEmpty && !_lockedTaskCodes.contains(code))
        .toSet()
        .toList(growable: false);
    _availableDateOptions = _buildAvailableDateOptions(enforceTeacherId: true);
    if (_availableDateOptions.isEmpty) {
      _availableDateOptions = _buildAvailableDateOptions(
        enforceTeacherId: false,
      );
    }
    _selectedDateOption = _resolveInitialDateOption();

    if (_availableDateOptions.isEmpty) {
      _errorMessage =
          'No timetable dates are available for ${widget.subjectName}. Update the timetable first.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assessment Mission')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppPalette.backgroundGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Panel(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _InfoPill(label: widget.studentName),
                      _InfoPill(label: widget.subjectName),
                      _InfoPill(
                        label:
                            (_selectedDateOption?.sessionType ??
                                    widget.sessionType)
                                .toUpperCase(),
                      ),
                      _InfoPill(
                        label: _selectedDateOption == null
                            ? widget.targetDateLabel
                            : _formatLongDate(_selectedDateOption!.date),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                _Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assessment date (timetable only)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Only dates where ${widget.subjectName} is scheduled are selectable. Session timing auto-sets from timetable.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppPalette.textMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedDateOption?.key,
                        items: _availableDateOptions
                            .map(
                              (option) => DropdownMenuItem<String>(
                                value: option.key,
                                child: Text(
                                  '${_formatLongDate(option.date)} · ${option.sessionLabel}',
                                ),
                              ),
                            )
                            .toList(growable: false),
                        decoration: const InputDecoration(
                          hintText: 'Select a timetable date',
                        ),
                        onChanged: _availableDateOptions.isEmpty
                            ? null
                            : (value) {
                                final matches = _availableDateOptions
                                    .where((option) => option.key == value)
                                    .toList(growable: false);
                                if (matches.isEmpty) {
                                  return;
                                }
                                setState(() {
                                  _selectedDateOption = matches.first;
                                  _errorMessage = null;
                                });
                              },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                _Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assessment rules',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: const [
                          _InfoPill(label: '10 questions'),
                          _InfoPill(label: 'Hard only'),
                          _InfoPill(label: '50 XP fixed'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'XP is locked to 50 for assessment mode.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppPalette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                _Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Task focus (required)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: widget.taskCodeOptions
                            .map((code) {
                              final normalizedCode = code.trim().toUpperCase();
                              final isLocked = _lockedTaskCodes.contains(
                                normalizedCode,
                              );
                              return _TaskChip(
                                label: isLocked ? '$code 🔒' : code,
                                selected: _selectedTaskCodes.contains(
                                  normalizedCode,
                                ),
                                enabled: !isLocked,
                                onTap: isLocked
                                    ? null
                                    : () => _toggleTaskCode(normalizedCode),
                              );
                            })
                            .toList(growable: false),
                      ),
                      if (_lockedTaskCodes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Locked because already drafted: ${_lockedTaskCodes.join(', ')}. Select any other task code.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppPalette.textMuted),
                        ),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.red.shade700),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                _Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Source file',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Upload a document or scan. The backend extracts text so you can preview task-specific sections or full raw upload text before applying assessment mode.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppPalette.textMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isExtractingSource
                              ? null
                              : _pickAndExtractSource,
                          child: Text(
                            _isExtractingSource
                                ? 'Reading file and extracting text...'
                                : 'Upload doc or scan',
                          ),
                        ),
                      ),
                      if (_uploadedSource != null) ...[
                        const SizedBox(height: 10),
                        _InfoPill(
                          label:
                              '${_uploadedSource!.fileName} · ${_uploadedSource!.extractedCharacterCount} chars',
                        ),
                      ],
                      if (_rawUploadedSourceText.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Source preview mode',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _TaskChip(
                              label: 'Task-specific full section',
                              selected: !_showFullRawUploadText,
                              onTap: () => setState(
                                () => _showFullRawUploadText = false,
                              ),
                            ),
                            _TaskChip(
                              label: 'Show full raw upload text',
                              selected: _showFullRawUploadText,
                              onTap: () =>
                                  setState(() => _showFullRawUploadText = true),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 300),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.84),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd,
                            ),
                          ),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              _taskSourcePreviewText.trim().isEmpty
                                  ? _rawUploadedSourceText.trim()
                                  : _taskSourcePreviewText,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(height: 1.45),
                            ),
                          ),
                        ),
                      ],
                      if (_sourceErrorMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _sourceErrorMessage!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.red.shade700),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _applySelection,
                    child: const Text(
                      'Draft Teaching + 10 Questions with Groq',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleTaskCode(String code) {
    final next = [..._selectedTaskCodes];
    if (next.contains(code)) {
      next.remove(code);
    } else {
      next.add(code);
    }

    setState(() {
      _selectedTaskCodes = next;
      _errorMessage = null;
    });
  }

  void _applySelection() {
    if (_selectedTaskCodes.isEmpty) {
      setState(() {
        _errorMessage = 'Select at least one task focus to continue.';
      });
      return;
    }
    if (_selectedDateOption == null) {
      setState(() {
        _errorMessage =
            'Select a timetable date so session timing can auto-match the lesson slot.';
      });
      return;
    }

    Navigator.of(context).pop(
      AssessmentModeSelectionResult(
        taskCodes: _selectedTaskCodes,
        targetDate: _selectedDateOption!.date,
        sessionType: _selectedDateOption!.sessionType,
        sourceRawText: _rawUploadedSourceText.trim(),
        taskScopedSourceText: _extractTaskScopedTextFromSource(
          sourceText: _rawUploadedSourceText,
          taskCodes: _selectedTaskCodes,
        ).trim(),
        sourceFileName: _uploadedSource?.fileName ?? '',
        sourceFileType: _uploadedSource?.mimeType ?? '',
      ),
    );
  }

  Future<void> _pickAndExtractSource() async {
    if (_selectedDateOption == null) {
      setState(() {
        _sourceErrorMessage =
            'Select a timetable date first so extraction uses the correct lesson slot.';
      });
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: _allowedSourceExtensions,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final selected = result.files.single;
      final bytes = selected.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw Exception(
          'The selected file could not be read. Try selecting the file again.',
        );
      }

      setState(() {
        _isExtractingSource = true;
        _sourceErrorMessage = null;
      });

      final extracted = await _api.uploadTeacherSourceDraft(
        token: widget.authToken,
        subjectId: widget.subjectId,
        sessionType: _selectedDateOption!.sessionType,
        fileBytes: bytes,
        fileName: selected.name,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _uploadedSource = extracted;
        _rawUploadedSourceText = extracted.extractedText.trim();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sourceErrorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isExtractingSource = false;
        });
      }
    }
  }

  _DateSlotOption? _resolveInitialDateOption() {
    if (_availableDateOptions.isEmpty) {
      return null;
    }

    final normalizedInitialDate = _dateOnly(widget.initialTargetDate);
    final preferredSessionType = widget.sessionType.trim().toLowerCase();

    for (final option in _availableDateOptions) {
      if (_isSameDate(option.date, normalizedInitialDate) &&
          option.sessionType == preferredSessionType) {
        return option;
      }
    }

    for (final option in _availableDateOptions) {
      if (_isSameDate(option.date, normalizedInitialDate)) {
        return option;
      }
    }

    return _availableDateOptions.first;
  }

  List<_DateSlotOption> _buildAvailableDateOptions({
    required bool enforceTeacherId,
  }) {
    const searchWindowDays = 120;
    final today = _dateOnly(DateTime.now());
    final options = <_DateSlotOption>[];
    final byDayName = <String, TodaySchedule>{
      for (final entry in widget.timetableEntries) _normalize(entry.day): entry,
    };
    final normalizedSubject = _normalize(widget.subjectName);

    for (var offset = 0; offset <= searchWindowDays; offset += 1) {
      final date = today.add(Duration(days: offset));
      final dayName = _weekdayName(date.weekday);
      final schedule = byDayName[_normalize(dayName)];
      if (schedule == null) {
        continue;
      }

      final morningMatches = _slotMatches(
        subjectName: schedule.morningMission.name,
        teacherId: schedule.morningTeacher?.id,
        normalizedSubject: normalizedSubject,
        enforceTeacherId: enforceTeacherId,
      );
      final afternoonMatches = _slotMatches(
        subjectName: schedule.afternoonMission.name,
        teacherId: schedule.afternoonTeacher?.id,
        normalizedSubject: normalizedSubject,
        enforceTeacherId: enforceTeacherId,
      );

      if (morningMatches) {
        options.add(_DateSlotOption(date: date, sessionType: 'morning'));
        continue;
      }
      if (afternoonMatches) {
        options.add(_DateSlotOption(date: date, sessionType: 'afternoon'));
      }
    }

    return options;
  }

  bool _slotMatches({
    required String subjectName,
    required String? teacherId,
    required String normalizedSubject,
    required bool enforceTeacherId,
  }) {
    final subjectMatches = _normalize(subjectName) == normalizedSubject;
    if (!subjectMatches) {
      return false;
    }

    if (!enforceTeacherId) {
      return true;
    }

    if ((teacherId ?? '').isEmpty) {
      return true;
    }

    return teacherId == widget.currentTeacherId;
  }

  String _weekdayName(int weekday) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[weekday - 1];
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  String get _taskSourcePreviewText {
    final sourceText = _rawUploadedSourceText.trim();
    if (sourceText.isEmpty) {
      return '';
    }

    if (_showFullRawUploadText || _selectedTaskCodes.isEmpty) {
      return sourceText;
    }

    return _extractTaskScopedTextFromSource(
      sourceText: sourceText,
      taskCodes: _selectedTaskCodes,
    ).trim();
  }

  String _extractTaskScopedTextFromSource({
    required String sourceText,
    required List<String> taskCodes,
  }) {
    final source = sourceText.trim();
    if (source.isEmpty) {
      return '';
    }

    final chunks = _splitSourceChunks(source);
    if (chunks.isEmpty || taskCodes.isEmpty) {
      return source;
    }

    final selectedCodes = taskCodes
        .map((value) => value.trim().toUpperCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    final headingIndexes = <int>[];

    for (var index = 0; index < chunks.length; index += 1) {
      final chunk = chunks[index];
      final chunkCodes = _extractTaskCodes(chunk);
      final isHeading =
          RegExp(r'\btask\b', caseSensitive: false).hasMatch(chunk) &&
          chunkCodes.isNotEmpty;
      if (isHeading) {
        headingIndexes.add(index);
      }
    }

    int start = 0;
    int end = chunks.length;

    if (headingIndexes.isNotEmpty) {
      int? matchedHeading;
      for (final headingIndex in headingIndexes) {
        final headingCodes = _extractTaskCodes(chunks[headingIndex]);
        if (headingCodes.any(selectedCodes.contains)) {
          matchedHeading = headingIndex;
          break;
        }
      }

      if (matchedHeading != null) {
        start = matchedHeading;
        final position = headingIndexes.indexOf(matchedHeading);
        if (position >= 0 && position + 1 < headingIndexes.length) {
          end = headingIndexes[position + 1];
        }
      }
    }

    final window = chunks.sublist(start, end);
    if (window.isEmpty) {
      return source;
    }

    final scoped = <String>[];
    for (final chunk in window) {
      final chunkCodes = _extractTaskCodes(chunk);
      if (chunkCodes.isEmpty || chunkCodes.any(selectedCodes.contains)) {
        scoped.add(chunk);
      }
    }
    if (scoped.isEmpty) {
      return window.join('\n\n');
    }

    final filteredLines = scoped
        .map(
          (chunk) => chunk
              .split('\n')
              .where((line) {
                final lineCodes = _extractTaskCodes(line);
                if (lineCodes.isEmpty) {
                  return true;
                }
                return lineCodes.any(selectedCodes.contains);
              })
              .map((line) => line.trimRight())
              .where((line) => line.trim().isNotEmpty)
              .join('\n'),
        )
        .where((chunk) => chunk.trim().isNotEmpty)
        .toList(growable: false);
    if (filteredLines.isEmpty) {
      return scoped.join('\n\n');
    }
    return filteredLines.join('\n\n');
  }

  List<String> _splitSourceChunks(String sourceText) {
    final byParagraph = sourceText
        .split(RegExp(r'\n{2,}'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (byParagraph.isNotEmpty) {
      return byParagraph;
    }
    return sourceText
        .split('\n')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  Set<String> _extractTaskCodes(String text) {
    final matches = RegExp(
      r'\b([PMD]\d+)\b',
      caseSensitive: false,
    ).allMatches(text);
    final codes = <String>{};
    for (final match in matches) {
      final code = (match.group(1) ?? '').trim().toUpperCase();
      if (code.isNotEmpty) {
        codes.add(code);
      }
    }
    return codes;
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _formatLongDate(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
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
    return '${weekdays[date.weekday - 1]} ${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.section),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: child,
    );
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
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _TaskChip extends StatelessWidget {
  const _TaskChip({
    required this.label,
    required this.selected,
    this.enabled = true,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: !enabled
              ? AppPalette.sky.withValues(alpha: 0.35)
              : selected
              ? AppPalette.navy
              : Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: !enabled
                ? AppPalette.textMuted
                : selected
                ? Colors.white
                : AppPalette.navy,
          ),
        ),
      ),
    );
  }
}
