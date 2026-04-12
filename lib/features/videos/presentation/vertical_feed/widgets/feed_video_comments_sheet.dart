import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flap_app/core/app_auth_context.dart';
import 'package:flap_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:flap_app/features/videos/domain/entities/video_comment.dart';
import 'package:flap_app/features/videos/domain/repositories/videos_repository.dart';
import 'package:flap_app/utils/i18n.dart';

String _formatCommentDate(DateTime? timestamp) {
  if (timestamp == null) return I18n.inline('Нещодавно', 'Recently');
  final now = DateTime.now();
  final difference = now.difference(timestamp);
  if (difference.inDays > 0) {
    return I18n.inline('${difference.inDays} дн. тому', '${difference.inDays} d ago');
  }
  if (difference.inHours > 0) {
    return I18n.inline('${difference.inHours} год. тому', '${difference.inHours} h ago');
  }
  if (difference.inMinutes > 0) {
    return I18n.inline('${difference.inMinutes} хв. тому', '${difference.inMinutes} min ago');
  }
  return I18n.inline('Щойно', 'Just now');
}

/// Bottom sheet: list comments + composer (same APIs as [VideoPlayerScreen]).
Future<void> showFeedVideoCommentsSheet(
  BuildContext hostContext, {
  required String videoId,
  required void Function(int totalCount) onCommentCountUpdated,
}) async {
  if (videoId.isEmpty) return;

  await showModalBottomSheet<void>(
    context: hostContext,
    backgroundColor: const Color(0xFF1a1a2e),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _FeedVideoCommentsSheet(
      videoId: videoId,
      onCommentCountUpdated: onCommentCountUpdated,
    ),
  );
}

class _FeedVideoCommentsSheet extends StatefulWidget {
  const _FeedVideoCommentsSheet({
    required this.videoId,
    required this.onCommentCountUpdated,
  });

  final String videoId;
  final void Function(int totalCount) onCommentCountUpdated;

  @override
  State<_FeedVideoCommentsSheet> createState() => _FeedVideoCommentsSheetState();
}

class _FeedVideoCommentsSheetState extends State<_FeedVideoCommentsSheet> {
  final TextEditingController _composer = TextEditingController();
  List<VideoComment> _comments = [];
  bool _loading = true;
  bool _submitting = false;

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() => _loading = true);
    try {
      final list =
          await context.read<VideosRepository>().fetchComments(widget.videoId);
      if (!mounted) return;
      setState(() {
        _comments = list;
        _loading = false;
      });
      widget.onCommentCountUpdated(_comments.length);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;

    final user = AppAuthContext.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            I18n.inline('Увійдіть, щоб коментувати', 'Sign in to comment'),
          ),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final prof =
          await context.read<ProfileRepository>().fetchLegacyUserMap(user.id);
      if (!mounted) return;
      final authorName = (prof?['displayName'] ?? prof?['name'] ?? 'Unknown').toString();

      await context.read<VideosRepository>().addComment(
            videoId: widget.videoId,
            userId: user.id,
            authorName: authorName,
            body: text,
          );

      if (!mounted) return;
      _composer.clear();
      await _loadComments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.inline('Коментар додано', 'Comment added')),
          backgroundColor: const Color(0xFF4caf50),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              I18n.inline('Не вдалося надіслати коментар', 'Could not send comment'),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white54,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.comment_outlined, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      I18n.inline('Коментарі', 'Comments'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _composer,
                        enabled: !_submitting,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: I18n.inline('Додати коментар...', 'Add a comment...'),
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _submitting
                        ? Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2e7d32),
                              shape: BoxShape.circle,
                            ),
                            child: const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : IconButton(
                            onPressed: _submit,
                            icon: const Icon(Icons.send, color: Colors.white),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF4caf50),
                              shape: const CircleBorder(),
                            ),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white54),
                      )
                    : _comments.isEmpty
                        ? Center(
                            child: Text(
                              I18n.inline('Поки що немає коментарів', 'No comments yet'),
                              style: const TextStyle(color: Colors.white54, fontSize: 16),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: _comments.length,
                            itemBuilder: (context, index) {
                              final c = _comments[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            c.authorName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _formatCommentDate(c.createdAt),
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      c.body,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}
