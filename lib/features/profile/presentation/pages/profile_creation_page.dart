import 'dart:typed_data';

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/locale/football_position.dart';
import '../../../../utils/city_catalog.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/progress/progress_status.dart';
import '../../../../core/usecases/no_params.dart';
import '../../../../router/app_router.dart';
import '../../../auth/domain/repositories/auth_session_repository.dart';
import '../../../../widgets/city_autocomplete_field.dart';
import '../../../../theme/flap_tokens.dart';
import '../../domain/entities/editable_profile_submission.dart';
import '../../domain/usecases/load_current_profile_usecase.dart';
import '../bloc/profile_bloc.dart';
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
  /// Canonical [profiles.position] values (English) — must match [FootballPosition].
  static const List<String> _positionDbValues = <String>[
    FootballPosition.goalkeeper,
    FootballPosition.defender,
    FootballPosition.midfielder,
    FootballPosition.forward,
  ];

  static const List<IconData> _positionIcons = <IconData>[
    Icons.sports_handball_rounded,
    Icons.shield_rounded,
    Icons.swap_horiz_rounded,
    Icons.sports_soccer_rounded,
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

  List<String> get _positionLabels => [
        tr('il_f2d20c7ee1'),
        tr('il_157ddc59b5'),
        tr('il_d332e47845'),
        tr('il_f1c65e1481'),
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
      helpText: tr('date_of_birth'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: FlapColors.green,
              onPrimary: FlapColors.onGreen,
              surface: FlapColors.card,
              onSurface: FlapColors.text,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: FlapColors.card,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _dateOfBirth = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  /// Maps stored DB / legacy text to the selected position (English slug).
  String? _canonicalDropdownValue(String? stored) {
    if (stored == null) {
      return null;
    }
    final s = stored.trim();
    if (s.isEmpty) {
      return null;
    }
    final db = positionToEnglishDb(s);
    if (db == null || !_positionDbValues.contains(db)) {
      return null;
    }
    return db;
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

  Future<void> _onSubmit() async {
    if (_dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('profile_select_dob_required'))),
      );
      return;
    }
    if (_selectedPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('il_b48d31fb5a'))),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final cubit = context.read<ProfileCreationCubit>();
    final uid = sl<AuthSessionRepository>().peekCurrentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('il_1141023944'))),
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
              tr(
                'profile_avatar_read_failed',
                namedArgs: {'detail': e.toString()},
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
        sl<ProfileBloc>().add(
          const ProfileEvent.userProfileSyncRequested(),
        );
        if (widget.isEditing) {
          context.router.maybePop();
        } else {
          context.router.replace(const ModeSelectionRoute());
        }
      },
      failure: (f) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_submitErrorMessage(f))),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final submitting = context.select<ProfileCreationCubit, bool>(
      (cubit) => cubit.state.submitProgress == ProgressStatus.loading,
    );

    if (_loadingPrefill) {
      return Scaffold(
        backgroundColor: FlapColors.bg,
        body: Container(
          decoration: const BoxDecoration(gradient: FlapColors.screenGlow),
          child: SafeArea(
            child: Column(
              children: [
                _appBar(),
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: FlapColors.green,
                      strokeWidth: 2.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: FlapColors.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: FlapColors.screenGlow),
        child: SafeArea(
          child: Column(
            children: [
              _appBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_loadError != null) _errorBanner(_loadError!),
                        Center(child: _avatarPicker()),
                        const SizedBox(height: 8),
                        Center(
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Text(
                              tr('il_c0660be883'),
                              style: FlapText.sora(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: FlapColors.greenBright,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        _label(tr('il_702ef921ed')),
                        _inputField(
                          controller: _nameController,
                          hint: tr('il_702ef921ed'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return tr('il_05786ecba6');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        _label(tr('il_7b48880494')),
                        _inputField(
                          controller: _surnameController,
                          hint: tr('il_7b48880494'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return tr('il_6efd92ba0d');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        _label(tr('il_6d031af10d')),
                        _positionChips(),
                        const SizedBox(height: 18),
                        _label(tr('il_fc33f73246')),
                        _cityField(),
                        const SizedBox(height: 18),
                        _label(tr('date_of_birth')),
                        _dateField(),
                        const SizedBox(height: 30),
                        _actions(submitting),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _appBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.router.maybePop(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: FlapColors.surface2,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: FlapColors.border),
              ),
              child: const Icon(Icons.chevron_left,
                  color: FlapColors.text, size: 19),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.isEditing ? tr('il_15c4aa1303') : tr('il_61d30d997d'),
              style: FlapText.sora(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: FlapColors.text,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: FlapColors.amber.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlapColors.amber.withOpacity(0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: FlapColors.amber, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: FlapText.sora(color: FlapColors.amber, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarPicker() {
    Widget inner;
    if (_pickedImage != null) {
      inner = ClipOval(
        child: FutureBuilder<Uint8List>(
          future: _pickedImage!.readAsBytes(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
                width: 110,
                height: 110,
              );
            }
            return const Center(
              child: CircularProgressIndicator(
                color: FlapColors.green,
                strokeWidth: 2,
              ),
            );
          },
        ),
      );
    } else if (_existingAvatarUrl != null && _existingAvatarUrl!.isNotEmpty) {
      inner = ClipOval(
        child: Image.network(
          _existingAvatarUrl!,
          fit: BoxFit.cover,
          width: 110,
          height: 110,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(
              child: CircularProgressIndicator(
                color: FlapColors.green,
                strokeWidth: 2,
              ),
            );
          },
          errorBuilder: (_, __, ___) => _avatarPlaceholder(),
        ),
      );
    } else {
      inner = _avatarPlaceholder();
    }

    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 110,
            height: 110,
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  FlapColors.green,
                  FlapColors.greenBright,
                  FlapColors.greenDeep,
                  FlapColors.green,
                ],
              ),
            ),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: FlapColors.bg,
              ),
              child: ClipOval(child: inner),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: FlapColors.primaryButton,
                shape: BoxShape.circle,
                border: Border.all(color: FlapColors.bg, width: 3),
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  color: FlapColors.onGreen, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      width: 104,
      height: 104,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: FlapColors.card2,
      ),
      child: const Icon(Icons.person_rounded,
          color: FlapColors.muted, size: 48),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        text,
        style: FlapText.sora(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: FlapColors.muted,
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: FlapColors.surface2,
        borderRadius: BorderRadius.circular(FlapRadii.field),
        border: Border.all(color: FlapColors.border),
      ),
      child: TextFormField(
        controller: controller,
        style: FlapText.sora(color: FlapColors.text, fontSize: 15),
        cursorColor: FlapColors.greenBright,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: FlapText.sora(color: FlapColors.muted, fontSize: 15),
          border: InputBorder.none,
          errorStyle: FlapText.sora(color: FlapColors.red, fontSize: 11.5),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
        validator: validator,
      ),
    );
  }

  Widget _positionChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(_positionDbValues.length, (i) {
        final val = _positionDbValues[i];
        final active = _selectedPosition == val;
        return GestureDetector(
          onTap: () => setState(() => _selectedPosition = val),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: active
                  ? FlapColors.green.withOpacity(0.16)
                  : FlapColors.surface,
              borderRadius: BorderRadius.circular(FlapRadii.chip),
              border: Border.all(
                color: active
                    ? FlapColors.green.withOpacity(0.55)
                    : FlapColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _positionIcons[i],
                  size: 16,
                  color: active ? FlapColors.greenBright : FlapColors.muted,
                ),
                const SizedBox(width: 7),
                Text(
                  _positionLabels[i],
                  style: FlapText.sora(
                    fontSize: 13.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    color:
                        active ? FlapColors.greenBright : FlapColors.muted,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _cityField() {
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(FlapRadii.field),
      borderSide: const BorderSide(color: FlapColors.border),
    );
    return CityAutocompleteField(
      controller: _cityController,
      label: tr('il_fc33f73246'),
      requiredField: true,
      filled: true,
      fillColor: FlapColors.surface2,
      style: FlapText.sora(color: FlapColors.text, fontSize: 15),
      labelStyle: FlapText.sora(color: FlapColors.muted, fontSize: 15),
      border: outline,
      enabledBorder: outline,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FlapRadii.field),
        borderSide:
            const BorderSide(color: FlapColors.greenBright, width: 1.4),
      ),
      prefixIcon: const Icon(Icons.location_city_rounded,
          color: FlapColors.muted, size: 20),
    );
  }

  Widget _dateField() {
    final hasDate = _dateOfBirth != null;
    return GestureDetector(
      onTap: _pickDateOfBirth,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: FlapColors.surface2,
          borderRadius: BorderRadius.circular(FlapRadii.field),
          border: Border.all(color: FlapColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                color: FlapColors.muted, size: 19),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasDate
                    ? DateFormat.yMMMd(
                        Localizations.localeOf(context).toString(),
                      ).format(_dateOfBirth!)
                    : tr('select_date'),
                style: FlapText.sora(
                  fontSize: 15,
                  color: hasDate ? FlapColors.text : FlapColors.muted,
                ),
              ),
            ),
            const Icon(Icons.expand_more_rounded,
                color: FlapColors.muted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _actions(bool submitting) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: submitting ? null : () => context.router.maybePop(),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: FlapColors.surface2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: FlapColors.border),
              ),
              child: Text(
                tr('il_19766ed6cc'),
                style: FlapText.sora(
                  color: FlapColors.muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: GestureDetector(
            onTap: submitting ? null : _onSubmit,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                gradient: FlapColors.primaryButton,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: FlapColors.green.withOpacity(0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: FlapColors.onGreen,
                      ),
                    )
                  : Text(
                      widget.isEditing
                          ? tr('il_dd0ae7a5cb')
                          : tr('il_61d30d997d'),
                      style: FlapText.sora(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: FlapColors.onGreen,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
