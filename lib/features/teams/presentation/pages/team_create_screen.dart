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
        SnackBar(content: Text(tr('il_e69e7edfdf', namedArgs: {'e': e.toString()}))),
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
    const accent = Color(0xFF4CAF50);

    return Scaffold(
      backgroundColor: const Color(0xFF070A08),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          tr('il_b5ad09892b'),
          style: FlapText.sora(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF13241B), FlapColors.bg],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF070A08), Color(0xFF070A08)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
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
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 40,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (limitReached) _buildLimitBanner(),
                            if (limitReached) const SizedBox(height: 16),
                            _buildLogoSelector(accent),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _nameCtrl,
                              cursorColor: Colors.white,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: _fieldDecoration(
                                tr('il_0952fcc6fe'),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().length < 3) {
                                  return tr('il_2bb9a4e3a6');
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _descCtrl,
                              maxLines: 3,
                              cursorColor: Colors.white,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                height: 1.4,
                              ),
                              decoration: _fieldDecoration(
                                tr('il_f6cbe2f0c1'),
                              ),
                              validator: (value) {
                                if (value != null &&
                                    value.trim().isNotEmpty &&
                                    value.trim().length < 10) {
                                  return tr('il_4a33faf877');
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            CityAutocompleteField(
                          controller: _cityCtrl,
                          label: tr('il_23d02bb867'),
                          requiredField: false,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          labelStyle: const TextStyle(color: Colors.white70),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF4CAF50)),
                          ),
                          prefixIcon: const Icon(Icons.location_city, color: Colors.white70),
                        ),
                            const SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                color: Colors.white.withValues(alpha: 0.01),
                              ),
                              child: SwitchListTile.adaptive(
                                activeTrackColor: accent.withValues(alpha: 0.4),
                                activeThumbColor: accent,
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                title: Text(
                                  tr('il_c48fc6f1b4'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  tr('il_369c6f6787'),
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                                value: _isPublic,
                                onChanged: (value) => setState(() => _isPublic = value),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _createTeam,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accent,
                                  foregroundColor: const Color(0xFF06140A),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Color(0xFF06140A),
                                          ),
                                        ),
                                      )
                                    : Text(tr('il_284ff194f8')),
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildHeroBanner(bool limitReached) {
    final accent = limitReached ? Colors.redAccent : const Color(0xFF4CAF50);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: limitReached
              ? [const Color(0xFF3B121B), const Color(0xFF150608)]
              : [const Color(0xFF13241B), const Color(0xFF070A08)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            tr('il_48efab2424'),
            style: TextStyle(
              color: accent,
              fontSize: 14,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tr('il_c0c1852b09'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr('il_19c4134847'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              _heroChip(Icons.palette, tr('il_d417aa16da')),
              _heroChip(Icons.shield, tr('il_999f23fcd7')),
              _heroChip(Icons.groups, tr('il_12fd2f174a')),
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
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildLimitBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.redAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tr('il_ac1e4b5525'),
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoSelector(Color accent) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [accent, accent.withValues(alpha: 0.4)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: CircleAvatar(
                radius: 52,
                backgroundColor: const Color(0xFF0E1310),
                backgroundImage:
                    _logoBytes != null ? MemoryImage(_logoBytes!) : null,
                child: _logoBytes == null
                    ? Icon(Icons.add_a_photo, color: accent, size: 30)
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _pickLogo,
          icon: const Icon(Icons.upload, color: Colors.white),
          label: Text(
            tr('il_0ec3891a84'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          tr('il_748cf916e2'),
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.02),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
      ),
    );
  }
}

