import 'package:auto_route/auto_route.dart';
import 'package:flap_app/core/profile_field_options.dart';
import 'package:flap_app/features/profile/domain/entities/profile_completion_snapshot.dart';
import 'package:flap_app/features/profile/domain/entities/profile_completion_submission.dart';
import 'package:flap_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:flap_app/features/profile/presentation/bloc/profile_completion_bloc.dart';
import 'package:flap_app/features/profile/presentation/bloc/profile_completion_event.dart';
import 'package:flap_app/features/profile/presentation/bloc/profile_completion_state.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

import 'package:flap_app/core/app_auth_context.dart';
import 'package:flap_app/core/media/flap_cached_image.dart';
import 'package:flap_app/core/router/app_router.dart';
import 'package:flap_app/core/theme/flap_theme.dart';
import 'package:flap_app/core/world_location_service.dart';
import 'package:flap_app/utils/i18n.dart';
import 'package:flap_app/widgets/searchable_choice_sheet.dart';

@RoutePage()
class ProfileCreationScreen extends StatefulWidget {
  final bool isEditing;

  const ProfileCreationScreen({Key? key, this.isEditing = false})
    : super(key: key);

  @override
  _ProfileCreationScreenState createState() => _ProfileCreationScreenState();
}

class _ProfileCreationScreenState extends State<ProfileCreationScreen> {
  late final ProfileCompletionBloc _completionBloc;

  @override
  void initState() {
    super.initState();
    _completionBloc = ProfileCompletionBloc(
      repository: context.read<ProfileRepository>(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileFromRepository();
      _prefetchCountries();
    });
  }

  Future<void> _prefetchCountries() async {
    try {
      await WorldLocationService.countryNames();
      if (mounted) setState(() => _locationsReady = true);
    } catch (_) {
      if (mounted) setState(() => _locationsReady = true);
    }
  }

  Future<void> _loadProfileFromRepository() async {
    final uid = AppAuthContext.userId;
    if (uid == null) return;
    _completionBloc.add(ProfileCompletionLoadRequested(uid));
  }

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();

  DateTime? _dateOfBirth;

  String? _selectedCountry;
  bool _locationsReady = false;

  String? _selectedPosition;
  String? _selectedExperience;
  XFile? _pickedImage;
  String? _existingAvatarUrl;
  bool _submitting = false;

