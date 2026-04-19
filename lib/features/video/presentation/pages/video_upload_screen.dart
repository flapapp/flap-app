import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../../constants/video_categories.dart';
import '../../../../core/di/injection.dart';
import '../../../challenges/domain/repositories/challenges_repository.dart';
import '../../../../services/thumbnail_service.dart';
import '../../../../utils/i18n.dart';

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
    I18n.inline('Легкий', 'Easy'),
    I18n.inline('Середній', 'Medium'),
    I18n.inline('Складний', 'Hard'),
    I18n.inline('Експерт', 'Expert'),
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
          SnackBar(content: Text(I18n.inline('Вибір відео скасовано', 'Video selection cancelled'))),
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
              I18n.inline(
                'Файл занадто великий. Максимум 25 МБ.',
                'File is too large. Maximum size is 25 MB.',
              ),
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
        SnackBar(content: Text(I18n.inline('Відео додано!', 'Video added!'))),
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
            ? I18n.inline('Відео для челенджу: ${widget.challengeTitle}', 'Video for challenge: ${widget.challengeTitle}')
            : I18n.t('upload_video'),
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
                    ? I18n.inline('Подай відео для челенджу!', 'Submit video for challenge!')
                    : I18n.t('show_skills'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.challengeId != null
                    ? I18n.inline('Завантаж відео та брати участь у челенджі', 'Upload video and participate in challenge')
                    : I18n.t('upload_get_ratings'),
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
                                I18n.inline('Відео вибрано!', 'Video selected!'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                I18n.inline('Натисніть ще раз, щоб змінити', 'Tap again to change'),
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
                                I18n.inline('Натисніть, щоб вибрати відео', 'Tap to select video'),
                                style: const TextStyle(
                                  color: Colors.white,
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
                        label: Text(I18n.inline('Галерея', 'Gallery')),
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
                        label: Text(I18n.inline('Камера', 'Camera')),
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
                      labelText: I18n.inline('Назва відео', 'Video title'),
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(15),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return I18n.inline('Введіть назву відео', 'Enter video title');
                      }
                      if (value.length < 3) {
                        return I18n.inline('Назва має бути не менше 3 символів', 'Title must be at least 3 characters');
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
                      labelText: I18n.inline('Опис', 'Description'),
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
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
                      labelText: I18n.inline('Категорія', 'Category'),
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                    ),
                    items: [
                      DropdownMenuItem<String>(
                        value: '',
                        child: Text(
                          I18n.inline('Оберіть категорію', 'Select a category'),
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
                        return I18n.inline(
                            'Виберіть категорію', 'Select category');
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
                      labelText: I18n.inline('Складність', 'Difficulty'),
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
                        return I18n.inline('Виберіть складність', 'Select difficulty');
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
                        I18n.inline(
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
                        ? I18n.inline('ЗАВАНТАЖЕННЯ...', 'UPLOADING...') 
                        : widget.challengeId != null 
                          ? I18n.inline('ПОДАТИ ВІДЕО ДЛЯ ЧЕЛЕНДЖУ', 'SUBMIT VIDEO FOR CHALLENGE')
                          : I18n.inline('ЗАВАНТАЖИТИ ВІДЕО', 'UPLOAD VIDEO'),
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception(I18n.inline('Користувач не авторизований', 'User not authorized'));
      }

      final fileSize = await _pickedVideo!.length();
      if (fileSize > _maxVideoBytes) {
        throw Exception(
          I18n.inline(
            'Розмір відео перевищує 25 МБ.',
            'Video size exceeds 25 MB.',
          ),
        );
      }

      // Генеруємо унікальні імена файлів
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'video_${user.uid}_$timestamp.mp4';
      
      // Створюємо посилання на Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('videos/${user.uid}/$fileName');

      print('🎬 Starting video upload: $fileName');

      // Завантажуємо відео (на всіх платформах через байти для веб-сумісності)
      final bytes = await _pickedVideo!.readAsBytes();
      final uploadTask = storageRef.putData(bytes);

      // Відстежуємо прогрес
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (!mounted) return;
        setState(() {
          _uploadProgress = snapshot.totalBytes == 0 ? 0 : snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      // Чекаємо завершення завантаження
      final snapshot = await uploadTask;
      final videoUrl = await snapshot.ref.getDownloadURL();
      
      print('✅ Video uploaded successfully: $videoUrl');

      final videoData = <String, dynamic>{
        'userId': user.uid,
        'authorId': user.uid,
        'authorName': user.displayName ?? user.email?.split('@')[0] ?? I18n.inline('Користувач', 'User'),
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': normalizeVideoCategoryValue(_selectedCategoryId ?? 'other'),
        'difficulty': _selectedDifficulty,
        'videoUrl': videoUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
        'rating': 0.0,
        'views': 0,
        'thumbnailUrl': null,
        'thumbnailGenerated': false,
      };

      if (widget.challengeId != null) {
        videoData.addAll({
          'challengeId': widget.challengeId,
          'challengeTitle': widget.challengeTitle ?? '',
          'isChallengeVideo': true,
        });
      }

      final videoDoc = await FirebaseFirestore.instance
          .collection('videos')
          .add(videoData);

      print('✅ Video document created: ${videoDoc.id}');

      // Якщо це відео для челенджу
      if (widget.challengeId != null) {
        await _submitVideoToChallenge(videoDoc.id, videoUrl);
      }

      // Генеруємо thumbnail в фоновому режимі
      _generateThumbnailInBackground(videoDoc.id, videoUrl, user.uid);

      // Показуємо успішне повідомлення
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(I18n.inline('✅ Відео успішно завантажено!', '✅ Video uploaded successfully!')),
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
            content: Text(I18n.inline('❌ Помилка завантаження: ${e.toString()}', '❌ Upload error: ${e.toString()}')),
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
      final user = FirebaseAuth.instance.currentUser!;

      // Додаємо відео до челенджу
      await sl<ChallengesRepository>()
          .addVideoToChallenge(widget.challengeId!, user.uid);
      
      // Створюємо submission документ
      await FirebaseFirestore.instance
          .collection('challenges')
          .doc(widget.challengeId!)
          .collection('submissions')
          .doc(user.uid)
          .set({
        'userId': user.uid,
        'videoId': videoId,
        'videoUrl': videoUrl,
        'title': _titleController.text.trim(),
        'authorName': user.displayName ?? user.email?.split('@')[0] ?? I18n.inline('Користувач', 'User'),
        'createdAt': FieldValue.serverTimestamp(),
        'averageRating': 0.0,
        'voteCount': 0,
        'votes': <String, dynamic>{},
        'thumbnailUrl': null, // Буде оновлено після генерації
        'isCreatorVideo': false,
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
              await FirebaseFirestore.instance
                  .collection('challenges')
                  .doc(widget.challengeId!)
                  .collection('submissions')
                  .doc(userId)
                  .update({
                'thumbnailUrl': thumbnailUrl,
                'thumbnailGenerated': true,
              });
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