import 'package:auto_route/auto_route.dart';
import 'package:flap_app/core/profile_field_options.dart';
import 'package:flap_app/core/storage/supabase_avatar_storage.dart';
import 'package:flap_app/features/auth/domain/entities/complete_profile_submission.dart';
import 'package:flap_app/features/auth/domain/repositories/user_profile_repository.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

import 'package:flap_app/core/app_auth_context.dart';
import 'package:flap_app/core/router/app_router.dart';
import 'package:flap_app/utils/i18n.dart';
import 'package:flap_app/widgets/city_autocomplete_field.dart';

@RoutePage()
class ProfileCreationScreen extends StatefulWidget {
  final bool isEditing;

  const ProfileCreationScreen({Key? key, this.isEditing = false})
    : super(key: key);

  @override
  _ProfileCreationScreenState createState() => _ProfileCreationScreenState();
}

class _ProfileCreationScreenState extends State<ProfileCreationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _loadProfileFromRepository(),
    );
  }

  Future<void> _loadProfileFromRepository() async {
    final uid = AppAuthContext.userId;
    if (uid == null) return;
    final repo = context.read<UserProfileRepository>();
    try {
      final snap = await repo.loadProfile(uid);
      if (!mounted || snap == null) return;
      setState(() {
        if (snap.name != null && snap.name!.isNotEmpty) {
          _nameController.text = snap.name!;
        }
        if (snap.surname != null && snap.surname!.isNotEmpty) {
          _surnameController.text = snap.surname!;
        }
        if (widget.isEditing) {
          _phoneController.text = snap.phone ?? '';
          _cityController.text = snap.city ?? '';
          _ageController.text = snap.age?.toString() ?? '';
          final pos = snap.position;
          _selectedPosition =
              pos != null &&
                  ProfileFieldOptions.positionStorageValues.contains(pos)
              ? pos
              : null;
          final exp = snap.experience;
          _selectedExperience =
              exp != null &&
                  ProfileFieldOptions.experienceStorageValues.contains(exp)
              ? exp
              : null;
          _existingAvatarUrl = snap.avatarUrl;
        }
      });
    } catch (_) {}
  }

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _ageController = TextEditingController();

  String? _selectedPosition;
  String? _selectedExperience;
  XFile? _pickedImage;
  String? _existingAvatarUrl;
  bool _submitting = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );

    if (picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            I18n.inline('Вибір фото скасовано', 'Photo selection cancelled'),
          ),
        ),
      );
      return;
    }

    setState(() {
      _pickedImage = picked;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(I18n.inline('Фото додано!', 'Photo added!'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final robotoTextTheme = GoogleFonts.robotoTextTheme(baseTheme.textTheme);
    final robotoFamily = GoogleFonts.roboto().fontFamily;

    return Theme(
          data: baseTheme.copyWith(
        textTheme: robotoTextTheme,
        primaryTextTheme: robotoTextTheme,
        inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
          hintStyle: GoogleFonts.roboto(color: Colors.white.withOpacity(0.7)),
          labelStyle: GoogleFonts.roboto(color: Colors.white70),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            textStyle: GoogleFonts.roboto(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            textStyle: GoogleFonts.roboto(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: GoogleFonts.roboto(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF1e7d32),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _submitting ? null : () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Text(
                    widget.isEditing
                        ? I18n.inline('Редагувати профіль', 'Edit profile')
                        : I18n.inline(
                            'Завершіть профіль',
                            'Complete your profile',
                          ),
                    style: TextStyle(
                      fontFamily: robotoFamily,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 30),

                  GestureDetector(
                    onTap: _submitting ? null : _pickImage,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(60),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: (_pickedImage != null)
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(58),
                              child: kIsWeb
                                  ? FutureBuilder<Uint8List>(
                                      future: _pickedImage!.readAsBytes(),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData) {
                                          return Image.memory(
                                            snapshot.data!,
                                            fit: BoxFit.cover,
                                          );
                                        }
                                        return const Center(
                                          child: CircularProgressIndicator(),
                                        );
                                      },
                                    )
                                  : FutureBuilder<Uint8List>(
                                      future: _pickedImage!.readAsBytes(),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData) {
                                          return Image.memory(
                                            snapshot.data!,
                                            fit: BoxFit.cover,
                                          );
                                        }
                                        return const Center(
                                          child: CircularProgressIndicator(),
                                        );
                                      },
                                    ),
                            )
                          : (_existingAvatarUrl != null &&
                                _existingAvatarUrl!.isNotEmpty)
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(58),
                              child: Image.network(
                                _existingAvatarUrl!,
                                fit: BoxFit.cover,
                                width: 120,
                                height: 120,
                                errorBuilder: (_, __, ___) => Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      I18n.inline('Додати фото', 'Add photo'),
                                      style: TextStyle(
                                        fontFamily: robotoFamily,
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 40,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  I18n.inline('Додати фото', 'Add photo'),
                                  style: TextStyle(
                                    fontFamily: robotoFamily,
                                    color: Colors.white,
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
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextFormField(
                      controller: _nameController,
                      style: TextStyle(
                        fontFamily: robotoFamily,
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText: I18n.inline('Ім\'я', 'First name'),
                        hintStyle: TextStyle(
                          fontFamily: robotoFamily,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return I18n.inline(
                            'Введіть ім\'я',
                            'Enter first name',
                          );
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextFormField(
                      controller: _surnameController,
                      style: TextStyle(
                        fontFamily: robotoFamily,
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText: I18n.inline('Прізвище', 'Last name'),
                        hintStyle: TextStyle(
                          fontFamily: robotoFamily,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return I18n.inline(
                            'Введіть прізвище',
                            'Enter last name',
                          );
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(
                        fontFamily: robotoFamily,
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText: I18n.inline('Телефон', 'Phone'),
                        hintStyle: TextStyle(
                          fontFamily: robotoFamily,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return I18n.inline(
                            'Введіть телефон',
                            'Enter phone number',
                          );
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: CityAutocompleteField(
                      controller: _cityController,
                      label: I18n.inline('Місто', 'City'),
                      requiredField: true,
                      style: TextStyle(
                        fontFamily: robotoFamily,
                        color: Colors.white,
                      ),
                      labelStyle: TextStyle(
                        fontFamily: robotoFamily,
                        color: Colors.white70,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      prefixIcon: const Icon(
                        Icons.location_city,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        fontFamily: robotoFamily,
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText: I18n.inline('Вік', 'Age'),
                        hintStyle: TextStyle(
                          fontFamily: robotoFamily,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return I18n.inline('Введіть вік', 'Enter age');
                        }
                        final n = int.tryParse(value.trim());
                        if (n == null || n < 1 || n > 120) {
                          return I18n.inline('Некоректний вік', 'Invalid age');
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _selectedPosition,
                      style: TextStyle(
                        fontFamily: robotoFamily,
                        color: Colors.white,
                      ),
                      dropdownColor: const Color(0xFF1e7d32),
                      decoration: InputDecoration(
                        hintText: I18n.inline(
                          'Позиція на полі',
                          'Field position',
                        ),
                        hintStyle: TextStyle(
                          fontFamily: robotoFamily,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                      ),
                      items: List<DropdownMenuItem<String>>.generate(
                        ProfileFieldOptions.positionStorageValues.length,
                        (i) {
                          return DropdownMenuItem<String>(
                            value: ProfileFieldOptions.positionStorageValues[i],
                            child: Text(
                              ProfileFieldOptions.positionLabels[i],
                              style: TextStyle(
                                fontFamily: robotoFamily,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedPosition = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return I18n.inline(
                            'Виберіть позицію',
                            'Select position',
                          );
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _selectedExperience,
                      style: TextStyle(
                        fontFamily: robotoFamily,
                        color: Colors.white,
                      ),
                      dropdownColor: const Color(0xFF1e7d32),
                      decoration: InputDecoration(
                        hintText: I18n.inline(
                          'Рівень досвіду',
                          'Experience level',
                        ),
                        hintStyle: TextStyle(
                          fontFamily: robotoFamily,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                      ),
                      items: List<DropdownMenuItem<String>>.generate(
                        ProfileFieldOptions.experienceStorageValues.length,
                        (i) {
                          return DropdownMenuItem<String>(
                            value:
                                ProfileFieldOptions.experienceStorageValues[i],
                            child: Text(
                              ProfileFieldOptions.experienceLabels[i],
                              style: TextStyle(
                                fontFamily: robotoFamily,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedExperience = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return I18n.inline(
                            'Виберіть досвід',
                            'Select experience',
                          );
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        backgroundColor: const Color(0xFF4caf50),
                      ),
                      onPressed: _submitting
                          ? null
                          : () async {
                              if (!_formKey.currentState!.validate()) {
                                return;
                              }
                              final uid = AppAuthContext.userId;
                              if (uid == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      I18n.inline(
                                        'Потрібно увійти в акаунт',
                                        'You need to sign in',
                                      ),
                                    ),
                                  ),
                                );
                                return;
                              }

                              setState(() => _submitting = true);

                              final age =
                                  int.parse(_ageController.text.trim());

                              String? avatarUrl;
                              if (_pickedImage != null) {
                                try {
                                  final bytes =
                                      await _pickedImage!.readAsBytes();
                                  avatarUrl = await SupabaseAvatarStorage
                                      .uploadAvatar(
                                    userId: uid,
                                    bytes: bytes,
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  setState(() => _submitting = false);
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        I18n.inline(
                                          'Не вдалося завантажити фото: $e',
                                          'Failed to upload photo: $e',
                                        ),
                                      ),
                                    ),
                                  );
                                  return;
                                }
                              }

                              final submission = CompleteProfileSubmission(
                                name: _nameController.text.trim(),
                                surname: _surnameController.text.trim(),
                                phone: _phoneController.text.trim(),
                                city: _cityController.text.trim(),
                                age: age,
                                position: _selectedPosition!,
                                experience: _selectedExperience!,
                              );

                              final profiles = context
                                  .read<UserProfileRepository>();
                              try {
                                await profiles.completeProfile(
                                  userId: uid,
                                  submission: submission,
                                  avatarUrl: avatarUrl,
                                );
                              } catch (e) {
                                if (!mounted) return;
                                setState(() => _submitting = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      I18n.inline(
                                        'Не вдалося зберегти профіль: $e',
                                        'Could not save profile: $e',
                                      ),
                                    ),
                                  ),
                                );
                                return;
                              }

                              if (!mounted) return;
                              if (avatarUrl != null &&
                                  avatarUrl.isNotEmpty) {
                                setState(() {
                                  _existingAvatarUrl = avatarUrl;
                                });
                              }

                              if (widget.isEditing) {
                                setState(() => _submitting = false);
                                Navigator.pop(context);
                              } else {
                                context.replaceRoute(VideoMainRoute());
                              }
                            },
                      child: _submitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              widget.isEditing
                                  ? I18n.inline(
                                      'Зберегти зміни',
                                      'Save changes',
                                    )
                                  : I18n.inline(
                                      'Продовжити',
                                      'Continue',
                                    ),
                              style: TextStyle(
                                fontFamily: robotoFamily,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
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
      ),
    );
  }
}