  void _applySnapshot(ProfileCompletionSnapshot snap) {
    setState(() {
      if (snap.name != null && snap.name!.isNotEmpty) {
        _nameController.text = snap.name!;
      }
      if (snap.surname != null && snap.surname!.isNotEmpty) {
        _surnameController.text = snap.surname!;
      }
      if (snap.dateOfBirth != null) {
        _dateOfBirth = snap.dateOfBirth;
      }
      if (snap.country != null && snap.country!.trim().isNotEmpty) {
        _selectedCountry = snap.country!.trim();
      }
      if (snap.city != null && snap.city!.trim().isNotEmpty) {
        _cityController.text = snap.city!.trim();
      }
      if (widget.isEditing) {
        _phoneController.text = snap.phone ?? '';
        final pos = snap.position;
        _selectedPosition =
            pos != null && ProfileFieldOptions.positionStorageValues.contains(pos)
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
  }

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

  String _formatDateOfBirth(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> _pickCountry() async {
    if (_submitting) return;
    if (!_locationsReady) {
      try {
        await WorldLocationService.countryNames();
        if (mounted) setState(() => _locationsReady = true);
      } catch (_) {}
    }
    final names = await WorldLocationService.countryNames();
    if (!mounted) return;
    final picked = await showSearchableChoiceSheet(
      context: context,
      title: I18n.inline('Країна', 'Country'),
      items: names,
      selected: _selectedCountry,
    );
    if (picked != null) {
      setState(() {
        _selectedCountry = picked;
        _cityController.clear();
      });
    }
  }

  Future<void> _pickCity() async {
    if (_submitting) return;
    final country = _selectedCountry?.trim();
    if (country == null || country.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            I18n.inline('Спочатку оберіть країну', 'Select a country first'),
          ),
        ),
      );
      return;
    }
    final cities = await WorldLocationService.cityNamesForCountry(country);
    if (!mounted) return;
    if (cities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            I18n.inline(
              'Немає міст у каталозі для цієї країни',
              'No cities found in the catalog for this country',
            ),
          ),
        ),
      );
      return;
    }
    final current = _cityController.text.trim();
    final picked = await showSearchableChoiceSheet(
      context: context,
      title: I18n.inline('Місто', 'City'),
      items: cities,
      selected: current.isEmpty ? null : current,
    );
    if (picked != null && mounted) {
      setState(() => _cityController.text = picked);
    }
  }

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 120, 1, 1);
    final last = DateTime(now.year, now.month, now.day);
    final initial = _dateOfBirth ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first)
          ? first
          : (initial.isAfter(last) ? last : initial),
      firstDate: first,
      lastDate: last,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4caf50),
              onPrimary: Colors.white,
              surface: Color(0xFF1e7d32),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _dateOfBirth = DateTime.utc(picked.year, picked.month, picked.day);
      });
    }
  }

  @override
  void dispose() {
    _completionBloc.close();
    _nameController.dispose();
    _surnameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.isEditing
        ? I18n.inline(
            'Оновіть свої дані профілю',
            'Update your profile details',
          )
        : I18n.inline(
            'Заповніть особисті дані, щоб завершити профіль',
            'Fill in your details to complete your profile',
          );

    return BlocProvider.value(
      value: _completionBloc,
      child: BlocListener<ProfileCompletionBloc, ProfileCompletionState>(
        listener: (context, state) {
          if (_submitting != state.submitting && mounted) {
            setState(() => _submitting = state.submitting);
          }
          if (state.snapshot != null) {
            _applySnapshot(state.snapshot!);
          }
          if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
            _completionBloc.add(const ProfileCompletionTransientCleared());
          }
          if (state.infoMessage != null && state.infoMessage!.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.infoMessage!)),
            );
            _completionBloc.add(const ProfileCompletionTransientCleared());
          }
          if (state.submitSucceeded) {
            if (state.avatarUrl != null && state.avatarUrl!.isNotEmpty) {
              setState(() => _existingAvatarUrl = state.avatarUrl);
            }
            if (widget.isEditing) {
              Navigator.pop(context);
            } else {
              context.replaceRoute(
                MainShellRoute(
                  children: [HomeHubRoute()],
                ),
              );
            }
            _completionBloc.add(const ProfileCompletionTransientCleared());
          }
        },
        child: WillPopScope(
          onWillPop: () async {
            await SystemNavigator.pop();
            return false;
          },
          child: Scaffold(
        backgroundColor: FlapTheme.pitch,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusScope.of(context).unfocus(),
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(20),
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        widget.isEditing
                            ? I18n.inline('Редагувати профіль', 'Edit profile')
                            : I18n.inline('Завершіть профіль', 'Complete profile'),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      GestureDetector(
                        onTap: _submitting ? null : _pickImage,
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
                          child: (_pickedImage != null)
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
                                      borderRadius: BorderRadius.circular(60),
                                      child: FlapCachedImage(
                                        imageUrl: _existingAvatarUrl!,
                                        width: 120,
                                        height: 120,
                                        fit: BoxFit.cover,
                                        memCacheWidth: 240,
                                        errorWidget: (_, __, ___) => Column(
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
                                                color: Colors.white.withOpacity(0.7),
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
                                        Icon(
                                          Icons.add_a_photo,
                                          size: 40,
                                          color: Colors.white.withOpacity(0.7),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          I18n.inline('Додати фото', 'Add photo'),
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
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: TextFormField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: I18n.inline('Ім\'я', 'First name'),
                            labelStyle: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(15),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return I18n.inline('Введіть ім\'я', 'Enter first name');
                            }
                            return null;
                          },
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
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: I18n.inline('Прізвище', 'Last name'),
                            labelStyle: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(15),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return I18n.inline('Введіть прізвище', 'Enter last name');
                            }
                            return null;
                          },
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
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: I18n.inline('Телефон', 'Phone'),
                            labelStyle: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(15),
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
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: InkWell(
                          onTap: _submitting ? null : _pickCountry,
                          borderRadius: BorderRadius.circular(15),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 16,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedCountry == null
                                        ? I18n.inline('Країна', 'Country')
                                        : _selectedCountry!,
                                    style: TextStyle(
                                      color: _selectedCountry == null
                                          ? Colors.white.withOpacity(0.7)
                                          : Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.public,
                                  color: Colors.white.withOpacity(0.7),
                                  size: 20,
                                ),
                              ],
                            ),
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
                        child: InkWell(
                          onTap: (_submitting || _selectedCountry == null)
                              ? null
                              : _pickCity,
                          borderRadius: BorderRadius.circular(15),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 16,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _cityController.text.trim().isEmpty
                                        ? I18n.inline('Місто', 'City')
                                        : _cityController.text.trim(),
                                    style: TextStyle(
                                      color: _cityController.text
                                              .trim()
                                              .isEmpty
                                          ? Colors.white.withOpacity(0.7)
                                          : Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.location_city,
                                  color: Colors.white.withOpacity(0.7),
                                  size: 20,
                                ),
                              ],
                            ),
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
                        child: InkWell(
                          onTap: _submitting ? null : _selectDateOfBirth,
                          borderRadius: BorderRadius.circular(15),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 16,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _dateOfBirth == null
                                        ? I18n.inline(
                                            'Дата народження',
                                            'Date of birth',
                                          )
                                        : _formatDateOfBirth(_dateOfBirth!),
                                    style: TextStyle(
                                      color: _dateOfBirth == null
                                          ? Colors.white.withOpacity(0.7)
                                          : Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.calendar_today,
                                  color: Colors.white.withOpacity(0.7),
                                  size: 20,
                                ),
                              ],
                            ),
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
                        child: DropdownButtonFormField<String>(
                          value: _selectedPosition,
                          style: const TextStyle(color: Colors.white),
                          dropdownColor: const Color(0xFF1e7d32),
                          decoration: InputDecoration(
                            labelText: I18n.inline(
                              'Позиція на полі',
                              'Field position',
                            ),
                            labelStyle: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(15),
                          ),
                          items: List<DropdownMenuItem<String>>.generate(
                            ProfileFieldOptions.positionStorageValues.length,
                            (i) {
                              return DropdownMenuItem<String>(
                                value: ProfileFieldOptions.positionStorageValues[i],
                                child: Text(
                                  ProfileFieldOptions.positionLabels[i],
                                  style: const TextStyle(color: Colors.white),
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
                              return I18n.inline('Виберіть позицію', 'Select position');
                            }
                            return null;
                          },
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
                          items: List<DropdownMenuItem<String>>.generate(
                            ProfileFieldOptions.experienceStorageValues.length,
                            (i) {
                              return DropdownMenuItem<String>(
                                value: ProfileFieldOptions.experienceStorageValues[i],
                                child: Text(
                                  ProfileFieldOptions.experienceLabels[i],
                                  style: const TextStyle(color: Colors.white),
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
                              return I18n.inline('Виберіть досвід', 'Select experience');
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
                            colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
                          ),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4caf50).withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          onPressed: _submitting
                              ? null
                              : () async {
                                  if (!_formKey.currentState!.validate()) {
                                    return;
                                  }
                                  if (_dateOfBirth == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          I18n.inline(
                                            'Оберіть дату народження',
                                            'Select your date of birth',
                                          ),
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  final countryTrim = _selectedCountry?.trim() ?? '';
                                  if (countryTrim.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          I18n.inline(
                                            'Оберіть країну',
                                            'Select your country',
                                          ),
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  final cityTrim = _cityController.text.trim();
                                  if (cityTrim.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          I18n.inline(
                                            'Оберіть місто',
                                            'Select your city',
                                          ),
                                        ),
                                      ),
                                    );
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
                                  if (_selectedPosition == null ||
                                      _selectedPosition!.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          I18n.inline(
                                            'Виберіть позицію',
                                            'Select position',
                                          ),
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  if (_selectedExperience == null ||
                                      _selectedExperience!.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          I18n.inline(
                                            'Виберіть досвід',
                                            'Select experience',
                                          ),
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  final submission = ProfileCompletionSubmission(
                                    name: _nameController.text.trim(),
                                    surname: _surnameController.text.trim(),
                                    phone: _phoneController.text.trim(),
                                    country: countryTrim,
                                    city: cityTrim,
                                    dateOfBirth: _dateOfBirth!,
                                    position: _selectedPosition!,
                                    experience: _selectedExperience!,
                                  );

                                  setState(() => _submitting = true);
                                  final avatarBytes = _pickedImage == null
                                      ? null
                                      : await _pickedImage!.readAsBytes();
                                  if (!mounted) return;
                                  _completionBloc.add(
                                    ProfileCompletionSubmitRequested(
                                      userId: uid,
                                      submission: submission,
                                      avatarBytes: avatarBytes,
                                      avatarMimeType: _pickedImage?.mimeType,
                                    ),
                                  );
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
                                  style: const TextStyle(
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
              ],
            ),
          ),
        ),
          ),
        ),
      ),
    );
  }
}
