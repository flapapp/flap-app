import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'mode_selection_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../utils/i18n.dart';

class ProfileCreationScreen extends StatefulWidget {
  final bool isEditing;
  
  const ProfileCreationScreen({Key? key, this.isEditing = false}) : super(key: key);
  
  @override
  _ProfileCreationScreenState createState() => _ProfileCreationScreenState();
}

class _ProfileCreationScreenState extends State<ProfileCreationScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          setState(() {
            _nameController.text = userData['authorName'] ?? userData['displayName'] ?? '';
            _surnameController.text = userData['surname'] ?? '';
            _cityController.text = userData['city'] ?? '';
            _ageController.text = userData['age']?.toString() ?? '';
            // Перевіряємо чи значення є в списках (using Ukrainian values for matching)
            final userPosition = userData['position'];
            final ukPositions = ['Воротар', 'Захисник', 'Півзахисник', 'Нападник'];
            _selectedPosition = ukPositions.contains(userPosition) ? userPosition : null;
            final userExperience = userData['experience'];
            final ukExperiences = ['Початківець', 'Любитель', 'Напівпрофесіонал', 'Професіонал'];
            _selectedExperience = ukExperiences.contains(userExperience) ? userExperience : null;
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _cityController = TextEditingController();
  final _ageController = TextEditingController();

  String? _selectedPosition;
  String? _selectedExperience;
  File? _imageFile;
  XFile? _pickedImage;

  List<String> get _positions => [
    I18n.inline('Воротар', 'Goalkeeper'),
    I18n.inline('Захисник', 'Defender'),
    I18n.inline('Півзахисник', 'Midfielder'),
    I18n.inline('Нападник', 'Forward'),
  ];

  List<String> get _experiences => [
    I18n.inline('Початківець', 'Beginner'),
    I18n.inline('Любитель', 'Amateur'),
    I18n.inline('Напівпрофесіонал', 'Semi-professional'),
    I18n.inline('Професіонал', 'Professional'),
  ];

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );

    if (picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.inline('Вибір фото скасовано', 'Photo selection cancelled'))),
      );
      return;
    }

    setState(() {
      _pickedImage = picked;
      if (!kIsWeb) {
        _imageFile = File(picked.path);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(I18n.inline('Фото додано!', 'Photo added!'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1e7d32),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Text(
                  widget.isEditing ? I18n.inline('Редагувати профіль', 'Edit profile') : I18n.inline('Створити профіль', 'Create profile'),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 30),

                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(60),
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                    ),
                    child: (_pickedImage != null)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(58),
                            child: kIsWeb
                                ? Image.network(_pickedImage!.path, fit: BoxFit.cover)
                                : Image.file(File(_pickedImage!.path), fit: BoxFit.cover),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.camera_alt, color: Colors.white, size: 40),
                              const SizedBox(height: 8),
                              Text(I18n.inline('Додати фото', 'Add photo'), style: const TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                  ),
                ),
                SizedBox(height: 30),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: TextFormField(
                    controller: _nameController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: I18n.inline('Ім\'я', 'First name'),
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return I18n.inline('Введіть ім\'я', 'Enter first name');
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(height: 20),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: TextFormField(
                    controller: _surnameController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: I18n.inline('Прізвище', 'Last name'),
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return I18n.inline('Введіть прізвище', 'Enter last name');
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(height: 20),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedPosition,
                    style: TextStyle(color: Colors.white),
                    dropdownColor: Color(0xFF1e7d32),
                    decoration: InputDecoration(
                      hintText: I18n.inline('Позиція', 'Position'),
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                    items: _positions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final position = entry.value;
                      // Store Ukrainian values (for consistency with database)
                      final ukValues = ['Воротар', 'Захисник', 'Півзахисник', 'Нападник'];
                      return DropdownMenuItem<String>(
                        value: ukValues[index],
                        child: Text(
                          position,
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedPosition = newValue;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return I18n.inline('Виберіть позицію', 'Select position');
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(height: 20),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: TextFormField(
                    controller: _cityController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: I18n.inline('Місто', 'City'),
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return I18n.inline('Введіть місто', 'Enter city');
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(height: 20),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: I18n.inline('Вік', 'Age'),
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return I18n.inline('Введіть вік', 'Enter age');
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(height: 20),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedExperience,
                    style: TextStyle(color: Colors.white),
                    dropdownColor: Color(0xFF1e7d32),
                    decoration: InputDecoration(
                      hintText: I18n.inline('Досвід', 'Experience'),
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    ),
                    items: _experiences.asMap().entries.map((entry) {
                      final index = entry.key;
                      final experience = entry.value;
                      // Store Ukrainian values (for consistency with database)
                      final ukValues = ['Початківець', 'Любитель', 'Напівпрофесіонал', 'Професіонал'];
                      return DropdownMenuItem<String>(
                        value: ukValues[index],
                        child: Text(
                          experience,
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedExperience = newValue;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return I18n.inline('Виберіть досвід', 'Select experience');
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(height: 30),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          side: BorderSide(color: Colors.white.withOpacity(0.5), width: 2),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          I18n.inline('Скасувати', 'Cancel'),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          backgroundColor: Color(0xFF4caf50),
                        ),
                        onPressed: () async {
  if (_formKey.currentState!.validate()) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.inline('Потрібно увійти в акаунт', 'You need to sign in'))),
      );
      return;
    }

// 1) Завантаження аватара
String? avatarUrl;
if (_pickedImage != null) {
  try {
    print('Starting image upload for user: $uid');
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('avatars/$uid/avatar.jpg');
    if (kIsWeb) {
      print('Uploading image for web platform');
      final bytes = await _pickedImage!.readAsBytes();
      final snap = await storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      avatarUrl = await snap.ref.getDownloadURL();
      print('Web upload successful. URL: $avatarUrl');
    } else {
      print('Uploading image for mobile platform');
      final file = File(_pickedImage!.path);
      final snap = await storageRef.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      avatarUrl = await snap.ref.getDownloadURL();
      print('Mobile upload successful. URL: $avatarUrl');
    }
    
    // Перевіряємо, чи URL дійсний
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      print('Avatar URL is valid: $avatarUrl');
    } else {
      print('Avatar URL is null or empty after upload');
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(I18n.inline('Не вдалося завантажити фото: $e', 'Failed to upload photo: $e'))),
    );
  }
}

// 2) Збереження профілю
        final fullName = '${_nameController.text.trim()} ${_surnameController.text.trim()}'.trim();
        final updateData = {
          'firstName': _nameController.text.trim(),
          'lastName': _surnameController.text.trim(),
          'authorName': fullName,
          'displayName': fullName,
          'city': _cityController.text.trim(),
          'age': int.tryParse(_ageController.text.trim()),
          'position': _selectedPosition,
          'experience': _selectedExperience,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Не перезаписуємо avatarUrl на null, якщо не вибрано нове фото
        if (avatarUrl != null && avatarUrl.isNotEmpty) {
          updateData['avatarUrl'] = avatarUrl;
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set(updateData, SetOptions(merge: true));

    // 3) Додамо 3-4 друзів автоматично (з існуючих користувачів)
    try {
      final existing = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, isNotEqualTo: uid)
          .limit(4)
          .get();
      final friendIds = existing.docs.map((d) => d.id).toList();
      if (friendIds.isNotEmpty) {
        final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
        await userRef.set({
          'friends': FieldValue.arrayUnion(friendIds),
        }, SetOptions(merge: true));
        for (final fid in friendIds) {
          final fRef = FirebaseFirestore.instance.collection('users').doc(fid);
          await fRef.set({
            'friends': FieldValue.arrayUnion([uid]),
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      // пропускаємо помилку, щоб не блокувати онбординг
    }

    // 4) Перехід
    if (widget.isEditing) {
      Navigator.pop(context); // Повертаємось на попередній екран
    } else {
      Navigator.pushReplacementNamed(context, '/mode');
    }
  }
},
                        child: Text(
                          widget.isEditing ? I18n.inline('Зберегти зміни', 'Save changes') : I18n.inline('Створити профіль', 'Create profile'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}