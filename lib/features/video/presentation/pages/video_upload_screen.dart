import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_app_storage.dart';
import '../../../../constants/video_categories.dart';
import '../../../../core/di/injection.dart';
import '../../../../theme/flap_tokens.dart';
import '../../../../widgets/video_preview_box.dart';
import '../../../challenges/domain/repositories/challenges_repository.dart';
import '../../../profile/presentation/bloc/profile_bloc.dart';
import '../video_feed_sync.dart';
import '../../data/services/thumbnail_service.dart';
import 'package:flap_app/core/auth/app_auth.dart';

@RoutePage()
class VideoUploadScreen extends StatefulWidget {
  final String? challengeId;
  final String? challengeTitle;
  
  const VideoUploadScreen({
    Key? key, 
    this.challengeId, 
    this.challengeTitle,
  }) : super(key: key);

  @override
  _VideoUploadScreenState createState() => _VideoUploadScreenState();
}

class _VideoUploadScreenState extends State<VideoUploadScreen> {
  static const int _maxVideoBytes = 25 * 1024 * 1024;
  static const Duration _maxVideoDuration = Duration(seconds: 10);
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String? _selectedCategory;
  String? _selectedDifficulty;
  XFile? _pickedVideo;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  List<String> get _difficulties => [
    tr('il_d6915875de'),
    tr('il_8e588cd187'),
    tr('il_9e73f8fa9c'),
    tr('il_8b317b0c50'),
  ];

  Future<void> _pickVideo({bool fromCamera = false}) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickVideo(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxDuration: _maxVideoDuration,
    );

