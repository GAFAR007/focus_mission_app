/**
 * WHAT:
 * QuestionEvidencePanel provides one compact upload, preview, download, replace,
 * and remove surface for evidence belonging to a single mission question.
 * WHY:
 * Students and teachers need the same clear evidence contract without turning
 * the mission screen into a general attachment manager.
 * HOW:
 * Load authorized question evidence through FocusMissionApi, gate student
 * controls with the authored permission, and render semantic document blocks.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/utils/focus_mission_api.dart';
import '../models/focus_mission_models.dart';
import 'safe_link_text.dart';

class QuestionEvidencePanel extends StatefulWidget {
  const QuestionEvidencePanel({
    super.key,
    required this.api,
    required this.token,
    required this.missionId,
    required this.questionIndex,
    this.questionId = '',
    required this.asTeacher,
    required this.allowUpload,
    this.title = 'Supporting evidence',
    this.initialFiles = const [],
  });

  final FocusMissionApi api;
  final String token;
  final String missionId;
  final int questionIndex;
  final String questionId;
  final bool asTeacher;
  final bool allowUpload;
  final String title;
  final List<QuestionEvidenceFileData> initialFiles;

  @override
  State<QuestionEvidencePanel> createState() => _QuestionEvidencePanelState();
}

class _QuestionEvidencePanelState extends State<QuestionEvidencePanel> {
  static const _extensions = [
    'pdf',
    'doc',
    'docx',
    'ppt',
    'pptx',
    'xls',
    'xlsx',
  ];

  List<QuestionEvidenceFileData> _files = const [];
  bool _loading = true;
  bool _working = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _files = widget.initialFiles;
    _load();
  }

  @override
  void didUpdateWidget(covariant QuestionEvidencePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.missionId != widget.missionId ||
        oldWidget.questionIndex != widget.questionIndex ||
        oldWidget.questionId != widget.questionId) {
      _files = widget.initialFiles;
      _load();
    } else if (oldWidget.initialFiles != widget.initialFiles &&
        widget.initialFiles.isNotEmpty) {
      setState(() => _files = widget.initialFiles);
    }
  }

  Future<void> _load() async {
    if (widget.missionId.trim().isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final all = await widget.api.fetchQuestionEvidence(
        token: widget.token,
        missionId: widget.missionId,
        asTeacher: widget.asTeacher,
      );
      if (!mounted) return;
      setState(() {
        _files = all
            .where(
              (item) => widget.questionId.trim().isNotEmpty
                  ? item.questionId == widget.questionId
                  : item.questionIndex == widget.questionIndex,
            )
            .toList(growable: false);
        if (_files.isEmpty && widget.initialFiles.isNotEmpty) {
          // WHY: Moved evidence intentionally keeps the original file id in
          // the immutable ResultPackage snapshot instead of duplicating bytes.
          _files = widget.initialFiles;
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickAndUpload() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _extensions,
      allowMultiple: false,
      withData: true,
    );
    final file = picked == null || picked.files.isEmpty
        ? null
        : picked.files.single;
    if (file == null) return;
    if (file.bytes == null) {
      _showMessage('The selected file could not be read.');
      return;
    }
    if (file.size > 10 * 1024 * 1024) {
      _showMessage('Choose a file that is 10 MB or smaller.');
      return;
    }
    setState(() {
      _working = true;
      _error = '';
    });
    try {
      await widget.api.uploadQuestionEvidence(
        token: widget.token,
        missionId: widget.missionId,
        questionIndex: widget.questionIndex,
        fileBytes: file.bytes!,
        fileName: file.name,
        asTeacher: widget.asTeacher,
      );
      await _load();
      _showMessage('Evidence saved to this question.');
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _remove() async {
    setState(() => _working = true);
    try {
      await widget.api.removeQuestionEvidence(
        token: widget.token,
        missionId: widget.missionId,
        questionIndex: widget.questionIndex,
        asTeacher: widget.asTeacher,
      );
      await _load();
      _showMessage('Draft evidence removed.');
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _download(QuestionEvidenceFileData file) async {
    setState(() => _working = true);
    try {
      final bytes = await widget.api.downloadQuestionEvidence(
        token: widget.token,
        evidenceId: file.id,
        asTeacher: widget.asTeacher,
      );
      await FilePicker.platform.saveFile(
        dialogTitle: 'Save original evidence',
        fileName: file.originalFileName,
        bytes: Uint8List.fromList(bytes),
      );
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final current = _files
        .where((item) => !item.isPreviousSubmittedEvidence)
        .toList();
    final previous = _files
        .where((item) => item.isPreviousSubmittedEvidence)
        .toList();
    final canChangeDraft =
        widget.allowUpload && current.every((item) => item.status == 'draft');
    if (!widget.allowUpload && _files.isEmpty && !_loading) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F9FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD8E5F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attach_file_rounded, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (_loading || _working)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (previous.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Previous submitted evidence',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            ...previous.map(_fileCard),
          ],
          if (current.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...current.map(_fileCard),
          ],
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _error,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          if (widget.allowUpload && !_loading) ...[
            const SizedBox(height: 10),
            Text(
              'PDF, Word, PowerPoint or Excel · maximum 10 MB',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: ValueKey(
                    'question_evidence_upload_${widget.questionIndex}',
                  ),
                  onPressed: _working || !canChangeDraft
                      ? null
                      : _pickAndUpload,
                  icon: Icon(
                    current.isEmpty
                        ? Icons.upload_file_rounded
                        : Icons.swap_horiz_rounded,
                  ),
                  label: Text(current.isEmpty ? 'Upload evidence' : 'Replace'),
                ),
                if (current.any((item) => item.status == 'draft'))
                  TextButton.icon(
                    onPressed: _working ? null : _remove,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Remove'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _fileCard(QuestionEvidenceFileData file) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDCE6F3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.description_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      file.originalFileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Download original',
                    onPressed: _working ? null : () => _download(file),
                    icon: const Icon(Icons.download_rounded),
                  ),
                ],
              ),
              Text(
                '${file.detectedType.toUpperCase()} · ${_fileSize(file.fileSize)} · ${file.status == 'draft' ? 'Saved draft' : 'Submitted'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              if (file.previewAvailable)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: const Text('Open preview'),
                  children: [StructuredEvidencePreview(file: file)],
                )
              else
                Text(
                  file.extractionError.isEmpty
                      ? 'File saved. We could not generate a text preview.'
                      : file.extractionError,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _fileSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).ceil()} KB';
  }
}

class StructuredEvidencePreview extends StatelessWidget {
  const StructuredEvidencePreview({super.key, required this.file});

  final QuestionEvidenceFileData file;

  @override
  Widget build(BuildContext context) {
    final content = file.extractedContent;
    if (file.parsedType == 'sheets') {
      return Column(
        children: (content['sheets'] as List<dynamic>? ?? const [])
            .map(
              (sheet) =>
                  _sheet(context, (sheet as Map).cast<String, dynamic>()),
            )
            .toList(growable: false),
      );
    }
    if (file.parsedType == 'slides') {
      return Column(
        children: (content['slides'] as List<dynamic>? ?? const [])
            .map((slide) {
              final value = (slide as Map).cast<String, dynamic>();
              return _section(
                context,
                'Slide ${value['slideNumber']}: ${value['title'] ?? ''}',
                value['blocks'] as List<dynamic>? ?? const [],
              );
            })
            .toList(growable: false),
      );
    }
    if (file.parsedType == 'pages') {
      return Column(
        children: (content['pages'] as List<dynamic>? ?? const [])
            .map((page) {
              final value = (page as Map).cast<String, dynamic>();
              return _section(
                context,
                'Page ${value['pageNumber']}',
                value['blocks'] as List<dynamic>? ?? const [],
              );
            })
            .toList(growable: false),
      );
    }
    return _blocks(context, content['blocks'] as List<dynamic>? ?? const []);
  }

  Widget _section(BuildContext context, String title, List<dynamic> blocks) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          _blocks(context, blocks),
        ],
      ),
    );
  }

  Widget _blocks(BuildContext context, List<dynamic> blocks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks
          .map((item) {
            final block = (item as Map).cast<String, dynamic>();
            if (block['type'] == 'table') {
              return _table(block['rows'] as List<dynamic>? ?? const []);
            }
            if (block['type'] == 'list') {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: (block['items'] as List<dynamic>? ?? const [])
                    .map((value) => SafeLinkText('• $value'))
                    .toList(growable: false),
              );
            }
            final text = (block['text'] ?? '').toString();
            final embeddedLinks = (block['links'] as List<dynamic>? ?? const [])
                .whereType<Map<dynamic, dynamic>>()
                .map((link) => link.cast<String, dynamic>())
                .where(
                  (link) =>
                      (link['url'] ?? '').toString().isNotEmpty &&
                      !text.contains((link['url'] ?? '').toString()),
                )
                .toList(growable: false);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SafeLinkText(
                    text,
                    style: block['type'] == 'heading'
                        ? Theme.of(context).textTheme.titleSmall
                        : Theme.of(context).textTheme.bodyMedium,
                  ),
                  ...embeddedLinks.map(
                    (link) => SafeLinkText(
                      '${link['text'] ?? 'Link'}: ${link['url']}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _sheet(BuildContext context, Map<String, dynamic> sheet) {
    final rows = (sheet['rows'] as List<dynamic>? ?? const [])
        .map((row) {
          final cells = ((row as Map)['cells'] as List<dynamic>? ?? const [])
              .map((cell) {
                if (cell is! Map) return cell.toString();
                final text = (cell['displayedValue'] ?? cell['text'] ?? '')
                    .toString();
                final formula = (cell['formula'] ?? '').toString();
                final hyperlink = (cell['hyperlink'] ?? '').toString();
                if (hyperlink.isNotEmpty) return '$text ($hyperlink)';
                if (formula.isNotEmpty) return '$text (=$formula)';
                return text;
              })
              .toList(growable: false);
          return cells;
        })
        .toList(growable: false);
    return _section(context, 'Sheet: ${sheet['name'] ?? ''}', [
      {'type': 'table', 'rows': rows},
    ]);
  }

  Widget _table(List<dynamic> rawRows) {
    final rows = rawRows
        .map(
          (row) =>
              (row as List<dynamic>).map((cell) => cell.toString()).toList(),
        )
        .toList(growable: false);
    if (rows.isEmpty) return const SizedBox.shrink();
    final columnCount = rows
        .map((row) => row.length)
        .fold<int>(0, (a, b) => a > b ? a : b);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: const Color(0xFFD8E2F0)),
        children: rows
            .map(
              (row) => TableRow(
                children: List.generate(
                  columnCount,
                  (index) => Padding(
                    padding: const EdgeInsets.all(7),
                    child: SafeLinkText(index < row.length ? row[index] : ''),
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}
