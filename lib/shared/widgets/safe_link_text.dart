/**
 * WHAT:
 * SafeLinkText renders exact user-authored text while making only normal web
 * URLs clickable and keeping all surrounding content selectable.
 * WHY:
 * Learners may submit useful links, but answer text must never be interpreted
 * as HTML or allow unsafe schemes such as javascript, data, or file.
 * HOW:
 * Split plain text with a bounded URL matcher, validate http/https targets,
 * and attach launch recognizers only to the validated spans.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SafeLinkText extends StatefulWidget {
  const SafeLinkText(
    this.text, {
    super.key,
    this.style,
    this.linkStyle,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;
  final TextStyle? linkStyle;
  final TextAlign? textAlign;

  @override
  State<SafeLinkText> createState() => _SafeLinkTextState();
}

class _SafeLinkTextState extends State<SafeLinkText> {
  static final RegExp _webUrl = RegExp(
    r'''(?:https?://|www\.)[^\s<>{}\[\]"']+''',
    caseSensitive: false,
  );

  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _clearRecognizers();
    super.dispose();
  }

  void _clearRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  Uri? _safeUri(String value) {
    final candidate = value.toLowerCase().startsWith('www.')
        ? 'https://$value'
        : value;
    final uri = Uri.tryParse(candidate);
    if (uri == null || !const {'http', 'https'}.contains(uri.scheme)) {
      return null;
    }
    return uri;
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _webUrl.allMatches(widget.text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, match.start)));
      }
      final raw = match.group(0) ?? '';
      final visible = raw.replaceFirst(RegExp(r'[),.;!?]+$'), '');
      final trailing = raw.substring(visible.length);
      final uri = _safeUri(visible);
      if (uri == null) {
        spans.add(TextSpan(text: raw));
      } else {
        final recognizer = TapGestureRecognizer()
          ..onTap = () {
            launchUrl(uri, webOnlyWindowName: '_blank');
          };
        _recognizers.add(recognizer);
        spans.add(
          TextSpan(
            text: visible,
            style:
                widget.linkStyle ??
                TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: Theme.of(context).colorScheme.primary,
                ),
            recognizer: recognizer,
          ),
        );
        if (trailing.isNotEmpty) {
          spans.add(TextSpan(text: trailing));
        }
      }
      cursor = match.end;
    }
    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor)));
    }
    return SelectableText.rich(
      TextSpan(style: widget.style, children: spans),
      textAlign: widget.textAlign,
    );
  }
}
