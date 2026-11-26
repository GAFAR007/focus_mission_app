/**
 * WHAT: Displays a teacher-provided question picture and accessible description.
 * WHY: Students must inspect source material without leaving a focused exam.
 * HOW: Decode private raster data and enlarge it in an in-page zoom dialog.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class QuestionPicture extends StatefulWidget {
  const QuestionPicture({
    super.key,
    required this.dataUrl,
    required this.description,
  });
  final String dataUrl;
  final String description;

  @override
  State<QuestionPicture> createState() => _QuestionPictureState();
}

class _QuestionPictureState extends State<QuestionPicture> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _decodePicture();
  }

  @override
  void didUpdateWidget(covariant QuestionPicture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataUrl != widget.dataUrl) _decodePicture();
  }

  void _decodePicture() {
    // WHY: MemoryImage compares byte identity. Decoding on every timer/heartbeat
    // rebuild causes a new image load, briefly collapsing the image and moving answers.
    try {
      _bytes = widget.dataUrl.isEmpty
          ? null
          : base64Decode(widget.dataUrl.split(',').last);
    } catch (_) {
      _bytes = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dataUrl.isEmpty) return const SizedBox.shrink();
    final bytes = _bytes;
    final description = widget.description;
    if (bytes == null) {
      // WHY: A damaged image must not prevent saved answers from loading.
      return Text('Picture unavailable. $description');
    }
    Widget picture() => Image.memory(
      bytes,
      fit: BoxFit.contain,
      semanticLabel: description,
      errorBuilder: (_, error, stack) =>
          Text('Picture unavailable. $description'),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: picture(),
            ),
          ),
          TextButton.icon(
            icon: const Icon(Icons.zoom_in),
            label: const Text('Enlarge picture'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: SizedBox(
                  width: 1100,
                  height: 700,
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close),
                          label: const Text('Close picture'),
                        ),
                      ),
                      Expanded(
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 5,
                          child: Center(child: picture()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ExpansionTile(
            title: const Text('Read picture description'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(description),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
