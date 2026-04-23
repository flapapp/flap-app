import 'dart:typed_data';

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flap_app/app_locale_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/locale/football_position.dart';
import '../../../../utils/city_catalog.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/progress/progress_status.dart';
import '../../../../core/usecases/no_params.dart';
import '../../../../router/app_router.dart';
import '../../../auth/domain/repositories/auth_session_repository.dart';
import '../../../../widgets/city_autocomplete_field.dart';
import '../../domain/entities/editable_profile_submission.dart';
import '../../domain/usecases/load_current_profile_usecase.dart';
import '../cubit/profile_creation_cubit.dart';

@RoutePage()
class ProfileCreationScreen extends StatelessWidget {
  const ProfileCreationScreen({super.key, this.isEditing = false});

  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProfileCreationCubit>(),
      child: _ProfileCreationForm(isEditing: isEditing),
    );
  }
}

class _ProfileCreationForm extends StatefulWidget {
  const _ProfileCreationForm({required this.isEditing});

  final bool isEditing;

  @override
  State<_ProfileCreationForm> createState() => _ProfileCreationFormState();
}

class _ProfileCreationFormState extends State<_ProfileCreationForm> {
  /// Canonical values stored in DB / matched on load (dropdown `value`s).
  static const _positionUk = [
    'Воротар',
    'Захисник',
    'Півзахисник',
    'Нападник',
  ];
  static const _positionTrKeys = [
    'il_f2d20c7ee1',
    'il_157ddc59b5',
    'il_d332e47845',
    'il_f1c65e1481',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _cityController = TextEditingController();

  DateTime? _dateOfBirth;
  String? _selectedPosition;
  XFile? _pickedImage;

  bool _loadingPrefill = true;
  String? _loadError;
  String? _existingAvatarUrl;

  List<String> get _positions => [
        tr(_positionTrKeys[0]),
        tr(_positionTrKeys[1]),
        tr(_positionTrKeys[2]),
        tr(_positionTrKeys[3]),
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUserData());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  DateTime? _parseDateOfBirthFromDocument(Map<String, dynamic> userData) {
    final s = userData['dateOfBirth']?.toString();
    if (s != null && s.isNotEmpty) {
      final parts = s.split(RegExp(r'[-T]'));
      if (parts.length >= 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null &&
            m != null &&
            d != null &&
            y >= 1900 &&
            m >= 1 &&
            m <= 12 &&
            d >= 1 &&
            d <= 31) {
          return DateTime(y, m, d);
        }
      }
    }
    final ageVal = userData['age'];
    if (ageVal is int && ageVal > 0) {
      return DateTime(DateTime.now().year - ageVal, 1, 1);
    }
    return null;
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final initial = _dateOfBirth ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? initial : DateTime(now.year - 18, 6, 15),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: bilingual('Дата народження', 'Date of birth'),
    );
    if (picked != null && mounted) {
      setState(() {
        _dateOfBirth = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  /// Maps DB (English) / legacy (UK/tr) to the dropdown `value` (Ukrainian canonical).
  String? _canonicalDropdownValue(
    String? stored,
    List<String> uk,
    List<String> trKeys,
  ) {
    if (stored == null) {
      return null;
    }
    final s = stored.trim();
    if (s.isEmpty) {
      return null;
    }
    final pEn = positionToEnglishDb(s);
    for (var i = 0; i < uk.length && i < trKeys.length; i++) {
      if (pEn == positionToEnglishDb(uk[i]) ||
          pEn == positionToEnglishDb(tr(trKeys[i]))) {
        return uk[i];
      }
    }
    for (var i = 0; i < uk.length; i++) {
      if (s == uk[i]) {
        return uk[i];
      }
      if (i < trKeys.length && s == tr(trKeys[i])) {
        return uk[i];
      }
    }
    return null;
  }

  Future<void> _loadUserData() async {
    setState(() {
      _loadingPrefill = true;
      _loadError = null;
    });
    try {
      final result = await sl<LoadCurrentProfileUseCase>()(const NoParams());
      result.when(
        success: (profile) {
          final userData = profile.document;
          if (!mounted) return;
          final fn = userData['firstName']?.toString().trim() ?? '';
          final ln = userData['lastName']?.toString().trim() ?? '';
          setState(() {
            if (fn.isNotEmpty) {
              _nameController.text = fn;
            } else {
              _nameController.text = userData['name']?.toString() ?? '';
            }
            if (ln.isNotEmpty) {
              _surnameController.text = ln;
            } else {
              _surnameController.text = userData['surname']?.toString() ?? '';
            }
            _cityController.text = CityCatalog.labelForDisplay(
              (userData['city'] ?? '').toString(),
            );
            _dateOfBirth = _parseDateOfBirthFromDocument(userData);
            _selectedPosition = _canonicalDropdownValue(
              userData['position']?.toString(),
              _positionUk,
              _positionTrKeys,
            );
            _existingAvatarUrl = profile.avatarUrl;
            _loadingPrefill = false;
          });
        },
        failure: (f) {
          if (!mounted) return;
          setState(() {
            _loadingPrefill = false;
            _loadError = f.when(
              cache: () => tr('il_789c156110'),
              network: (m) => m ?? tr('il_789c156110'),
              unexpected: (m) => m ?? tr('il_789c156110'),
              auth: (_, m) => m ?? tr('il_789c156110'),
            );
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingPrefill = false;
        _loadError = e.toString();
      });
    }
  }

  String _submitErrorMessage(Failure f) {
    return f.when(
      cache: () => tr('il_789c156110'),
      network: (m) => m ?? tr('il_789c156110'),
      unexpected: (m) => m ?? tr('il_c578b58288'),
      auth: (_, m) => m ?? tr('il_789c156110'),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );

    if (picked == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('il_61aa8a16fb'))),
      );
      return;
    }

    setState(() {
      _pickedImage = picked;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('il_fee01cd3cc'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final submitting = context.select<ProfileCreationCubit, bool>(
      (cubit) => cubit.state.submitProgress == ProgressStatus.loading,
    );
    final baseTheme = Theme.of(context);
    final robotoTextTheme = GoogleFonts.robotoTextTheme(baseTheme.textTheme);
    final robotoFamily = GoogleFonts.roboto().fontFamily;

    if (_loadingPrefill) {
      return Theme(
        data: baseTheme.copyWith(
          textTheme: robotoTextTheme,
          primaryTextTheme: robotoTextTheme,
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFF1e7d32),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.router.maybePop(),
            ),
          ),
          body: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

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
            textStyle:
                GoogleFonts.roboto(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            textStyle:
                GoogleFonts.roboto(fontWeight: FontWeight.bold, fontSize: 16),
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
            onPressed: () => context.router.maybePop(),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  if (_loadError != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orangeAccent),
                      ),
                      child: Text(
                        _loadError!,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ],
                  Text(
                    widget.isEditing
                        ? tr('il_15c4aa1303')
                        : tr('il_61d30d997d'),
                    style: TextStyle(
                      fontFamily: robotoFamily,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 30),
                  GestureDetector(
                    onTap: _pickImage,
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
                      child: _pickedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(58),
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
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                },
                              ),
                            )
                          : _existingAvatarUrl != null &&
                                  _existingAvatarUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(58),
                                  child: Image.network(
                                    _existingAvatarUrl!,
                                    fit: BoxFit.cover,
                                    width: 120,
                                    height: 120,
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                      if (loadingProgress == null) {
                                        return child;
                                      }
                                      return const Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                        ),
                                      );
                                    },
                                    errorBuilder: (_, __, ___) => Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.broken_image_outlined,
                                          color: Colors.white.withOpacity(0.8),
                                          size: 40,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          tr('il_c0660be883'),
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
                                    const Icon(Icons.camera_alt,
                                        color: Colors.white, size: 40),
                                    const SizedBox(height: 8),
                                    Text(
                                      tr('il_c0660be883'),
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
                      style:
                          TextStyle(fontFamily: robotoFamily, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: tr('il_702ef921ed'),
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
                          return tr('il_05786ecba6');
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
                      style:
                          TextStyle(fontFamily: robotoFamily, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: tr('il_7b48880494'),
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
                          return tr('il_6efd92ba0d');
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
                      style:
                          TextStyle(fontFamily: robotoFamily, color: Colors.white),
                      dropdownColor: const Color(0xFF1e7d32),
                      decoration: InputDecoration(
                        hintText: tr('il_6d031af10d'),
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
                      items: List.generate(_positionUk.length, (i) {
                        return DropdownMenuItem<String>(
                          value: _positionUk[i],
                          child: Text(
                            _positions[i],
                            style: TextStyle(
                              fontFamily: robotoFamily,
                              color: Colors.white,
                            ),
                          ),
                        );
                      }),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedPosition = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return tr('il_b48d31fb5a');
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
                      label: tr('il_fc33f73246'),
                      requiredField: true,
                      style: TextStyle(fontFamily: robotoFamily, color: Colors.white),
                      labelStyle:
                          TextStyle(fontFamily: robotoFamily, color: Colors.white70),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      prefixIcon: const Icon(Icons.location_city, color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _pickDateOfBirth,
                      borderRadius: BorderRadius.circular(25),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              color: Colors.white.withOpacity(0.85),
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    bilingual(
                                      'Дата народження',
                                      'Date of birth',
                                    ),
                                    style: TextStyle(
                                      fontFamily: robotoFamily,
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _dateOfBirth != null
                                        ? DateFormat.yMMMd(
                                            Localizations.localeOf(context)
                                                .toString(),
                                          ).format(_dateOfBirth!)
                                        : bilingual(
                                            'Оберіть дату',
                                            'Select date',
                                          ),
                                    style: TextStyle(
                                      fontFamily: robotoFamily,
                                      fontSize: 16,
                                      color: _dateOfBirth != null
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.55),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.5),
                              width: 2,
                            ),
                          ),
                          onPressed: submitting
                              ? null
                              : () => context.router.maybePop(),
                          child: Text(
                            tr('il_19766ed6cc'),
                            style: TextStyle(
                              fontFamily: robotoFamily,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            backgroundColor: const Color(0xFF4caf50),
                          ),
                          onPressed: submitting
                              ? null
                              : () async {
                            if (_dateOfBirth == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    bilingual(
                                      'Оберіть дату народження',
                                      'Please select your date of birth',
                                    ),
                                  ),
                                ),
                              );
                              return;
                            }
                            if (!_formKey.currentState!.validate()) return;
                            final cubit = context.read<ProfileCreationCubit>();
                            final uid =
                                sl<AuthSessionRepository>().peekCurrentUser?.uid;
                            if (uid == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(tr('il_1141023944')),
                                ),
                              );
                              return;
                            }
                            Uint8List? avatarBytes;
                            if (_pickedImage != null) {
                              try {
                                avatarBytes = await _pickedImage!.readAsBytes();
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      bilingual(
                                        'Не вдалося прочитати фото: $e',
                                        'Failed to read photo: $e',
                                      ),
                                    ),
                                  ),
                                );
                                return;
                              }
                            }
                            final submission = EditableProfileSubmission(
                              userId: uid,
                              firstName: _nameController.text.trim(),
                              lastName: _surnameController.text.trim(),
                              city: _cityController.text.trim(),
                              dateOfBirth: _dateOfBirth,
                              position: _selectedPosition,
                              avatarJpegBytes: avatarBytes,
                              isEditing: widget.isEditing,
                            );
                            final result = await cubit.submit(submission);
                            if (!mounted) return;
                            result.when(
                              success: (_) {
                                if (widget.isEditing) {
                                  context.router.maybePop();
                                } else {
                                  context.router.replace(const ModeSelectionRoute());
                                }
                              },
                              failure: (f) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(_submitErrorMessage(f)),
                                  ),
                                );
                              },
                            );
                          },
                          child: submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  widget.isEditing
                                      ? tr('il_dd0ae7a5cb')
                                      : tr('il_61d30d997d'),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
