import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flap_app/app_locale_access.dart';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_app_storage.dart';
import '../../../../constants/video_categories.dart';
import '../../../../core/di/injection.dart';
import '../../../challenges/domain/repositories/challenges_repository.dart';
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
  
  String? _selectedCategoryId;
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

    setState(() {
      _pickedVideo = picked;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('il_045038419d'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1e7d32),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.challengeId != null 
            ? tr(
                'il_0b714f54fd',
                args: [
                  (widget.challengeTitle != null &&
                          widget.challengeTitle!.trim().isNotEmpty)
                      ? widget.challengeTitle!.trim()
                      : tr('challenges'),
                ],
              )
            : tr('upload_video'),
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                // Заголовок
                Text(
                  widget.challengeId != null 
                    ? tr('il_cde4c7cfff')
                    : tr('show_skills'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.challengeId != null
                    ? tr('il_d74c27d5af')
                    : tr('upload_get_ratings'),
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 30),

                // Вибір відео
                GestureDetector(
                  onTap: _isUploading ? null : () => _pickVideo(fromCamera: false),
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: _pickedVideo != null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.videocam,
                                color: Colors.white,
                                size: 50,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                tr('il_46b82fc56c'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                tr('il_79906b4600'),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.add_circle_outline,
                                color: Colors.white,
                                size: 50,
                              ),
                              const SizedBox(height: 15),
                              Text(
                                tr('il_0799690a53'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                tr('il_537c5fd217'),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 30),
                // Швидкий вибір джерела: Галерея / Камера
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isUploading ? null : () => _pickVideo(fromCamera: false),
                        icon: const Icon(Icons.video_library),
                        label: Text(tr('il_352cfc749e')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white24,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isUploading ? null : () => _pickVideo(fromCamera: true),
                        icon: const Icon(Icons.videocam),
                        label: Text(tr('il_03494b0d1f')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4caf50),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Поля тільки для звичайних відео (не для челенджів)
                if (widget.challengeId == null) ...[
                  // Назва відео
                  Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: TextFormField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: tr('il_ff9a998595'),
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(15),
                    ),
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
                ),
                const SizedBox(height: 20),

                // Опис
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: TextFormField(
                    controller: _descriptionController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: tr('il_526e0087cc'),
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(15),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return tr('il_2542f6b6c4');
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Категорія
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategoryId ?? '',
                    style: const TextStyle(color: Colors.white),
                    dropdownColor: const Color(0xFF1e7d32),
                    decoration: InputDecoration(
                      labelText: tr('il_292c06f004'),
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                    ),
                    items: [
                      DropdownMenuItem<String>(
                        value: '',
                        child: Text(
                          tr('il_b11f4a82b9'),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      ...kVideoCategories.map(
                        (category) => DropdownMenuItem<String>(
                          value: category.id,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category.label(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (category.description().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  category.description(),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedCategoryId =
                            (newValue == null || newValue.isEmpty)
                                ? null
                                : newValue;
                      });
                    },
                    validator: (value) {
                      if ((_selectedCategoryId ?? '').isEmpty) {
                        return tr('il_e26788c574');
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Складність
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedDifficulty,
                    style: const TextStyle(color: Colors.white),
                    dropdownColor: const Color(0xFF1e7d32),
                    decoration: InputDecoration(
                      labelText: tr('il_be44133ed5'),
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                    ),
                    items: _difficulties.map((String difficulty) {
                      return DropdownMenuItem<String>(
                        value: difficulty,
                        child: Text(
                          difficulty,
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedDifficulty = newValue;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return tr('il_efd7187705');
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 30),
                ], // Закриваємо блок полів для звичайних відео

                // Прогрес завантаження
                if (_isUploading) ...[
                  Column(
                    children: [
                      LinearProgressIndicator(
                        value: _uploadProgress,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        bilingual(
                          'Завантаження: ${(_uploadProgress * 100).toInt()}%',
                          'Uploading: ${(_uploadProgress * 100).toInt()}%',
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ],

                // Кнопка завантаження
                Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    onPressed: _isUploading || _pickedVideo == null ? null : _uploadVideo,
                    child: Text(
                      _isUploading 
                        ? tr('il_b3a3bd2970') 
                        : widget.challengeId != null 
                          ? tr('il_905236a2ac')
                          : tr('il_70b7b4bddf'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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
    if (!_formKey.currentState!.validate() || _pickedVideo == null) {
      return;
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

      // Генеруємо унікальні імена файлів
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'video_${user.id}_$timestamp.mp4';
      
      print('🎬 Starting video upload: $fileName');

      // Завантажуємо відео (на всіх платформах через байти для веб-сумісності)
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
      
      print('✅ Video uploaded successfully: $videoUrl');

      final videoData = <String, dynamic>{
        'user_id': user.id,
        'title': _titleController.text.trim().isEmpty
            ? (widget.challengeTitle ?? tr('il_d534be829e'))
            : _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'video_url': videoUrl,
        'thumbnail_url': null,
      };

      final categoryCode = normalizeVideoCategoryValue(_selectedCategoryId ?? 'other');
      if (widget.challengeId == null) {
        final category = await client
            .from('video_categories')
            .select('id')
            .eq('code', categoryCode)
            .maybeSingle();
        final difficulty = await client
            .from('video_difficulties')
            .select('id')
            .eq('code', (_selectedDifficulty ?? '').toLowerCase())
            .maybeSingle();
        if (category != null) {
          videoData['category_id'] = category['id'];
        }
        if (difficulty != null) {
          videoData['difficulty_id'] = difficulty['id'];
        }
      }

      final videoDoc = await client.from('videos').insert(videoData).select('id').single();
      final videoId = (videoDoc['id'] ?? '').toString();

      print('✅ Video document created: $videoId');

      // Якщо це відео для челенджу
      if (widget.challengeId != null) {
        await _submitVideoToChallenge(videoId, videoUrl);
      }

      // Генеруємо thumbnail в фоновому режимі
      _generateThumbnailInBackground(videoId, videoUrl, user.id);

      // Показуємо успішне повідомлення
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_8e1f1900d9')),
            backgroundColor: const Color(0xFF4caf50),
          ),
        );

        // Повертаємося на попередній екран
        Navigator.pop(context);
      }

    } catch (e) {
      print('❌ Error uploading video: $e');
      
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

  Future<void> _submitVideoToChallenge(String videoId, String videoUrl) async {
    try {
      final user = AppAuth.currentUser!;

      // Додаємо відео до челенджу
      await sl<ChallengesRepository>()
          .addVideoToChallenge(widget.challengeId!, user.id);
      
      await Supabase.instance.client.from('challenge_submissions').upsert({
        'challenge_id': widget.challengeId!,
        'user_id': user.id,
        'video_id': videoId,
        'video_url': videoUrl,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'thumbnail_url': null,
      });

      print('✅ Video submitted to challenge: ${widget.challengeId}');
      
    } catch (e) {
      print('❌ Error submitting to challenge: $e');
      throw e;
    }
  }

  void _generateThumbnailInBackground(String videoId, String videoUrl, String userId) {
    // Генеруємо thumbnail в фоновому режимі, не блокуючи UI
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        print('🎬 Starting background thumbnail generation for: $videoId');
        
        final thumbnailService = ThumbnailService();
        final thumbnailUrl = await thumbnailService.generateAndUploadThumbnail(
          videoUrl: videoUrl,
          videoId: videoId,
          userId: userId,
        );

        if (thumbnailUrl != null) {
          print('✅ Thumbnail generated successfully: $thumbnailUrl');
          
          // Якщо це відео для челенджу, оновлюємо submission з thumbnailUrl
          if (widget.challengeId != null) {
            try {
              await Supabase.instance.client
                  .from('challenge_submissions')
                  .update({
                'thumbnail_url': thumbnailUrl,
              })
                  .eq('challenge_id', widget.challengeId!)
                  .eq('user_id', userId);
              print('✅ Submission thumbnail updated for challenge: ${widget.challengeId}');
            } catch (e) {
              print('⚠️ Failed to update submission thumbnail: $e');
            }
          }
        } else {
          print('⚠️ Thumbnail generation failed, but video upload was successful');
        }
      } catch (e) {
        print('❌ Background thumbnail generation error: $e');
        // Не показуємо помилку користувачу, оскільки відео вже завантажено
      }
    });
  }
}