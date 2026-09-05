/**
 * WHAT:
 * LearningVideoCard presents a validated optional YouTube learning clip in a
 * responsive 16:9 card for teacher preview and student learning support.
 * WHY:
 * Videos should supplement Learn First without autoplay, assessment impact,
 * arbitrary HTML injection, or a mandatory watch requirement.
 * HOW:
 * Parse the stored URL to a recognized video ID, lazy-load a privacy-enhanced
 * inline player after an explicit click, and retain an external-link fallback.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/constants/app_palette.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/youtube_video.dart';

class LearningVideoCard extends StatefulWidget {
  const LearningVideoCard({
    super.key,
    required this.url,
    this.placement = LearningVideoPlacements.afterLearnFirst,
    this.showStudentGuidance = false,
    this.onChange,
    this.onRemove,
  });

  final String url;
  final String placement;
  final bool showStudentGuidance;
  final VoidCallback? onChange;
  final VoidCallback? onRemove;

  @override
  State<LearningVideoCard> createState() => _LearningVideoCardState();
}

class _LearningVideoCardState extends State<LearningVideoCard> {
  YoutubePlayerController? _controller;
  String _controllerVideoId = '';
  bool _showPlayer = false;

  @override
  void didUpdateWidget(covariant LearningVideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextVideoId = parseYouTubeVideoUrl(widget.url)?.videoId ?? '';
    if (_controllerVideoId.isNotEmpty && _controllerVideoId != nextVideoId) {
      _controller?.close();
      _controller = null;
      _controllerVideoId = '';
      _showPlayer = false;
    }
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = parseYouTubeVideoUrl(widget.url);
    if (video == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.item),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7F4), Color(0xFFFFE9E4)],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: const Color(0xFFFFC9BF)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final media = _buildMedia(video);
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YouTube learning video',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: AppPalette.navy),
              ),
              const SizedBox(height: 4),
              Text(
                LearningVideoPlacements.label(widget.placement),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF8B4C45),
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (widget.showStudentGuidance) ...[
                const SizedBox(height: 8),
                Text(
                  'Watch this short video if it helps you understand the idea. You can continue without watching.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppPalette.textMuted),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _showInlinePlayer(video),
                    icon: const Icon(Icons.play_circle_outline_rounded),
                    label: Text(
                      widget.showStudentGuidance
                          ? 'Watch video'
                          : 'Preview video',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _openVideo(context, video),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Open on YouTube'),
                  ),
                  if (widget.onChange != null)
                    TextButton.icon(
                      onPressed: widget.onChange,
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Change'),
                    ),
                  if (widget.onRemove != null)
                    TextButton.icon(
                      onPressed: widget.onRemove,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Remove'),
                    ),
                ],
              ),
            ],
          );

          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                media,
                const SizedBox(height: AppSpacing.item),
                details,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: _showPlayer ? 420 : 260, child: media),
              const SizedBox(width: AppSpacing.item),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMedia(YouTubeVideoReference video) {
    if (_showPlayer) {
      return Semantics(
        label: 'Embedded optional YouTube learning video player',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: YoutubePlayer(
            key: ValueKey<String>('youtube-player-${video.videoId}'),
            controller: _controllerFor(video),
            aspectRatio: 16 / 9,
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: 'Show the optional YouTube learning video player',
      child: InkWell(
        onTap: () => _showInlinePlayer(video),
        borderRadius: BorderRadius.circular(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  video.thumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFFFFDDD5),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.ondemand_video_rounded,
                      color: Color(0xFF9E4035),
                      size: 42,
                    ),
                  ),
                ),
                const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 56,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 12)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  YoutubePlayerController _controllerFor(YouTubeVideoReference video) {
    if (_controller == null || _controllerVideoId != video.videoId) {
      _controller?.close();
      _controllerVideoId = video.videoId;
      _controller = YoutubePlayerController.fromVideoId(
        videoId: video.videoId,
        autoPlay: false,
        params: const YoutubePlayerParams(
          enableCaption: true,
          playsInline: true,
          privacyEnhancedMode: true,
          showControls: true,
          showFullscreenButton: true,
          strictRelatedVideos: true,
        ),
      );
    }
    return _controller!;
  }

  void _showInlinePlayer(YouTubeVideoReference video) {
    // WHY: The iframe is created only after an explicit teacher or student
    // action and starts paused, preventing autoplay and unnecessary page load.
    _controllerFor(video);
    setState(() => _showPlayer = true);
  }

  Future<void> _openVideo(
    BuildContext context,
    YouTubeVideoReference video,
  ) async {
    final opened = await launchUrl(
      Uri.parse(video.canonicalUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the YouTube video.')),
      );
    }
  }
}
