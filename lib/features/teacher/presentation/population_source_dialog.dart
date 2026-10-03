/**
 * WHAT: Lets teachers choose a file or populate editable fields from pasted text.
 * WHY: Incomplete imports must retain recognised content without saving invalid
 * missions or consuming assessment slots. Existing file handling stays intact.
 * HOW: The caller supplies its existing upload service with previewOnly enabled;
 * the shared backend parser returns review fields and teacher-facing diagnostics.
 * WHO: Teacher authoring owns this temporary, unsaved import review.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../shared/models/focus_mission_models.dart';
import '../../../core/utils/focus_mission_api.dart';

const populationSourceExtensions = [
  'pdf',
  'docx',
  'txt',
  'png',
  'jpg',
  'jpeg',
  'webp',
  'bmp',
];
const maxPopulationTextCharacters = 100000;

typedef PopulationPreview =
    Future<UploadedSourceDraft> Function(PlatformFile source);

Future<PlatformFile?> showPopulationSourceDialog({
  required BuildContext context,
  required String format,
  required PopulationPreview preview,
  int? requiredQuestionCount,
}) => showDialog<PlatformFile>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _PopulationSourceDialog(
    format: format,
    preview: preview,
    requiredQuestionCount: requiredQuestionCount,
  ),
);

class _PopulationSourceDialog extends StatefulWidget {
  const _PopulationSourceDialog({
    required this.format,
    required this.preview,
    this.requiredQuestionCount,
  });
  final String format;
  final PopulationPreview preview;
  final int? requiredQuestionCount;
  @override
  State<_PopulationSourceDialog> createState() =>
      _PopulationSourceDialogState();
}

class _PopulationSourceDialogState extends State<_PopulationSourceDialog> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _fields =
      <({String label, String prefix, TextEditingController value})>[];
  bool _paste = false;
  bool _busy = false;
  bool _checked = false;
  String? _error;
  UploadedSourceDraft? _result;
  String _validatedText = '';

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    for (final field in _fields) {
      field.value.dispose();
    }
    super.dispose();
  }

  PlatformFile _textFile(String text) {
    final bytes = Uint8List.fromList(utf8.encode(text));
    return PlatformFile(
      name: 'pasted-assessment.txt',
      size: bytes.length,
      bytes: bytes,
    );
  }

  Future<void> _pickFile() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: populationSourceExtensions,
      );
      if (!mounted) return;
      if (result != null && result.files.isNotEmpty) {
        Navigator.of(context).pop(result.files.single);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'The file picker could not open. Try again or choose Paste Text.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _reviewText() {
    // WHY: Use the parser's existing export headings; never invent options,
    // answers, marking criteria or learning text. Empty optional fields are omitted.
    final parts = <String>[];
    for (final field in _fields) {
      final value = field.value.text.trim();
      if (value.isEmpty &&
          !field.prefix.contains('Question ') &&
          !field.prefix.startsWith('Sentence ') &&
          !field.prefix.startsWith('Blank ') &&
          !field.prefix.startsWith('Options:')) {
        continue;
      }
      parts.add('${field.prefix}${field.prefix.isEmpty ? '' : ' '}$value');
    }
    return parts.join('\n');
  }

  Future<void> _populate({bool fromFields = false}) async {
    if (_busy) return;
    final source = fromFields ? _reviewText() : _text.text.trim();
    if (source.trim().isEmpty) {
      setState(
        () => _error =
            'Paste some assessment content before choosing Populate from Text.',
      );
      return;
    }
    if (source.length > maxPopulationTextCharacters) {
      setState(
        () => _error =
            'Paste one assessment at a time (up to 100,000 characters).',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _checked = false;
    });
    try {
      final result = await widget
          .preview(_textFile(source))
          .timeout(const Duration(seconds: 45));
      if (!mounted) return;
      for (final field in _fields) {
        field.value.dispose();
      }
      _fields
        ..clear()
        ..addAll(
          result.populationFields.map(
            (field) => (
              label: (field['label'] ?? '').toString(),
              prefix: (field['prefix'] ?? '').toString(),
              value: TextEditingController(
                text: (field['value'] ?? '').toString(),
              ),
            ),
          ),
        );
      final questionCount = _fields
          .where(
            (field) => RegExp(r'^Question \d+ · Prompt$').hasMatch(field.label),
          )
          .length;
      setState(() {
        _result = result;
        _validatedText = source;
        _checked = !result.draftReadiness.needsAttention && _fields.isNotEmpty;
        if (widget.requiredQuestionCount != null &&
            questionCount != widget.requiredQuestionCount) {
          _error =
              'This assessment needs exactly ${widget.requiredQuestionCount} questions; $questionCount were found. Add the missing Question sections in the pasted text, then populate again.';
          _checked = false;
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          // Keep both the source and previously recognised fields after a failure.
          _error = error is FocusMissionApiException
              ? error.message
              : error is TimeoutException
              ? 'Checking this content took too long. Your text is still here; try again.'
              : 'Could not reach the content checker. Your text and recognised fields are still here. Check your connection and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = switch (widget.format) {
      'THEORY' => 'Theory',
      'ESSAY_BUILDER' => 'Essay Builder',
      _ => 'Objective',
    };
    return PopScope(
      canPop: !_busy,
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820, maxHeight: 820),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Populate $label',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close population',
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Upload File'),
                            selected: !_paste,
                            onSelected: _busy
                                ? null
                                : (_) => setState(() => _paste = false),
                          ),
                          ChoiceChip(
                            label: const Text('Paste Text'),
                            selected: _paste,
                            onSelected: _busy
                                ? null
                                : (_) => setState(() => _paste = true),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (!_paste) ...[
                        const Text(
                          'Import your structured PDF, DOCX, TXT or image using the existing file workflow.',
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _busy ? null : _pickFile,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Choose file'),
                        ),
                      ] else ...[
                        Text(
                          widget.format == 'ESSAY_BUILDER'
                              ? 'Paste the title, UNIT TEXT, Sentence sections, Learn First bullets, Sentence Preview and Blank options with correct answers.'
                              : 'Paste the title, UNIT TEXT and numbered Question sections with Learn First and Prompt. ${widget.format == 'THEORY' ? 'Include Expected Answer for each question.' : 'Include Options A–D and Correct Answer for each question.'}',
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('population-pasted-text'),
                          controller: _text,
                          enabled: !_busy,
                          minLines: 8,
                          maxLines: 16,
                          decoration: const InputDecoration(
                            labelText: 'Assessment content',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {
                            _checked = false;
                          }),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _busy ? null : () => _populate(),
                          child: Text(
                            _busy ? 'Populating…' : 'Populate from Text',
                          ),
                        ),
                      ],
                      if (_busy) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(),
                      ],
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      if (_paste && _result != null) ...[
                        const SizedBox(height: 20),
                        Text(
                          _result!.draftReadiness.summary,
                          key: const Key('population-summary'),
                        ),
                        ..._result!.draftReadiness.missingRequirements.map(
                          (message) => Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text('• $message'),
                          ),
                        ),
                        ..._result!.draftReadiness.warningNotes
                            .where(
                              (message) =>
                                  !message.contains('no draft was populated'),
                            )
                            .map(
                              (message) => Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(message),
                              ),
                            ),
                        const SizedBox(height: 16),
                        const Text(
                          'Recognised fields — edit missing details below, or update the pasted text to add sections.',
                        ),
                        const SizedBox(height: 12),
                        for (var index = 0; index < _fields.length; index++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: TextField(
                              key: ValueKey('population-field-$index'),
                              controller: _fields[index].value,
                              enabled: !_busy,
                              minLines: 1,
                              maxLines: 6,
                              decoration: InputDecoration(
                                labelText: _fields[index].label,
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.always,
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (_) =>
                                  setState(() => _checked = false),
                            ),
                          ),
                        if (_fields.isNotEmpty)
                          OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _populate(fromFields: true),
                            child: const Text('Check edited fields'),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_paste && _result != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: FilledButton.icon(
                    key: const Key('population-apply'),
                    onPressed: !_checked || _busy
                        ? null
                        : () {
                            // WHY: Prevent a second tap from popping the builder
                            // while the dialog's closing animation is running.
                            if (_busy) return;
                            setState(() => _busy = true);
                            Navigator.pop(context, _textFile(_validatedText));
                          },
                    icon: const Icon(Icons.check),
                    label: const Text('Apply to builder'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
