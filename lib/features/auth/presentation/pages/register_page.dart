import 'dart:typed_data';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/progress/progress_status.dart';
import '../../../../router/app_router.dart';
import '../../../../utils/i18n.dart';
import '../../../../widgets/city_autocomplete_field.dart';
import '../../domain/entities/register_request.dart';
import '../bloc/auth_bloc.dart';

String _registrationErrorMessage(Failure failure) {
  return failure.when(
    cache: () => I18n.inline('Помилка реєстрації', 'Registration error'),
    network: (m) => m ?? I18n.inline('Помилка реєстрації', 'Registration error'),
    unexpected: (m) =>
        m ?? I18n.inline('Помилка реєстрації', 'Registration error'),
    auth: (code, message) =>
        message ?? I18n.inline('Помилка реєстрації', 'Registration error'),
  );
}

@RoutePage()
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthBloc>().add(const AuthEvent.registrationFormOpened());
    });
  }

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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            I18n.inline(
              'Помилка вибору фото: $e',
              'Error selecting photo: $e',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _submit(BuildContext blocContext) async {
    if (!_formKey.currentState!.validate()) return;
    List<int>? avatarBytes;
    if (_pickedImage != null) {
      avatarBytes = await _pickedImage!.readAsBytes();
    }
    if (!mounted) return;
    final request = RegisterRequest(
      name: _nameController.text.trim(),
      surname: _surnameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text.trim(),
      city: _cityController.text.trim(),
      age: int.tryParse(_ageController.text.trim()) ?? 18,
      position: _selectedPosition ?? I18n.inline('Універсал', 'Universal'),
      experience:
          _selectedExperience ?? I18n.inline('Початківець', 'Beginner'),
      avatarBytes: avatarBytes,
    );
    if (!mounted) return;
    if (!blocContext.mounted) return;
    blocContext.read<AuthBloc>().add(
          AuthEvent.registrationRequested(request),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (p, c) =>
          (p.registrationProgress != c.registrationProgress &&
              c.registrationProgress == ProgressStatus.success) ||
          (p.registrationProgress != c.registrationProgress &&
              c.registrationProgress == ProgressStatus.failure),
      listener: (context, state) {
        if (state.registrationProgress == ProgressStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                I18n.inline(
                  '🎉 Вітаємо! Ви отримали 2 тижні Champions League преміум!',
                  '🎉 Congratulations! You received 2 weeks of Champions League premium!',
                ),
              ),
              duration: const Duration(seconds: 3),
              backgroundColor: const Color(0xFF4caf50),
            ),
          );
          context.router.replace(const ModeSelectionRoute());
        } else if (state.registrationProgress == ProgressStatus.failure &&
            state.registrationFailure != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _registrationErrorMessage(state.registrationFailure!),
              ),
            ),
          );
        }
      },
      builder: (blocContext, state) {
        final loading =
            state.registrationProgress == ProgressStatus.loading;
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
                child: GestureDetector(
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
                                onPressed: loading
                                    ? null
                                    : () => context.router.maybePop(),
                                icon: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  I18n.t('back'),
                                  style: const TextStyle(color: Colors.white),
                                ),
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
                              I18n.inline(
                                'Приєднуйтесь до футбольної спільноти',
                                'Join the football community',
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.8),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 30),
                            GestureDetector(
                              onTap: loading ? null : () => _pickImage(),
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(60),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 3,
                                  ),
                                ),
                                child: _pickedImage != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(60),
                                        child: FutureBuilder<Uint8List>(
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_a_photo,
                                            size: 40,
                                            color:
                                                Colors.white.withOpacity(0.7),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            I18n.inline(
                                              'Додати фото',
                                              'Add photo',
                                            ),
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withOpacity(0.7),
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
                                  width: 2,
                                ),
                              ),
                              child: TextFormField(
                                controller: _nameController,
                                enabled: !loading,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: I18n.inline('Ім\'я', 'Name'),
                                  labelStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(15),
                                ),
                                validator: (value) => (value == null ||
                                        value.isEmpty)
                                    ? I18n.inline(
                                        'Введіть ваше ім\'я',
                                        'Enter your name',
                                      )
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
                                  width: 2,
                                ),
                              ),
                              child: TextFormField(
                                controller: _emailController,
                                enabled: !loading,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  labelStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                  ),
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
                                  width: 2,
                                ),
                              ),
                              child: TextFormField(
                                controller: _phoneController,
                                enabled: !loading,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: I18n.inline('Телефон', 'Phone'),
                                  hintText:
                                      I18n.inline('Необовʼязково', 'Optional'),
                                  labelStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                  ),
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
                                  width: 2,
                                ),
                              ),
                              child: TextFormField(
                                controller: _surnameController,
                                enabled: !loading,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText:
                                      I18n.inline('Прізвище', 'Surname'),
                                  labelStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(15),
                                ),
                                validator: (value) => (value == null ||
                                        value.isEmpty)
                                    ? I18n.inline(
                                        'Введіть ваше прізвище',
                                        'Enter your surname',
                                      )
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
                                  width: 2,
                                ),
                              ),
                              child: CityAutocompleteField(
                                controller: _cityController,
                                label: I18n.t('city'),
                                requiredField: true,
                                style: const TextStyle(color: Colors.white),
                                labelStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
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
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: TextFormField(
                                controller: _ageController,
                                enabled: !loading,
                                style: const TextStyle(color: Colors.white),
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: I18n.inline('Вік', 'Age'),
                                  labelStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(15),
                                ),
                                validator: (value) => (value == null ||
                                        value.isEmpty)
                                    ? I18n.inline(
                                        'Введіть ваш вік',
                                        'Enter your age',
                                      )
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
                                  width: 2,
                                ),
                              ),
                              child: DropdownButtonFormField<String>(
                                value: _selectedPosition,
                                style: const TextStyle(color: Colors.white),
                                dropdownColor: const Color(0xFF1e7d32),
                                decoration: InputDecoration(
                                  labelText: I18n.inline(
                                    'Позиція на полі',
                                    'Position on field',
                                  ),
                                  labelStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(15),
                                ),
                                items: _positions.map((String position) {
                                  return DropdownMenuItem<String>(
                                    value: position,
                                    child: Text(
                                      position,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: loading
                                    ? null
                                    : (String? newValue) {
                                        setState(() {
                                          _selectedPosition = newValue;
                                        });
                                      },
                                validator: (value) => value == null
                                    ? I18n.inline(
                                        'Оберіть позицію',
                                        'Select position',
                                      )
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
                                  width: 2,
                                ),
                              ),
                              child: DropdownButtonFormField<String>(
                                value: _selectedExperience,
                                style: const TextStyle(color: Colors.white),
                                dropdownColor: const Color(0xFF1e7d32),
                                decoration: InputDecoration(
                                  labelText: I18n.inline(
                                    'Рівень досвіду',
                                    'Experience level',
                                  ),
                                  labelStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(15),
                                ),
                                items: _experiences.map((String experience) {
                                  return DropdownMenuItem<String>(
                                    value: experience,
                                    child: Text(
                                      experience,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: loading
                                    ? null
                                    : (String? newValue) {
                                        setState(() {
                                          _selectedExperience = newValue;
                                        });
                                      },
                                validator: (value) => value == null
                                    ? I18n.inline(
                                        'Оберіть рівень досвіду',
                                        'Select experience level',
                                      )
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
                                  width: 2,
                                ),
                              ),
                              child: TextFormField(
                                controller: _passwordController,
                                enabled: !loading,
                                obscureText: true,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: I18n.t('password'),
                                  labelStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                  ),
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
                                      'Password must be at least 6 characters',
                                    );
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
                                    Color(0xFF66bb6a),
                                  ],
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
                                onPressed: loading
                                    ? null
                                    : () => _submit(blocContext),
                                child: loading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                    : Text(
                                        I18n.inline(
                                          'Створити профіль',
                                          'Create profile',
                                        ),
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
                    ],
                  ),
                ),
              ),
            ),
          );
        },
    );
  }
}
