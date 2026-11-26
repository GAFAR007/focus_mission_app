/**
 * WHAT: Optional teacher picture controls shared by question and essay editors.
 * WHY: Every mission format should offer the same accessible visual support.
 * HOW: Pick a bounded PNG/JPEG, preview it, and emit picture and description edits.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'question_picture.dart';

class QuestionPictureEditor extends StatefulWidget {
  const QuestionPictureEditor({
    super.key,
    required this.dataUrl,
    required this.description,
    required this.onChanged,
  });
  final String dataUrl;
  final String description;
  final void Function(String dataUrl, String description) onChanged;
  @override
  State<QuestionPictureEditor> createState() => _QuestionPictureEditorState();
}

class _QuestionPictureEditorState extends State<QuestionPictureEditor> {
  late String _dataUrl = widget.dataUrl;
  late String _description = widget.description;
  bool _picking = false;
  String? _error;
  @override
  void didUpdateWidget(covariant QuestionPictureEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataUrl != widget.dataUrl ||
        oldWidget.description != widget.description) {
      _dataUrl = widget.dataUrl;
      _description = widget.description;
    }
  }

  Future<void> _pick() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
        withData: true,
      );
      if (!mounted || result == null) return;
      final bytes = result.files.single.bytes;
      // WHY: Reject unsupported content before storing it in the draft; the API validates again.
      if (bytes == null || bytes.length > 512 * 1024) {
        throw const FormatException('Choose a PNG or JPEG up to 512 KB.');
      }
      const signature = [137, 80, 78, 71, 13, 10, 26, 10];
      final png =
          bytes.length >= 8 &&
          List.generate(8, (i) => bytes[i] == signature[i]).every((v) => v);
      final jpeg =
          bytes.length >= 3 &&
          bytes[0] == 255 &&
          bytes[1] == 216 &&
          bytes[2] == 255;
      if (!png && !jpeg) {
        throw const FormatException('Choose a valid PNG or JPEG picture.');
      }
      setState(() {
        _dataUrl =
            'data:image/${png ? 'png' : 'jpeg'};base64,${base64Encode(bytes)}';
      });
      widget.onChanged(_dataUrl, _description);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? error.message
              : 'Could not open this picture. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _picking ? null : _pick,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(
              _dataUrl.isEmpty ? 'Add picture (optional)' : 'Replace picture',
            ),
          ),
          if (_dataUrl.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  _dataUrl = '';
                  _description = '';
                });
                widget.onChanged('', '');
              },
              child: const Text('Remove picture'),
            ),
        ],
      ),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      if (_dataUrl.isNotEmpty) ...[
        QuestionPicture(dataUrl: _dataUrl, description: _description),
        TextFormField(
          key: ValueKey(_dataUrl),
          initialValue: _description,
          maxLength: 6000,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Picture description (required)',
            helperText:
                'Describe the picture or paste the code so every student can read it.',
          ),
          onChanged: (value) {
            _description = value;
            widget.onChanged(_dataUrl, value);
          },
        ),
      ],
      const SizedBox(height: 12),
    ],
  );
}
