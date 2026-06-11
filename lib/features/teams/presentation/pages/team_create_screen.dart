import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import 'package:image_picker/image_picker.dart';

import '../../../../core/di/injection.dart';
import '../../../../theme/flap_tokens.dart';
import '../../domain/repositories/teams_repository.dart';
import '../../../../widgets/city_autocomplete_field.dart';

@RoutePage()
class TeamCreateScreen extends StatefulWidget {
  final int existingTeams;

  const TeamCreateScreen({super.key, required this.existingTeams});

  @override
  State<TeamCreateScreen> createState() => _TeamCreateScreenState();
}

class _TeamCreateScreenState extends State<TeamCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  bool _isPublic = true;
  bool _isSaving = false;
  Uint8List? _logoBytes;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _logoBytes = bytes;
    });
  }

  Future<void> _createTeam() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await sl<TeamsRepository>().createTeam(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        isPublic: _isPublic,
        logoBytes: _logoBytes,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(tr('il_e69e7edfdf', namedArgs: {'e': e.toString()})),
          backgroundColor: FlapColors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final limitReached = widget.existingTeams >= 3;

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
                  child: Column(
                    children: [
                      _buildHeroBanner(limitReached),
                      const SizedBox(height: 20),
                      AbsorbPointer(
                        absorbing: limitReached || _isSaving,
                        child: Opacity(
                          opacity: limitReached ? 0.55 : 1,
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (limitReached) ...[
                                  _buildLimitBanner(),
                                  const SizedBox(height: 20),
                                ],
                                Center(child: _buildLogoSelector()),
                                const SizedBox(height: 28),
                                _label(tr('il_0952fcc6fe')),
                                _inputField(
                                  controller: _nameCtrl,
                                  hint: tr('il_0952fcc6fe'),
                                  validator: (value) {
                                    if (value == null ||
                                        value.trim().length < 3) {
                                      return tr('il_2bb9a4e3a6');
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),
                                _label(tr('il_f6cbe2f0c1')),
                                _inputField(
                                  controller: _descCtrl,
                                  hint: tr('il_f6cbe2f0c1'),
                                  maxLines: 3,
                                  validator: (value) {
                                    if (value != null &&
                                        value.trim().isNotEmpty &&
                                        value.trim().length < 10) {
                                      return tr('il_4a33faf877');
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),
                                _label(tr('il_23d02bb867')),
                                _cityField(),
                                const SizedBox(height: 18),
                                _buildVisibilityToggle(),
                                const SizedBox(height: 28),
                                _primaryButton(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Chrome / styled builders ------------------------------------------

  Widget _appBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
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
              tr('il_b5ad09892b'),
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

  Widget _buildHeroBanner(bool limitReached) {
    final accent = limitReached ? FlapColors.red : FlapColors.greenBright;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FlapRadii.card),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: limitReached
              ? const [Color(0xFF2A0E14), FlapColors.bg]
              : const [Color(0xFF13241B), FlapColors.bg],
        ),
        border: Border.all(color: FlapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            tr('il_48efab2424'),
            style: FlapText.cond(
              color: accent,
              fontSize: 13,
              letterSpacing: 3.4,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            tr('il_c0c1852b09'),
            textAlign: TextAlign.center,
            style: FlapText.cond(
              color: FlapColors.text,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr('il_19c4134847'),
            textAlign: TextAlign.center,
            style: FlapText.sora(
              color: FlapColors.muted,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              _heroChip(Icons.palette_rounded, tr('il_d417aa16da')),
              _heroChip(Icons.shield_rounded, tr('il_999f23fcd7')),
              _heroChip(Icons.groups_rounded, tr('il_12fd2f174a')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: FlapColors.surface2,
        border: Border.all(color: FlapColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: FlapColors.greenBright),
          const SizedBox(width: 6),
          Text(
            text,
            style: FlapText.sora(color: FlapColors.text, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FlapColors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(FlapRadii.tile),
        border: Border.all(color: FlapColors.red.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: FlapColors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tr('il_ac1e4b5525'),
              style: FlapText.sora(color: FlapColors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoSelector() {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickLogo,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 120,
                height: 120,
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
                  child: ClipOval(
                    child: _logoBytes != null
                        ? Image.memory(
                            _logoBytes!,
                            fit: BoxFit.cover,
                            width: 114,
                            height: 114,
                          )
                        : Container(
                            color: FlapColors.card2,
                            child: const Icon(
                              Icons.shield_rounded,
                              color: FlapColors.muted,
                              size: 44,
                            ),
                          ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: FlapColors.primaryButton,
                    shape: BoxShape.circle,
                    border: Border.all(color: FlapColors.bg, width: 3),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: FlapColors.onGreen, size: 17),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickLogo,
          child: Text(
            tr('il_0ec3891a84'),
            style: FlapText.sora(
              color: FlapColors.greenBright,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          tr('il_748cf916e2'),
          style: FlapText.sora(color: FlapColors.muted2, fontSize: 12),
        ),
      ],
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
    int maxLines = 1,
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
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: FlapText.sora(color: FlapColors.muted, fontSize: 15),
          border: InputBorder.none,
          errorStyle: FlapText.sora(color: FlapColors.red, fontSize: 11.5),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
      ),
    );
  }

  Widget _cityField() {
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(FlapRadii.field),
      borderSide: const BorderSide(color: FlapColors.border),
    );
    return CityAutocompleteField(
      controller: _cityCtrl,
      label: tr('il_23d02bb867'),
      requiredField: false,
      filled: true,
      fillColor: FlapColors.surface2,
      style: FlapText.sora(color: FlapColors.text, fontSize: 15),
      labelStyle: FlapText.sora(color: FlapColors.muted, fontSize: 15),
      border: outline,
      enabledBorder: outline,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FlapRadii.field),
        borderSide: const BorderSide(color: FlapColors.greenBright, width: 1.4),
      ),
      prefixIcon: const Icon(Icons.location_city_rounded,
          color: FlapColors.muted, size: 20),
    );
  }

  Widget _buildVisibilityToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FlapRadii.tile),
        border: Border.all(color: FlapColors.border),
        color: FlapColors.surface,
      ),
      child: SwitchListTile.adaptive(
        activeTrackColor: FlapColors.green.withValues(alpha: 0.4),
        activeThumbColor: FlapColors.green,
        contentPadding: EdgeInsets.zero,
        title: Text(
          tr('il_c48fc6f1b4'),
          style: FlapText.sora(
            color: FlapColors.text,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          tr('il_369c6f6787'),
          style: FlapText.sora(color: FlapColors.muted, fontSize: 12),
        ),
        value: _isPublic,
        onChanged: (value) => setState(() => _isPublic = value),
      ),
    );
  }

  Widget _primaryButton() {
    return GestureDetector(
      onTap: _isSaving ? null : _createTeam,
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: FlapColors.primaryButton,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: FlapColors.green.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: _isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: FlapColors.onGreen,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr('il_284ff194f8'),
                    style: FlapText.sora(
                      color: FlapColors.onGreen,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded,
                      color: FlapColors.onGreen, size: 19),
                ],
              ),
      ),
    );
  }
}
