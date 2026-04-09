import 'dart:typed_data';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/router/app_router.dart';
import '../../../../utils/i18n.dart';
import '../../../../widgets/city_autocomplete_field.dart';
import '../../domain/entities/new_user_profile.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

@RoutePage()
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
  XFile? _pickedImage;
  final ImagePicker _picker = ImagePicker();

  List<String> get _positions => [
        I18n.inline('Воротар', 'Goalkeeper'),
        I18n.inline('Захисник', 'Defender'),
        I18n.inline('Півзахисник', 'Midfielder'),
        I18n.inline('Нападник', 'Forward'),
        I18n.inline('Універсал', 'Universal'),
      ];

  List<String> get _experiences => [
        I18n.inline('Початківець', 'Beginner'),
        I18n.inline('Аматор', 'Amateur'),
        I18n.inline('Досвідчений', 'Experienced'),
        I18n.inline('Професіонал', 'Professional'),
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
          _pickedImage = image;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(I18n.inline(
                'Помилка вибору фото: $e', 'Error selecting photo: $e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final focused = FocusScope.of(context);
        if (!focused.hasPrimaryFocus) {
          focused.unfocus();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1e7d32),
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: BlocConsumer<AuthBloc, AuthState>(
            listenWhen: (previous, current) =>
                current is AuthCredentialsRejected ||
                current is AuthRegistrationCompleted,
            listener: (context, state) {
              if (state is AuthCredentialsRejected) {
                final text = state.code == 'email-already-in-use'
                    ? I18n.inline(
                        'Ця електронна адреса вже використовується. Увійдіть або оберіть іншу.',
                        'This email is already in use. Sign in or choose another one.',
                      )
                    : (state.message != null && state.message!.isNotEmpty
                        ? state.message!
                        : I18n.inline(
                            'Помилка реєстрації',
                            'Registration error',
                          ));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(text)),
                );
              }
              if (state is AuthRegistrationCompleted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(I18n.inline(
                      'Реєстрацію завершено. Підтвердіть email і увійдіть у свій акаунт.',
                      'Registration complete. Confirm your email and sign in to your account.',
                    )),
                    duration: const Duration(seconds: 3),
                    backgroundColor: const Color(0xFF4caf50),
                  ),
                );
                context.replaceRoute(LoginRoute());
              }
            },
            builder: (context, state) {
              final loading = state is AuthLoading;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => FocusScope.of(context).unfocus(),
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(20),
                  children: [
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.topLeft,
                            child: TextButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon:
                                  const Icon(Icons.arrow_back, color: Colors.white),
                              label: Text(I18n.t('back'),
                                  style: const TextStyle(color: Colors.white)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            I18n.t('register'),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            I18n.inline('Приєднуйтесь до футбольної спільноти',
                                'Join the football community'),
                            style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.8)),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 30),
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(60),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 3),
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
                                          : FutureBuilder<Uint8List>(
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
                                            ),
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
                                          I18n.inline('Додати фото', 'Add photo'),
                                          style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.7),
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
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 2),
                            ),
                            child: TextFormField(
                              controller: _nameController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: I18n.inline('Ім\'я', 'Name'),
                                labelStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.7)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(15),
                              ),
                              validator: (value) => (value == null ||
                                      value.isEmpty)
                                  ? I18n.inline(
                                      'Введіть ваше ім\'я', 'Enter your name')
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 2),
                            ),
                            child: TextFormField(
                              controller: _emailController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Email',
                                labelStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.7)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(15),
                              ),
                              validator: (value) => (value == null ||
                                      value.isEmpty)
                                  ? I18n.t('enter_email')
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 2),
                            ),
                            child: TextFormField(
                              controller: _phoneController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: I18n.inline('Телефон', 'Phone'),
                                hintText:
                                    I18n.inline('Необовʼязково', 'Optional'),
                                labelStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.7)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(15),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 2),
                            ),
                            child: TextFormField(
                              controller: _surnameController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText:
                                    I18n.inline('Прізвище', 'Surname'),
                                labelStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.7)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(15),
                              ),
                              validator: (value) => (value == null ||
                                      value.isEmpty)
                                  ? I18n.inline('Введіть ваше прізвище',
                                      'Enter your surname')
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 2),
                            ),
                            child: CityAutocompleteField(
                              controller: _cityController,
                              label: I18n.t('city'),
                              requiredField: true,
                              style: const TextStyle(color: Colors.white),
                              labelStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.7)),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              prefixIcon: const Icon(Icons.location_city,
                                  color: Colors.white70),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 2),
                            ),
                            child: TextFormField(
                              controller: _ageController,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: I18n.inline('Вік', 'Age'),
                                labelStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.7)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(15),
                              ),
                              validator: (value) => (value == null ||
                                      value.isEmpty)
                                  ? I18n.inline(
                                      'Введіть ваш вік', 'Enter your age')
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 2),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _selectedPosition,
                              style: const TextStyle(color: Colors.white),
                              dropdownColor: const Color(0xFF1e7d32),
                              decoration: InputDecoration(
                                labelText: I18n.inline(
                                    'Позиція на полі', 'Position on field'),
                                labelStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.7)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(15),
                              ),
                              items: _positions.map((String position) {
                                return DropdownMenuItem<String>(
                                  value: position,
                                  child: Text(position,
                                      style:
                                          const TextStyle(color: Colors.white)),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedPosition = newValue;
                                });
                              },
                              validator: (value) => value == null
                                  ? I18n.inline(
                                      'Оберіть позицію', 'Select position')
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 2),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _selectedExperience,
                              style: const TextStyle(color: Colors.white),
                              dropdownColor: const Color(0xFF1e7d32),
                              decoration: InputDecoration(
                                labelText: I18n.inline(
                                    'Рівень досвіду', 'Experience level'),
                                labelStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.7)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(15),
                              ),
                              items: _experiences.map((String experience) {
                                return DropdownMenuItem<String>(
                                  value: experience,
                                  child: Text(experience,
                                      style:
                                          const TextStyle(color: Colors.white)),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedExperience = newValue;
                                });
                              },
                              validator: (value) => value == null
                                  ? I18n.inline('Оберіть рівень досвіду',
                                      'Select experience level')
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 2),
                            ),
                            child: TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: I18n.t('password'),
                                labelStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.7)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(15),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return I18n.t('enter_password');
                                }
                                if (value.length < 6) {
                                  return I18n.inline(
                                      'Пароль має бути не менше 6 символів',
                                      'Password must be at least 6 characters');
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 30),
                          Container(
                            width: double.infinity,
                            height: 55,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4caf50),
                                    Color(0xFF66bb6a)
                                  ]),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25)),
                              ),
                              onPressed: loading
                                  ? null
                                  : () {
                                      if (!_formKey.currentState!.validate()) {
                                        return;
                                      }
                                      context.read<AuthBloc>().add(
                                            AuthRegisterRequested(
                                              email: _emailController.text
                                                  .trim(),
                                              password: _passwordController
                                                  .text
                                                  .trim(),
                                              profile: NewUserProfile(
                                                name: _nameController.text
                                                    .trim(),
                                                surname: _surnameController.text
                                                    .trim(),
                                                email: _emailController.text
                                                    .trim(),
                                                phone: _phoneController.text
                                                    .trim(),
                                                city: _cityController.text
                                                    .trim(),
                                                age: int.tryParse(_ageController
                                                            .text
                                                            .trim()) ??
                                                        18,
                                                position: _selectedPosition ??
                                                    I18n.inline('Універсал',
                                                        'Universal'),
                                                experience:
                                                    _selectedExperience ??
                                                        I18n.inline(
                                                            'Початківець',
                                                            'Beginner'),
                                              ),
                                            ),
                                          );
                                    },
                              child: loading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white)
                                  : Text(
                                      I18n.inline(
                                          'Створити профіль', 'Create profile'),
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
