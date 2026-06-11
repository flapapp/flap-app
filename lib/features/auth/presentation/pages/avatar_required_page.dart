import 'dart:async';
import 'dart:typed_data';

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/di/injection.dart';
import '../../../../router/app_router.dart';
import '../../../../theme/flap_tokens.dart';
import '../../../profile/domain/repositories/current_user_profile_avatar_repository.dart';
import '../../../profile/domain/usecases/commit_profile_avatar_urls_usecase.dart';
import '../widgets/auth_widgets.dart';

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
    final hasPhoto = _previewBytes != null;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: FlapColors.bg,
        body: Container(
          decoration: const BoxDecoration(gradient: FlapColors.screenGlow),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Center(child: AuthEyebrow(tr('auth_eyebrow_welcome'))),
                  const SizedBox(height: 14),
                  Text(
                    tr('avatar_required_title'),
                    style: FlapText.cond(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: FlapColors.text,
                      height: 1.05,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr('avatar_required_subtitle'),
                    style: FlapText.sora(
                      fontSize: 14,
                      color: FlapColors.muted,
                      height: 1.45,
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
                                    value:
                                        (_uploadPercent / 100.0).clamp(0.0, 1.0),
                                    strokeWidth: _ringStroke,
                                    strokeCap: StrokeCap.round,
                                    backgroundColor: FlapColors.surface2,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                      FlapColors.greenBright,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  width: ringSize,
                                  height: ringSize,
                                  padding: const EdgeInsets.all(_ringStroke),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: SweepGradient(
                                      colors: [
                                        FlapColors.green,
                                        FlapColors.greenBright,
                                        FlapColors.greenDeep,
                                        FlapColors.green,
                                      ],
                                    ),
                                  ),
                                  child: const DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: FlapColors.bg,
                                    ),
                                  ),
                                ),
                              ClipOval(
                                child: Container(
                                  width: _avatarDiameter,
                                  height: _avatarDiameter,
                                  color: FlapColors.card2,
                                  child: hasPhoto
                                      ? Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Image.memory(
                                              _previewBytes!,
                                              fit: BoxFit.cover,
                                            ),
                                            if (_uploading)
                                              ColoredBox(
                                                color: FlapColors.bg
                                                    .withValues(alpha: 0.6),
                                                child: Center(
                                                  child: Text(
                                                    '${_uploadPercent.clamp(0, 100).round()}%',
                                                    style: FlapText.cond(
                                                      color: FlapColors.text,
                                                      fontSize: 48,
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
                                            const Icon(
                                              Icons.add_a_photo_rounded,
                                              size: 60,
                                              color: FlapColors.greenBright,
                                            ),
                                            const SizedBox(height: 12),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                              ),
                                              child: Text(
                                                tr('il_c0660be883'),
                                                textAlign: TextAlign.center,
                                                style: FlapText.sora(
                                                  color: FlapColors.muted,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                              if (hasPhoto && !_uploading)
                                Positioned(
                                  right: 18,
                                  bottom: 18,
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      gradient: FlapColors.primaryButton,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: FlapColors.bg, width: 4),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      color: FlapColors.onGreen,
                                      size: 20,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AuthPrimaryButton(
                    label: _uploading ? tr('uploading') : tr('il_31fbef1625'),
                    loading: _uploading,
                    showArrow: !_uploading,
                    onTap: (!hasPhoto || _uploading) ? null : _upload,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
