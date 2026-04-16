import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flap_app/constants/video_categories.dart';
import 'package:flap_app/core/app_auth_context.dart';
import 'package:flap_app/features/challenges/domain/repositories/challenge_repository.dart';
import 'package:flap_app/features/videos/data/thumbnail_service.dart';
import 'package:flap_app/features/videos/domain/repositories/videos_repository.dart';
import 'package:flap_app/features/videos/presentation/screens/challenge_video_upload/challenge_video_upload_view.dart';
import 'package:flap_app/features/videos/presentation/screens/challenge_video_upload/cvu_tokens.dart';
import 'package:flap_app/models/challenge.dart';
import 'package:flap_app/utils/i18n.dart';

@RoutePage()
class VideoUploadScreen extends StatefulWidget {
  const VideoUploadScreen({
    super.key,
    this.challengeId,
    this.challengeTitle,
  });

  final String? challengeId;
  final String? challengeTitle;

  @override
  State<VideoUploadScreen> createState() => _VideoUploadScreenState();
}

class _VideoUploadScreenState extends State<VideoUploadScreen> {
  static const int _maxVideoBytes = 25 * 1024 * 1024;
  static const Duration _maxVideoDuration = Duration(seconds: 10);

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedCategoryId;
  String? _selectedDifficulty;
  XFile? _pickedVideo;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  Challenge? _challengeMeta;
  bool _challengeMetaLoading = false;
  String? _challengeMetaError;

  CvuFlowPhase _cvuPhase = CvuFlowPhase.draft;
  String? _cvuInlineError;

  List<String> get _difficulties => [
        I18n.inline('Легкий', 'Easy'),
        I18n.inline('Середній', 'Medium'),
        I18n.inline('Складний', 'Hard'),
        I18n.inline('Експерт', 'Expert'),
      ];

