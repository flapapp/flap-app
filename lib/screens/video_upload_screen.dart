import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import '../services/challenge_service.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  
  String? _selectedCategory;
  String? _selectedDifficulty;
  File? _videoFile;
  XFile? _pickedVideo;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  final List<String> _categories = [
    'Техніка',
    'Фізика',
    'Тактика',
    'Командна гра',
    'Фрістайл',
    'Інше',
  ];

  final List<String> _difficulties = [
    'Легкий',
    'Середній',
    'Складний',
    'Експерт',
  ];

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5), // Максимум 5 хвилин
    );

    if (picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Вибір відео скасовано')),
      );
      return;
    }

    setState(() {
      _pickedVideo = picked;
      if (!kIsWeb) {
        _videoFile = File(picked.path);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Відео додано!')),
    );
  }

  Future<void> _uploadVideo() async {
    // Для челенджів не потрібна валідація форми
    bool isValidForUpload = widget.challengeId != null 
        ? _pickedVideo != null 
        : (_formKey.currentState!.validate() && _pickedVideo != null);
        
    if (isValidForUpload) {
      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
      });

      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) {
          throw Exception('Користувач не авторизований');
        }

        // Створюємо унікальну назву файлу
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'video_$timestamp.mp4';
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('videos/$uid/$fileName');

        String? videoUrl;
        
        if (kIsWeb) {
          final bytes = await _pickedVideo!.readAsBytes();
          final uploadTask = storageRef.putData(
            bytes,
            SettableMetadata(contentType: 'video/mp4'),
          );
          
          uploadTask.snapshotEvents.listen((snapshot) {
            setState(() {
              _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
            });
          });
          
          final snap = await uploadTask;
          videoUrl = await snap.ref.getDownloadURL();
        } else {
          final file = File(_pickedVideo!.path);
          final uploadTask = storageRef.putFile(
            file,
            SettableMetadata(contentType: 'video/mp4'),
          );
          
          uploadTask.snapshotEvents.listen((snapshot) {
            setState(() {
              _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
            });
          });
          
          final snap = await uploadTask;
          videoUrl = await snap.ref.getDownloadURL();
        }

         // Отримуємо дані користувача
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final userData = userDoc.data();
        final authorName = userData?['displayName'] ?? 'Невідомий';
        final city = userData?['city'] ?? 'Невідомо';

        if (widget.challengeId == null) {
          // Зберігаємо метадані звичайного відео в колекції videos
          await FirebaseFirestore.instance.collection('videos').add({
            'userId': uid,
            'authorName': authorName,
            'city': city,
            'title': _titleController.text.trim(),
            'description': _descriptionController.text.trim(),
            'category': _selectedCategory,
            'difficulty': _selectedDifficulty,
            'videoUrl': videoUrl,
            'thumbnailUrl': null, // Пізніше додамо
            'duration': 0, // Пізніше додамо
            'views': 0,
            'likes': 0,
            'dislikes': 0,
            'rating': 0.0,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Це відео для челенджу: записуємо тільки в submissions під челенджем
          final challengeId = widget.challengeId!;
          final submissionRef = FirebaseFirestore.instance
              .collection('challenges')
              .doc(challengeId)
              .collection('submissions')
              .doc(uid);
          await submissionRef.set({
            'userId': uid,
            'authorName': authorName,
            'title': _titleController.text.trim(),
            'description': _descriptionController.text.trim(),
            'videoUrl': videoUrl,
            'createdAt': FieldValue.serverTimestamp(),
            'rating': 0.0,
            'votes': 0,
          });

          // Позначаємо, що користувач подав відео на челендж
          try {
            final challengeService = ChallengeService();
            await challengeService.addVideoToChallenge(challengeId, uid);
          } catch (e) {
            print('Error updating challenge submission: $e');
          }
        }

        // Очищаємо форму
        _titleController.clear();
        _descriptionController.clear();
        setState(() {
          _selectedCategory = null;
          _selectedDifficulty = null;
          _pickedVideo = null;
          _videoFile = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.challengeId != null 
                ? 'Відео успішно завантажено для челенджу!'
                : 'Відео успішно завантажено!'
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Повертаємося назад
        Navigator.pop(context);

      } catch (e) {
        print('Error uploading video: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Помилка завантаження: $e')),
        );
      } finally {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
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
            ? 'Відео для челенджу: ${widget.challengeTitle}'
            : 'Завантажити відео',
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
                    ? 'Подай відео для челенджу!'
                    : 'Покажи свої навички!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.challengeId != null
                    ? 'Завантаж відео та брати участь у челенджі'
                    : 'Завантаж відео та отримай оцінки від спільноти',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 30),

                // Вибір відео
                GestureDetector(
                  onTap: _isUploading ? null : _pickVideo,
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
                                'Відео вибрано!',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Натисніть ще раз, щоб змінити',
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
                              const Text(
                                'Натисніть, щоб вибрати відео',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'MP4, максимум 5 хвилин',
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
                      labelText: 'Назва відео',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(15),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Введіть назву відео';
                      }
                      if (value.length < 3) {
                        return 'Назва має бути не менше 3 символів';
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
                      labelText: 'Опис',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(15),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Введіть опис відео';
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
                    value: _selectedCategory,
                    style: const TextStyle(color: Colors.white),
                    dropdownColor: const Color(0xFF1e7d32),
                    decoration: InputDecoration(
                      labelText: 'Категорія',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                    ),
                    items: _categories.map((String category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(
                          category,
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedCategory = newValue;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Виберіть категорію';
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
                      labelText: 'Складність',
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
                        return 'Виберіть складність';
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
                        'Завантаження: ${(_uploadProgress * 100).toInt()}%',
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
                        ? 'ЗАВАНТАЖЕННЯ...' 
                        : widget.challengeId != null 
                          ? 'ПОДАТИ ВІДЕО ДЛЯ ЧЕЛЕНДЖУ'
                          : 'ЗАВАНТАЖИТИ ВІДЕО',
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
}