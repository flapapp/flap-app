import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart';
import 'package:flap_app/app_locale_access.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/progress/progress_status.dart';
import '../../../../router/app_router.dart';
import '../../../../widgets/city_autocomplete_field.dart';
import '../../domain/entities/register_request.dart';
import '../bloc/auth_bloc.dart';

String _registrationErrorMessage(Failure failure) {
  return failure.when(
    cache: () => tr('il_789c156110'),
    network: (m) => m ?? tr('il_789c156110'),
    unexpected: (m) =>
        m ?? tr('il_789c156110'),
    auth: (code, message) =>
        message ?? tr('il_789c156110'),
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
        tr('il_f2d20c7ee1'),
        tr('il_157ddc59b5'),
        tr('il_d332e47845'),
        tr('il_f1c65e1481'),
        tr('il_b23b6b4d06'),
      ];

  List<String> get _experiences => [
        tr('il_c865ebb305'),
        tr('il_8cc398e1bf'),
        tr('il_2506204d5d'),
        tr('il_19c73a5cdf'),
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
            bilingual(
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
      position: _selectedPosition ?? tr('il_b23b6b4d06'),
      experience:
          _selectedExperience ?? tr('il_c865ebb305'),
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
                tr('il_11506dbdb4'),
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
                                  tr('back'),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              tr('register'),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              tr('il_5f00fe3f37'),
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
                                            tr('il_c0660be883'),
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
                                  labelText: tr('il_dcd1d5223f'),
                                  labelStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(15),
                                ),
                                validator: (value) => (value == null ||
                                        value.isEmpty)
                                    ? tr('il_0421de1204')
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
                                    ? tr('enter_email')
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
                                  labelText: tr('il_63dceb8800'),
                                  hintText:
                                      tr('il_59be71333c'),
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
                                      tr('il_f762da05f4'),
                                  labelStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(15),
                                ),
                                validator: (value) => (value == null ||
                                        value.isEmpty)
                                    ? tr('il_a865381880')
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
                                label: tr('city'),
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
                                  labelText: tr('il_39b7370f30'),
                                  labelStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(15),
                                ),
                                validator: (value) => (value == null ||
                                        value.isEmpty)
                                    ? tr('il_3d7566fac9')
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
                                  labelText: tr('il_fe3ef9b3f4'),
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
                                    ? tr('il_b48d31fb5a')
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
                                  labelText: tr('il_71293dadc2'),
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
                                    ? tr('il_146b18ba66')
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
                                  labelText: tr('password'),
                                  labelStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(15),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return tr('enter_password');
                                  }
                                  if (value.length < 6) {
                                    return tr('il_2005290ddd');
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
                                        tr('il_61d30d997d'),
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