    if (picked == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('il_9a523553f3'))),
        );
      }
      return;
    }

    final fileSize = await picked.length();
    if (fileSize > _maxVideoBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              tr('il_c5e57856db'),
            ),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _pickedVideo = picked;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('il_045038419d'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleText = widget.challengeId != null
        ? tr(
            'il_0b714f54fd',
            args: [
              (widget.challengeTitle != null &&
                      widget.challengeTitle!.trim().isNotEmpty)
                  ? widget.challengeTitle!.trim()
                  : tr('challenges'),
            ],
          )
        : tr('video_upload_clip');

    return Scaffold(
      backgroundColor: FlapColors.bg,
      appBar: AppBar(
        backgroundColor: FlapColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 66,
        leadingWidth: 60,
        titleSpacing: 0,
        leading: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: FlapColors.surface2,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: FlapColors.border),
                ),
                child: const Icon(Icons.chevron_left,
                    color: FlapColors.text, size: 19),
              ),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Text(
            //   tr('video_upload_sub'),
            //   style: FlapText.sora(
            //       fontSize: 11.5,
            //       fontWeight: FontWeight.w500,
            //       color: FlapColors.muted),
            // ),
            const SizedBox(height: 1),
            Text(
              titleText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FlapText.sora(fontSize: 19, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Upload box (9:16, dashed striped → preview once picked)
                Center(
                  child: GestureDetector(
                    onTap: _isUploading ? null : _showSourceChooser,
                    child: SizedBox(
                      width: 169,
                      height: 300,
                      child: _pickedVideo == null
                          ? CustomPaint(
                              painter: _UploadBoxPainter(),
                              child: Center(child: _uploadPlaceholder()),
                            )
                          : _buildPickedPreview(),
                    ),
                  ),
                ),
                // Fields for normal videos only (not challenges)
                if (widget.challengeId == null) ...[
                  const SizedBox(height: 22),
                  _fieldLabel(tr('video_field_title')),
                  _styledField(
                    controller: _titleController,
                    hint: tr('video_upload_title_hint'),
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return tr('il_5b97d44a4d');
                      }
                      if (value.length < 3) {
                        return tr('il_ae600ea5b0');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  _fieldLabel(tr('il_526e0087cc')),
                  _styledField(
                    controller: _descriptionController,
                    hint: tr('il_526e0087cc'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 15),
                  _fieldLabel(tr('il_292c06f004')),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.zero,
                      itemCount: kVideoCategories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final category = kVideoCategories[i];
                        return _uploadChip(
                          category.label(),
                          selected: _selectedCategory == category.id,
                          onTap: () => setState(() {
                            _selectedCategory =
                                _selectedCategory == category.id
                                    ? null
                                    : category.id;
                          }),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 15),
                  _fieldLabel(tr('il_be44133ed5')),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.zero,
                      itemCount: _difficulties.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final d = _difficulties[i];
                        return _uploadChip(
                          d,
                          selected: _selectedDifficulty == d,
                          onTap: () => setState(() {
                            _selectedDifficulty =
                                _selectedDifficulty == d ? null : d;
                          }),
                        );
                      },
                    ),
                  ),
                ],

                if (_isUploading) ...[
                  const SizedBox(height: 22),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: _uploadProgress,
                      minHeight: 6,
                      backgroundColor: FlapColors.surface2,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          FlapColors.greenBright),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      'upload_progress_percent',
                      namedArgs: {
                        'percent': '${(_uploadProgress * 100).toInt()}',
                      },
                    ),
                    style: FlapText.sora(
                        fontSize: 12.5, color: FlapColors.muted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: FlapColors.bg,
          border: Border(top: BorderSide(color: FlapColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Builder(builder: (context) {
            final disabled = _isUploading ||
                _pickedVideo == null ||
                (widget.challengeId == null &&
                    _titleController.text.trim().isEmpty);
            return GestureDetector(
              onTap: disabled ? null : _uploadVideo,
              child: Opacity(
                opacity: disabled ? 0.45 : 1,
                child: Container(
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: FlapColors.primaryButton,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isUploading
                            ? tr('il_b3a3bd2970')
                            : widget.challengeId != null
                                ? tr('il_905236a2ac')
                                : tr('video_publish'),
                        style: FlapText.sora(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: FlapColors.onGreen),
                      ),
                      if (!_isUploading) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded,
                            color: FlapColors.onGreen, size: 19),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _uploadPlaceholder() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 58,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: FlapColors.green.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: FlapColors.green.withValues(alpha: 0.35)),
          ),
          child: const Icon(Icons.play_arrow_rounded,
              color: FlapColors.greenBright, size: 26),
        ),
        const SizedBox(height: 12),
        Text(
          tr('video_upload_box_title'),
          style: FlapText.sora(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            tr('video_upload_box_hint'),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FlapText.sora(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: FlapColors.muted),
          ),
        ),
      ],
    );
  }

  Widget _buildPickedPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          VideoPreviewBox(
            key: ValueKey(_pickedVideo!.path),
            videoUrl: _pickedVideo!.path,
            aspectRatio: 9 / 16,
            borderRadius: 18,
            showPlayIcon: false,
            placeholderColor: const Color(0xFF0D1A15),
          ),
          // Bottom gradient + filename + change hint.
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF070A08).withValues(alpha: 0.85),
                  ],
                  stops: const [0.55, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            left: 11,
            right: 11,
            bottom: 11,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _pickedVideo!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FlapText.sora(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  tr('il_79906b4600'),
                  style: FlapText.sora(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFCDD4CE)),
                ),
              ],
            ),
          ),
          // Selected badge.
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: FlapColors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: FlapColors.onGreen, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        text,
        style: FlapText.sora(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: FlapColors.muted),
      ),
    );
  }

  Widget _styledField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      style: FlapText.sora(fontSize: 14),
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: FlapText.sora(fontSize: 14, color: FlapColors.muted),
        filled: true,
        fillColor: const Color(0x09FFFFFF),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: FlapColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: FlapColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: FlapColors.green),
        ),
        errorStyle: FlapText.sora(fontSize: 11.5, color: FlapColors.red),
      ),
    );
  }

  Widget _uploadChip(String label,
      {required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 38,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected
              ? FlapColors.green.withValues(alpha: 0.16)
              : FlapColors.surface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected
                ? FlapColors.green.withValues(alpha: 0.5)
                : FlapColors.border,
          ),
        ),
        child: Text(
          label,
          style: FlapText.sora(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? FlapColors.greenBright : FlapColors.muted,
          ),
        ),
      ),
    );
  }

  void _showSourceChooser() {
    showModalBottomSheet(
      context: context,
      backgroundColor: FlapColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              _chooserRow(
                icon: Icons.photo_library_outlined,
                label: tr('il_352cfc749e'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickVideo(fromCamera: false);
                },
              ),
              const SizedBox(height: 8),
              _chooserRow(
                icon: Icons.videocam_outlined,
                label: tr('il_03494b0d1f'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickVideo(fromCamera: true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chooserRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: FlapColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FlapColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: FlapColors.green.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
                border:
                    Border.all(color: FlapColors.green.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, size: 19, color: FlapColors.greenBright),
            ),
            const SizedBox(width: 12),
            Text(label,
                style:
                    FlapText.sora(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadVideo() async {
    if (!_formKey.currentState!.validate() || _pickedVideo == null) {
      return;
    }
    // Category & difficulty are chip selections (not form fields), so validate
    // them manually for regular (non-challenge) uploads.
    if (widget.challengeId == null) {
      if ((_selectedCategory ?? '').isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('il_e26788c574'))),
        );
        return;
      }
      if ((_selectedDifficulty ?? '').isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('il_efd7187705'))),
        );
        return;
      }
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final user = AppAuth.currentUser;
      if (user == null) {
        throw Exception(tr('il_76144c407d'));
      }

      final fileSize = await _pickedVideo!.length();
      if (fileSize > _maxVideoBytes) {
        throw Exception(
          tr('il_8af3536c64'),
        );
      }

      // Generate unique file names
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'video_${user.id}_$timestamp.mp4';
      
      print('[video_upload] Starting video upload: $fileName');

      // Upload video bytes (web-compatible)
      final bytes = await _pickedVideo!.readAsBytes();
      if (!mounted) return;
      setState(() => _uploadProgress = 0.15);

      final client = Supabase.instance.client;
      final videoUrl = await SupabaseAppStorage.uploadPublicBytes(
        client,
        bucket: SupabaseAppStorage.videos,
        path: '${user.id}/$fileName',
        bytes: bytes,
        contentType: 'video/mp4',
      );

      if (!mounted) return;
      setState(() => _uploadProgress = 1.0);
      
      print('[video_upload] Video uploaded successfully: $videoUrl');

      if (widget.challengeId != null) {
        await _submitVideoToChallengeOnly(client, videoUrl, user.id);
        final sub = await client
            .from('challenge_submissions')
            .select('id')
            .eq('challenge_id', widget.challengeId!)
            .eq('user_id', user.id)
            .maybeSingle();
        final submissionId = (sub?['id'] ?? '').toString();
        if (submissionId.isNotEmpty) {
          _generateChallengeSubmissionThumbnailInBackground(
            submissionId,
            videoUrl,
            user.id,
            widget.challengeId!,
          );
        }
      } else {
        final desc = _descriptionController.text.trim();
        final videoData = <String, dynamic>{
          'user_id': user.id,
          'title': _titleController.text.trim().isEmpty
              ? (widget.challengeTitle ?? tr('il_d534be829e'))
              : _titleController.text.trim(),
          'video_url': videoUrl,
          'thumbnail_url': null,
        };
        if (desc.isNotEmpty) {
          videoData['description'] = desc;
        }

        final difficulty = await client
            .from('video_difficulties')
            .select('id')
            .eq('code', (_selectedDifficulty ?? '').toLowerCase())
            .maybeSingle();
        final selectedCategory = (_selectedCategory ?? '').trim();
        if (selectedCategory.isNotEmpty) {
          videoData['category'] = selectedCategory;
        }
        if (difficulty != null) {
          videoData['difficulty_id'] = difficulty['id'];
        }

        final videoDoc = await client.from('videos').insert(videoData).select('id').single();
        final videoId = (videoDoc['id'] ?? '').toString();
        print('[video_upload] Video document created: $videoId');
        _generateThumbnailInBackground(videoId, videoUrl, user.id);
        sl<ProfileBloc>().add(const ProfileEvent.userProfileSyncRequested());
        sl<VideoFeedSync>().notifyFeedMayHaveChanged();
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_8e1f1900d9')),
            backgroundColor: const Color(0xFF4caf50),
          ),
        );

        // Pop back to previous screen
        Navigator.pop(context);
      }

    } catch (e) {
      print('[video_upload] ERROR uploading video: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_ef709be5c7', args: [e.toString()])),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  /// Challenge videos are not inserted into [videos]; [challenge_submissions.video_url] is canonical.
  Future<void> _submitVideoToChallengeOnly(
    SupabaseClient client,
    String videoUrl,
    String userId,
  ) async {
    await sl<ChallengesRepository>().addVideoToChallenge(widget.challengeId!, userId);

    final subDesc = _descriptionController.text.trim();
    final submission = <String, dynamic>{
      'challenge_id': widget.challengeId!,
      'user_id': userId,
      'video_url': videoUrl,
      'title': _titleController.text.trim(),
      'thumbnail_url': null,
    };
    if (subDesc.isNotEmpty) {
      submission['description'] = subDesc;
    }
    await client.from('challenge_submissions').upsert(
      submission,
      onConflict: 'challenge_id,user_id',
    );

    print('[video_upload] Video submitted to challenge (submission only): ${widget.challengeId}');
  }

  void _generateChallengeSubmissionThumbnailInBackground(
    String submissionId,
    String videoUrl,
    String userId,
    String challengeId,
  ) {
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        final thumbnailService = ThumbnailService();
        final thumbnailUrl = await thumbnailService.generateSubmissionThumbnail(
          videoUrl: videoUrl,
          challengeId: challengeId,
          submissionId: submissionId,
          userId: userId,
        );
        if (thumbnailUrl != null) {
          print('[video_upload] Challenge submission thumbnail: $thumbnailUrl');
        }
      } catch (e) {
        print('[video_upload] ERROR challenge submission thumbnail: $e');
      }
    });
  }

  void _generateThumbnailInBackground(String videoId, String videoUrl, String userId) {
    // Generate thumbnail in background without blocking UI
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        print('[video_upload] Starting background thumbnail generation for: $videoId');
        
        final thumbnailService = ThumbnailService();
        final thumbnailUrl = await thumbnailService.generateAndUploadThumbnail(
          videoUrl: videoUrl,
          videoId: videoId,
          userId: userId,
        );

        if (thumbnailUrl != null) {
          print('[video_upload] Thumbnail generated successfully: $thumbnailUrl');
        } else {
          print('[video_upload] WARN: Thumbnail generation failed, but video upload was successful');
        }
      } catch (e) {
        print('[video_upload] ERROR background thumbnail generation: $e');
        // Swallow thumbnail errors; video already uploaded
      }
    });
  }
}
/// Diagonal striped fill + dashed border for the upload box (design `.uploadbox`).
class _UploadBoxPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(18));

    canvas.save();
    canvas.clipRRect(rrect);
    // Base + 16px diagonal stripes (135deg).
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0D1A15));
    final stripe = Paint()
      ..color = const Color(0xFF11201A)
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke;
    for (double x = -size.height; x < size.width + size.height; x += 32) {
      canvas.drawLine(
          Offset(x, 0), Offset(x + size.height, size.height), stripe);
    }
    canvas.restore();

    // 1.5px dashed border (border-strong).
    final border = Path()..addRRect(rrect.deflate(0.75));
    final paint = Paint()
      ..color = const Color(0x29FFFFFF)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (final metric in border.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final end = (dist + 6).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(dist, end), paint);
        dist += 11; // 6 dash + 5 gap
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
