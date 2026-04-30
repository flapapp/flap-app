import 'dart:async';
import 'dart:typed_data';

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/di/injection.dart';
import '../../../../router/app_router.dart';
import '../../../profile/domain/repositories/current_user_profile_avatar_repository.dart';
import '../../../profile/domain/usecases/commit_profile_avatar_urls_usecase.dart';

/// Shown after sign-in when [profiles.avatar_url] is missing — user must upload before the rest of the app.
@RoutePage()
class AvatarRequiredScreen extends StatefulWidget {
  const AvatarRequiredScreen({super.key});

  @override
  State<AvatarRequiredScreen> createState() => _AvatarRequiredScreenState();
}

class _AvatarRequiredScreenState extends State<AvatarRequiredScreen> {
  static const double _avatarDiameter = 260;
  static const double _ringStroke = 10;

  final ImagePicker _picker = ImagePicker();
  Uint8List? _previewBytes;
  bool _uploading = false;
  double _uploadPercent = 0;
  Timer? _progressTimer;

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  void _cancelProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  void _startProgressSimulation({required double cap}) {
    _cancelProgressTimer();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 45), (_) {
      if (!mounted) return;
      setState(() {
        if (_uploadPercent < cap) {
          _uploadPercent = (_uploadPercent + 1.8).clamp(0.0, cap);
        }
      });
    });
  }

  Future<void> _pick() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        final bytes = await image.readAsBytes();
        setState(() => _previewBytes = bytes);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'avatar_pick_photo_failed',
              namedArgs: {'error': e.toString()},
            ),
          ),
        ),
      );
    }
  }

  Future<void> _upload() async {
    final bytes = _previewBytes;
    if (bytes == null || bytes.isEmpty) return;

    setState(() {
      _uploading = true;
      _uploadPercent = 0;
    });

    try {
      setState(() => _uploadPercent = 4);
      _startProgressSimulation(cap: 82);

      final uploadResult =
          await sl<CurrentUserProfileAvatarRepository>().uploadAvatarJpeg(bytes);

      _cancelProgressTimer();
      if (!mounted) return;

      final url = uploadResult.when(
        success: (u) => u,
        failure: (f) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  f.when(
                    cache: () => '',
                    network: (m) => m ?? '',
                    unexpected: (m) => m ?? '',
                    auth: (_, m) => m ?? '',
                  ),
                ),
              ),
            );
          }
          return null;
        },
      );
      if (url == null || !mounted) return;

      setState(() => _uploadPercent = 88);
      _startProgressSimulation(cap: 97);

      final commit = await sl<CommitProfileAvatarUrlsUseCase>()(
        CommitProfileAvatarUrlsParams(downloadUrl: url),
      );

      _cancelProgressTimer();
      if (!mounted) return;

      final ok = commit.when(
        success: (_) => true,
        failure: (f) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  f.when(
                    cache: () => '',
                    network: (m) => m ?? '',
                    unexpected: (m) => m ?? '',
                    auth: (_, m) => m ?? '',
                  ),
                ),
              ),
            );
          }
          return false;
        },
      );
      if (!ok || !mounted) return;

      setState(() => _uploadPercent = 100);
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (!mounted) return;
      await context.router.replace(const ModeSelectionRoute());
    } finally {
      _cancelProgressTimer();
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadPercent = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ringSize = _avatarDiameter + _ringStroke * 2 + 8;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF1e7d32),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr('avatar_required_title'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  tr('avatar_required_subtitle'),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  textAlign: TextAlign.center,
                ),
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: _uploading ? null : _pick,
                      child: SizedBox(
                        width: ringSize,
                        height: ringSize,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            if (_uploading)
                              SizedBox(
                                width: ringSize,
                                height: ringSize,
                                child: CircularProgressIndicator(
                                  value: (_uploadPercent / 100.0).clamp(0.0, 1.0),
                                  strokeWidth: _ringStroke,
                                  strokeCap: StrokeCap.round,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.2),
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    Color(0xFFa5d6a7),
                                  ),
                                ),
                              )
                            else
                              Container(
                                width: ringSize,
                                height: ringSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.38),
                                    width: _ringStroke,
                                  ),
                                ),
                              ),
                            ClipOval(
                              child: Container(
                                width: _avatarDiameter,
                                height: _avatarDiameter,
                                color: Colors.white.withValues(alpha: 0.1),
                                child: _previewBytes != null
                                    ? Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.memory(
                                            _previewBytes!,
                                            fit: BoxFit.cover,
                                          ),
                                          if (_uploading)
                                            ColoredBox(
                                              color: Colors.black
                                                  .withValues(alpha: 0.45),
                                              child: Center(
                                                child: Text(
                                                  '${_uploadPercent.clamp(0, 100).round()}%',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 44,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: -1,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      )
                                    : Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_a_photo,
                                            size: 64,
                                            color: Colors.white
                                                .withValues(alpha: 0.75),
                                          ),
                                          const SizedBox(height: 10),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
                                            child: Text(
                                              tr('il_c0660be883'),
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withValues(alpha: 0.75),
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4caf50),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  onPressed: (_previewBytes == null || _uploading)
                      ? null
                      : _upload,
                  child: _uploading
                      ? Text(
                          tr('uploading'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : Text(
                          tr('il_31fbef1625'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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
}