  bool get _isChallengeMode => widget.challengeId != null && widget.challengeId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_isChallengeMode) {
      _challengeMetaLoading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadChallengeMeta());
    }
  }

  Future<void> _loadChallengeMeta() async {
    final id = widget.challengeId;
    if (id == null || id.isEmpty) return;
    setState(() {
      _challengeMetaLoading = true;
      _challengeMetaError = null;
    });
    try {
      final c = await context.read<ChallengeRepository>().getChallenge(id);
      if (!mounted) return;
      setState(() {
        _challengeMeta = c;
        _challengeMetaLoading = false;
        if (c == null) {
          _challengeMetaError = I18n.inline('Челендж не знайдено', 'Challenge not found');
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _challengeMetaLoading = false;
        _challengeMetaError = e.toString();
      });
    }
  }

  Future<void> _pickVideo({bool fromCamera = false}) async {
    if (_isChallengeMode && (_cvuPhase == CvuFlowPhase.uploading || _cvuPhase == CvuFlowPhase.success)) {
      return;
    }
    final picker = ImagePicker();
    final XFile? picked = await picker.pickVideo(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxDuration: _maxVideoDuration,
    );

    if (picked == null) {
      if (mounted && !_isChallengeMode) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.inline('Вибір відео скасовано', 'Video selection cancelled'))),
        );
      }
      return;
    }

    final fileSize = await picked.length();
    if (fileSize > _maxVideoBytes) {
      if (mounted) {
        final msg = I18n.inline(
          'Файл занадто великий. Максимум 25 МБ.',
          'File is too large. Maximum size is 25 MB.',
        );
        if (_isChallengeMode) {
          setState(() => _cvuInlineError = msg);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.redAccent, content: Text(msg)),
          );
        }
      }
      return;
    }

    setState(() {
      _pickedVideo = picked;
      _cvuInlineError = null;
      if (_isChallengeMode) {
        _cvuPhase = CvuFlowPhase.draft;
      }
    });

    if (mounted && !_isChallengeMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.inline('Відео додано!', 'Video added!'))),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isChallengeMode) {
      if (_challengeMetaLoading) {
        return Scaffold(
          backgroundColor: CvuTokens.bg0,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    color: CvuTokens.accent,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  I18n.inline('Завантаження челенджу…', 'Loading challenge…'),
                  style: const TextStyle(color: CvuTokens.muted, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
      }
      if (_challengeMetaError != null && _challengeMeta == null) {
        return Scaffold(
          backgroundColor: CvuTokens.bg0,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  IconButton(
                    alignment: Alignment.centerLeft,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: CvuTokens.text),
                  ),
                  const Spacer(),
                  const Icon(Icons.search_off_rounded, size: 48, color: CvuTokens.muted),
                  const SizedBox(height: 16),
                  Text(
                    I18n.inline('Не вдалося відкрити челендж', 'Couldn’t open challenge'),
                    style: const TextStyle(
                      color: CvuTokens.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _challengeMetaError!,
                    style: const TextStyle(color: CvuTokens.muted, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loadChallengeMeta,
                    style: FilledButton.styleFrom(
                      backgroundColor: CvuTokens.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(I18n.inline('Повторити', 'Retry')),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        );
      }

      return ChallengeVideoUploadView(
        challenge: _challengeMeta,
        flowPhase: _cvuPhase,
        uploadProgress: _uploadProgress,
        pickedFileLabel: _pickedVideo?.name,
        hasVideo: _pickedVideo != null,
        clipTitleController: _titleController,
        errorMessage: _cvuInlineError,
        onBack: () => Navigator.pop(context),
        onPickGallery: _isUploading ? () {} : () => _pickVideo(fromCamera: false),
        onPickCamera: _isUploading ? () {} : () => _pickVideo(fromCamera: true),
        onSubmit: _isUploading ? () {} : _uploadVideo,
        onRetryAfterFailure: () {
          setState(() {
            _cvuPhase = CvuFlowPhase.draft;
            _cvuInlineError = null;
          });
        },
        onClearError: () => setState(() => _cvuInlineError = null),
      );
    }

    return _buildGenericUploadScaffold(context);
  }

  Widget _buildGenericUploadScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: CvuTokens.bg0,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: CvuTokens.text,
        title: Text(
          I18n.t('upload_video'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  I18n.t('show_skills'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: CvuTokens.text,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  I18n.t('upload_get_ratings'),
                  style: const TextStyle(fontSize: 16, color: CvuTokens.muted),
                ),
                const SizedBox(height: 30),
                GestureDetector(
                  onTap: _isUploading ? null : () => _pickVideo(fromCamera: false),
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: CvuTokens.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: CvuTokens.stroke),
                    ),
                    child: _pickedVideo != null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.videocam, color: CvuTokens.accent, size: 50),
                              const SizedBox(height: 10),
                              Text(
                                I18n.inline('Відео вибрано!', 'Video selected!'),
                                style: const TextStyle(
                                  color: CvuTokens.text,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                I18n.inline('Натисніть ще раз, щоб змінити', 'Tap again to change'),
                                style: TextStyle(color: CvuTokens.muted.withValues(alpha: 0.85), fontSize: 14),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_circle_outline, color: CvuTokens.accent, size: 50),
                              const SizedBox(height: 15),
                              Text(
                                I18n.inline('Натисніть, щоб вибрати відео', 'Tap to select video'),
                                style: const TextStyle(
                                  color: CvuTokens.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                I18n.inline(
                                  'MP4, до 10 секунд і 25 МБ',
                                  'MP4, up to 10 seconds and 25 MB',
                                ),
                                style: TextStyle(color: CvuTokens.muted.withValues(alpha: 0.85), fontSize: 14),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isUploading ? null : () => _pickVideo(fromCamera: false),
                        icon: const Icon(Icons.video_library),
                        label: Text(I18n.inline('Галерея', 'Gallery')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CvuTokens.surfaceLift,
                          foregroundColor: CvuTokens.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isUploading ? null : () => _pickVideo(fromCamera: true),
                        icon: const Icon(Icons.videocam),
                        label: Text(I18n.inline('Камера', 'Camera')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CvuTokens.accent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: CvuTokens.surface,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: CvuTokens.stroke),
                  ),
                  child: TextFormField(
                    controller: _titleController,
                    style: const TextStyle(color: CvuTokens.text),
                    decoration: InputDecoration(
                      labelText: I18n.inline('Назва відео', 'Video title'),
                      labelStyle: const TextStyle(color: CvuTokens.muted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(15),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return I18n.inline('Введіть назву відео', 'Enter video title');
                      }
                      if (value.length < 3) {
                        return I18n.inline(
                          'Назва має бути не менше 3 символів',
                          'Title must be at least 3 characters',
                        );
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: CvuTokens.surface,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: CvuTokens.stroke),
                  ),
                  child: TextFormField(
                    controller: _descriptionController,
                    style: const TextStyle(color: CvuTokens.text),
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: I18n.inline('Опис', 'Description'),
                      labelStyle: const TextStyle(color: CvuTokens.muted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(15),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return I18n.inline('Введіть опис відео', 'Enter video description');
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: CvuTokens.surface,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: CvuTokens.stroke),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategoryId ?? '',
                    style: const TextStyle(color: CvuTokens.text),
                    dropdownColor: CvuTokens.surfaceLift,
                    decoration: InputDecoration(
                      labelText: I18n.inline('Категорія', 'Category'),
                      labelStyle: const TextStyle(color: CvuTokens.muted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                    ),
                    items: [
                      DropdownMenuItem<String>(
                        value: '',
                        child: Text(
                          I18n.inline('Оберіть категорію', 'Select a category'),
                          style: TextStyle(color: CvuTokens.muted.withValues(alpha: 0.8)),
                        ),
                      ),
                      ...kVideoCategories.map(
                        (category) => DropdownMenuItem<String>(
                          value: category.id,
                          child: Text(category.label(), style: const TextStyle(color: CvuTokens.text)),
                        ),
                      ),
                    ],
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedCategoryId = (newValue == null || newValue.isEmpty) ? null : newValue;
                      });
                    },
                    validator: (value) {
                      if ((_selectedCategoryId ?? '').isEmpty) {
                        return I18n.inline('Виберіть категорію', 'Select category');
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: CvuTokens.surface,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: CvuTokens.stroke),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedDifficulty,
                    style: const TextStyle(color: CvuTokens.text),
                    dropdownColor: CvuTokens.surfaceLift,
                    decoration: InputDecoration(
                      labelText: I18n.inline('Складність', 'Difficulty'),
                      labelStyle: const TextStyle(color: CvuTokens.muted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                    ),
                    items: _difficulties.map((String difficulty) {
                      return DropdownMenuItem<String>(
                        value: difficulty,
                        child: Text(difficulty, style: const TextStyle(color: CvuTokens.text)),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedDifficulty = newValue;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return I18n.inline('Виберіть складність', 'Select difficulty');
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 30),
                if (_isUploading) ...[
                  LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: CvuTokens.stroke,
                    color: CvuTokens.accent,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    I18n.inline(
                      'Завантаження: ${(_uploadProgress * 100).toInt()}%',
                      'Uploading: ${(_uploadProgress * 100).toInt()}%',
                    ),
                    style: const TextStyle(color: CvuTokens.text, fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: CvuTokens.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    onPressed: _isUploading || _pickedVideo == null ? null : _uploadVideo,
                    child: Text(
                      _isUploading
                          ? I18n.inline('ЗАВАНТАЖЕННЯ...', 'UPLOADING...')
                          : I18n.inline('ЗАВАНТАЖИТИ ВІДЕО', 'UPLOAD VIDEO'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  Future<void> _uploadVideo() async {
    if (_pickedVideo == null) return;

    if (!_isChallengeMode) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
    }

    final challengeRepo = context.read<ChallengeRepository>();
    final videosRepo = context.read<VideosRepository>();
    final user = AppAuthContext.currentUser;
    if (user == null) {
      if (_isChallengeMode) {
        setState(() {
          _cvuPhase = CvuFlowPhase.failed;
          _cvuInlineError =
              I18n.inline('Користувач не авторизований', 'User not authorized');
        });
      }
      return;
    }

    if (_isChallengeMode) {
      final existingSubmission = await challengeRepo.getSubmission(
            challengeId: widget.challengeId!,
            submissionUserId: user.id,
          );
      if (existingSubmission != null) {
        if (!mounted) return;
        setState(() {
          _cvuPhase = CvuFlowPhase.failed;
          _cvuInlineError = I18n.inline(
            'Ви вже подали відео для цього челенджу.',
            'You already joined this challenge and submitted a video.',
          );
        });
        return;
      }
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      if (_isChallengeMode) {
        _cvuPhase = CvuFlowPhase.uploading;
        _cvuInlineError = null;
      }
    });

    try {
      final fileSize = await _pickedVideo!.length();
      if (fileSize > _maxVideoBytes) {
        throw Exception(I18n.inline('Розмір відео перевищує 25 МБ.', 'Video size exceeds 25 MB.'));
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'video_${user.id}_$timestamp.mp4';

      final bytes = await _pickedVideo!.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty) {
        throw Exception(I18n.inline('Порожній файл відео', 'Empty video file'));
      }

      setState(() => _uploadProgress = 0.05);

      final uploaded = await videosRepo.uploadVideoBytes(
        userId: user.id,
        bytes: bytes,
        fileName: fileName,
        isChallengeVideo: _isChallengeMode,
      );

      if (!mounted) return;
      setState(() => _uploadProgress = 0.92);

      final videoUrl = uploaded.publicUrl;

      final author =
          user.displayName ?? user.email?.split('@').first ?? I18n.inline('Користувач', 'User');

      final String videoTitle;
      final String videoDescription;
      if (_isChallengeMode) {
        final raw = _titleController.text.trim();
        videoTitle = raw.isNotEmpty
            ? raw
            : (widget.challengeTitle?.trim().isNotEmpty == true
                ? widget.challengeTitle!.trim()
                : I18n.inline('Відео для челенджу', 'Challenge clip'));
        videoDescription = _descriptionController.text.trim();
      } else {
        videoTitle = _titleController.text.trim();
        videoDescription = _descriptionController.text.trim();
      }

      if (!mounted) return;
      setState(() => _uploadProgress = 1.0);

      String? newLibraryVideoId;
      if (_isChallengeMode) {
        if (!mounted) return;
        await _submitVideoToChallenge(uploaded.path, videoUrl, videoTitle);
      } else {
        newLibraryVideoId = await videosRepo.createVideoRecord(
          userId: user.id,
          authorName: author,
          title: videoTitle,
          description: videoDescription,
          category: normalizeVideoCategoryValue(_selectedCategoryId ?? 'other'),
          difficulty: _selectedDifficulty,
          videoUrl: videoUrl,
          videoStoragePath: uploaded.path,
          challengeId: widget.challengeId,
          challengeTitle: widget.challengeTitle,
          isChallengeVideo: false,
        );
      }

      if (!mounted) return;
      _generateThumbnailInBackground(
        videosRepo,
        videoStoragePath: uploaded.path,
        videoUrl: videoUrl,
        userId: user.id,
        libraryVideoId: newLibraryVideoId,
      );

      if (!mounted) return;

      if (_isChallengeMode) {
        setState(() {
          _cvuPhase = CvuFlowPhase.success;
          _isUploading = false;
        });
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        if (mounted) Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(I18n.inline('Відео успішно завантажено!', 'Video uploaded successfully!')),
            backgroundColor: CvuTokens.accent,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        if (_isChallengeMode) {
          setState(() {
            _cvuPhase = CvuFlowPhase.failed;
            _cvuInlineError = e.toString();
            _isUploading = false;
            _uploadProgress = 0.0;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                I18n.inline('Помилка завантаження: $e', 'Upload error: $e'),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        if (_isChallengeMode && _cvuPhase == CvuFlowPhase.success) {
          // Keep success overlay + progress until delayed pop.
        } else {
          setState(() {
            _isUploading = false;
            _uploadProgress = 0.0;
            if (_isChallengeMode && _cvuPhase == CvuFlowPhase.uploading) {
              _cvuPhase = CvuFlowPhase.draft;
            }
          });
        }
      }
    }
  }

  Future<void> _submitVideoToChallenge(
    String videoId,
    String videoUrl,
    String videoTitle,
  ) async {
    final user = AppAuthContext.currentUser!;
    final author =
        user.displayName ?? user.email?.split('@').first ?? I18n.inline('Користувач', 'User');
    await context.read<ChallengeRepository>().upsertSubmission(
          challengeId: widget.challengeId!,
          userId: user.id,
          videoId: videoId,
          videoUrl: videoUrl,
          title: videoTitle,
          authorName: author,
          isCreatorVideo: false,
        );
  }

  void _generateThumbnailInBackground(
    VideosRepository videosRepo, {
    required String videoStoragePath,
    required String videoUrl,
    required String userId,
    String? libraryVideoId,
  }) {
    Future<void>.delayed(const Duration(seconds: 2), () async {
      try {
        final thumbnailService = ThumbnailService();
        if (widget.challengeId != null) {
          await thumbnailService.generateSubmissionThumbnail(
            videosRepository: videosRepo,
            videoUrl: videoUrl,
            challengeId: widget.challengeId!,
            submissionId: '${widget.challengeId}_$userId',
            userId: userId,
          );
        } else {
          final vid = libraryVideoId;
          if (vid == null || vid.isEmpty) return;
          await thumbnailService.generateAndUploadThumbnail(
            videosRepository: videosRepo,
            videoUrl: videoUrl,
            videoId: vid,
            userId: userId,
          );
        }
      } catch (_) {}
    });
  }
}
