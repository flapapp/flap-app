// lib/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _cityController = TextEditingController();
  final _ageController = TextEditingController();
  
  String? _selectedPosition;
  String? _selectedExperience;
  File? _selectedImage;
  XFile? _pickedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  
  final List<String> _positions = [
    'Воротар',
    'Захисник',
    'Півзахисник',
    'Нападник',
    'Універсал',
  ];
  
  final List<String> _experiences = [
    'Початківець',
    'Аматор',
    'Досвідчений',
    'Професіонал',
  ];

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          // Для web не використовуємо File(), зберігаємо XFile
          if (kIsWeb) {
            _selectedImage = null; // Не використовуємо File для web
            _pickedImage = image;  // Зберігаємо XFile
          } else {
            _selectedImage = File(image.path);
            _pickedImage = image;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Помилка вибору фото: $e')),
      );
    }
  }

  Future<String?> _uploadAvatar(String userId) async {
    if (_pickedImage == null) return null;
    
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('avatars')
          .child(userId)
          .child('avatar.jpg');
      
      // Використовуємо XFile для всіх платформ
      final bytes = await _pickedImage!.readAsBytes();
      await ref.putData(bytes);
      
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading avatar: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1e7d32),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    label: const Text('Назад', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 10),

                const Text(
                  'Реєстрація',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Приєднуйтесь до футбольної спільноти',
                  style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                
                // Avatar selection
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(60),
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
                    ),
                    child: _pickedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(60),
                            child: kIsWeb
                                ? FutureBuilder<Uint8List>(
                                    future: _pickedImage!.readAsBytes(),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData) {
                                        return Image.memory(
                                          snapshot.data!,
                                          fit: BoxFit.cover,
                                          width: 120,
                                          height: 120,
                                        );
                                      }
                                      return const CircularProgressIndicator();
                                    },
                                  )
                                : Image.file(_selectedImage!, fit: BoxFit.cover, width: 120, height: 120),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo,
                                size: 40,
                                color: Colors.white.withOpacity(0.7),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Додати фото',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 30),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                  ),
                  child: TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Ім\'я',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(15),
                    ),
                    validator: (value) => (value == null || value.isEmpty) ? 'Введіть ваше ім\'я' : null,
                  ),
                ),
                const SizedBox(height: 20),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                  ),
                  child: TextFormField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(15),
                    ),
                    validator: (value) => (value == null || value.isEmpty) ? 'Введіть email' : null,
                  ),
                ),
                const SizedBox(height: 20),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                  ),
                  child: TextFormField(
                    controller: _phoneController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Телефон',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(15),
                    ),
                    validator: (value) => (value == null || value.isEmpty) ? 'Введіть номер телефону' : null,
                  ),
                ),
                const SizedBox(height: 20),

                // Прізвище
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                  ),
                  child: TextFormField(
                    controller: _surnameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Прізвище',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(15),
                    ),
                    validator: (value) => (value == null || value.isEmpty) ? 'Введіть ваше прізвище' : null,
                  ),
                ),
                const SizedBox(height: 20),

                // Місто
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                  ),
                  child: TextFormField(
                    controller: _cityController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Місто',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(15),
                    ),
                    validator: (value) => (value == null || value.isEmpty) ? 'Введіть ваше місто' : null,
                  ),
                ),
                const SizedBox(height: 20),

                // Вік
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                  ),
                  child: TextFormField(
                    controller: _ageController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Вік',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(15),
                    ),
                    validator: (value) => (value == null || value.isEmpty) ? 'Введіть ваш вік' : null,
                  ),
                ),
                const SizedBox(height: 20),

                // Позиція
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedPosition,
                    style: const TextStyle(color: Colors.white),
                    dropdownColor: const Color(0xFF1e7d32),
                    decoration: InputDecoration(
                      labelText: 'Позиція на полі',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(15),
                    ),
                    items: _positions.map((String position) {
                      return DropdownMenuItem<String>(
                        value: position,
                        child: Text(position, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedPosition = newValue;
                      });
                    },
                    validator: (value) => value == null ? 'Оберіть позицію' : null,
                  ),
                ),
                const SizedBox(height: 20),

                // Досвід
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedExperience,
                    style: const TextStyle(color: Colors.white),
                    dropdownColor: const Color(0xFF1e7d32),
                    decoration: InputDecoration(
                      labelText: 'Рівень досвіду',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(15),
                    ),
                    items: _experiences.map((String experience) {
                      return DropdownMenuItem<String>(
                        value: experience,
                        child: Text(experience, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedExperience = newValue;
                      });
                    },
                    validator: (value) => value == null ? 'Оберіть рівень досвіду' : null,
                  ),
                ),
                const SizedBox(height: 20),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                  ),
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Пароль',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(15),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Введіть пароль';
                      if (value.length < 6) return 'Пароль має бути не менше 6 символів';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 30),

                Container(
                  width: double.infinity,
                  height: 55,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF4caf50), Color(0xFF66bb6a)]),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        try {
                          // Створюємо користувача
                          UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                            email: _emailController.text.trim(),
                            password: _passwordController.text.trim(),
                          );
                          
                          setState(() {
                            _isLoading = true;
                          });
                          
                          // Завантажуємо аватар якщо є
                          String? avatarUrl;
                          if (_pickedImage != null) {
                            print('Uploading avatar for user: ${userCredential.user!.uid}');
                            print('Image file exists: ${_pickedImage != null}');
                            avatarUrl = await _uploadAvatar(userCredential.user!.uid);
                            print('Final Avatar URL: $avatarUrl');
                          } else {
                            print('No image selected for upload');
                          }
                          
                          // Створюємо профіль в Firestore одразу з преміум підпискою
                          final now = DateTime.now();
                          final premiumExpiry = now.add(const Duration(days: 14)); // 2 тижні преміум
                          
                          final fullName =
                              '${_nameController.text.trim()} ${_surnameController.text.trim()}'.trim();

                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(userCredential.user!.uid)
                              .set({
                            'authorName': fullName,
                            'displayName': fullName,
                            'name': _nameController.text.trim(),
                            'surname': _surnameController.text.trim(),
                            'email': _emailController.text.trim(),
                            'phone': _phoneController.text.trim(),
                            'city': _cityController.text.trim(),
                            'age': int.tryParse(_ageController.text.trim()) ?? 18,
                            'position': _selectedPosition ?? 'Універсал',
                            'experience': _selectedExperience ?? 'Початківець',
                            'avatarUrl': avatarUrl,
                            'createdAt': FieldValue.serverTimestamp(),
                            // Default ratings per spec
                            'rating': 3.0,
                            'matchRating': 3.0,
                            'videoRating': 3.0,
                            'totalMatches': 0,
                            'totalVideos': 0,
                            'ratingHistory': [],
                            'lastRatingUpdate': FieldValue.serverTimestamp(),
                            'coins': 160, // 100 базових + 60 за преміум
                            'matches': 0,
                            'goals': 0,
                            'assists': 0,
                            // Преміум підписка
                            'subscription': 'champions_league',
                            'subscriptionExpiry': Timestamp.fromDate(premiumExpiry),
                            'subscriptionActive': true,
                            'challengesCreated': 0,
                            'maxChallengesPerMonth': 999, // Необмежено для преміум
                          });
                          
                          setState(() {
                            _isLoading = false;
                          });
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🎉 Вітаємо! Ви отримали 2 тижні Champions League преміум!'),
                              duration: Duration(seconds: 3),
                              backgroundColor: Color(0xFF4caf50),
                            ),
                          );
                          Navigator.pushReplacementNamed(context, '/mode');
                        } on FirebaseAuthException catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.message ?? 'Помилка реєстрації')),
                          );
                        }
                      }
                    },
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Створити профіль',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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