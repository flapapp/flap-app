import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import '../services/friends_service.dart';
import 'video_player_screen.dart';
import '../services/notification_service.dart';
import '../utils/i18n.dart';
import '../services/badge_service.dart';
import '../models/badge.dart' as app_badge;

class PlayerProfileScreen extends StatefulWidget {
  final String playerId;
  final String? playerName;

  const PlayerProfileScreen({
    Key? key,
    required this.playerId,
    this.playerName,
  }) : super(key: key);

  @override
  _PlayerProfileScreenState createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<String, dynamic>? playerData;
  List<Map<String, dynamic>> playerVideos = [];
  bool isLoading = true;
  final FriendsService _friendsService = FriendsService();
  bool _isSendingRequest = false;
  // Пікер та локальний буфер аватару
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedAvatar; // web-safe файл
  bool _uploadingAvatar = false;
  final NotificationService _notificationService = NotificationService();
  List<String> _myVideoIds = [];
  bool _loadingMyVideos = false;
  final BadgeService _badgeService = BadgeService();
  double _winRate = 0.0;
  List<String> _recentResults = const ['-', '-', '-', '-', '-'];
  List<String> _userBadgeIds = [];
  List<app_badge.Badge> _userBadges = [];
  int _badgeEndorseVersion = 0;
  // Опції як у реєстрації
  List<String> get _positions => [
        'Воротар'.i18n('Goalkeeper'),
        'Захисник'.i18n('Defender'),
        'Півзахисник'.i18n('Midfielder'),
        'Нападник'.i18n('Forward'),
        'Універсал'.i18n('Utility player'),
      ];
  List<String> get _experiences => [
        'Початківець'.i18n('Beginner'),
        'Аматор'.i18n('Amateur'),
        'Досвідчений'.i18n('Experienced'),
        'Професіонал'.i18n('Professional'),
      ];

  @override
  void initState() {
    super.initState();
    _loadPlayerData();
  }

  Future<void> _loadPlayerData() async {
    try {
      // Завантажити дані гравця
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.playerId)
          .get();

      if (userDoc.exists) {
        playerData = userDoc.data();
      }
      // Win Rate + останні 5 результатів
      final stats = await _loadMatchStats(widget.playerId);
      _winRate = stats['winRate'] as double? ?? 0.0;
      _recentResults = List<String>.from(
        stats['recentResults'] ?? const ['-', '-', '-', '-', '-'],
      );

            // Бейджі гравця
      try {
        final badgeObjects = await _badgeService.getUserBadgeObjects(widget.playerId);
        _userBadges = badgeObjects;
        _userBadgeIds = badgeObjects.map((b) => b.id).toList();
      } catch (_) {}

      // Завантажити відео гравця (simplified query to avoid index issues)
      final videosQuery = await FirebaseFirestore.instance
          .collection('videos')
          .where('userId', isEqualTo: widget.playerId)
          .limit(10)
          .get();

      playerVideos = videosQuery.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort on client side to avoid index requirement
      playerVideos.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error loading player data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _loadMatchStats(String userId) async {
  try {
    final base = FirebaseFirestore.instance
        .collection('matches')
        .where('participants', arrayContains: userId);

    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await base
          .where('status', isEqualTo: 'finished')
          .orderBy('updatedAt', descending: true)
          .limit(20)
          .get();
    } catch (_) {
      try {
        snap = await base
            .where('status', isEqualTo: 'finished')
            .limit(20)
            .get();
      } catch (_) {
        snap = await base.limit(20).get();
      }
    }

    int wins = 0, draws = 0, losses = 0;
    final List<String> recent = [];

    for (final d in snap.docs) {
      final data = d.data();

      int? aOpt = data['teamAScore'] as int?;
      int? bOpt = data['teamBScore'] as int?;
      int a = aOpt ?? 0, b = bOpt ?? 0;

      if (aOpt == null || bOpt == null) {
        final r = (data['result'] ?? '').toString();
        if (r == 'teamAWins') { a = 1; b = 0; }
        else if (r == 'teamBWins') { a = 0; b = 1; }
        else if (r == 'draw') { a = 0; b = 0; }
        else { continue; }
      }

      final teamA = List<String>.from((data['teamA']?['playerIds'] ?? const []));
      final teamB = List<String>.from((data['teamB']?['playerIds'] ?? const []));
      bool isA = teamA.contains(userId);
      if (!isA && teamA.isEmpty && teamB.isEmpty) {
        final parts = List<String>.from(data['participants'] ?? const []);
        if (parts.isNotEmpty) {
          final half = (parts.length / 2).ceil();
          isA = parts.take(half).contains(userId);
        }
      }

      String res;
      if (a == b) { draws++; res = 'D'; }
      else if ((isA && a > b) || (!isA && b > a)) { wins++; res = 'W'; }
      else { losses++; res = 'L'; }

      if (recent.length < 5) recent.add(res);
    }

    final total = wins + draws + losses;
    final rate = total > 0 ? (wins / total) * 100 : 0.0;
    while (recent.length < 5) recent.add('-');

    return {'winRate': rate, 'recentResults': recent};
  } catch (_) {
    return {'winRate': 0.0, 'recentResults': const ['-', '-', '-', '-', '-']};
  }
}

  Future<void> _loadMyVideosForRequest() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    setState(() {
      _loadingMyVideos = true;
    });
    try {
      final qs = await FirebaseFirestore.instance
          .collection('videos')
          .where('userId', isEqualTo: currentUser.uid)
          .limit(50)
          .get();
      _myVideoIds = qs.docs.map((d) => d.id).toList();
    } catch (_) {}
    if (mounted) setState(() {
      _loadingMyVideos = false;
    });
  }

  Future<void> _pickAvatar() async {
  try {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85);
    if (image != null) {
      setState(() => _pickedAvatar = image);
    }
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(I18n.inline('Помилка вибору фото: $e', 'Photo selection error: $e'))),
    );
  }
}

Future<String?> _uploadAvatarToStorage(String userId, XFile file) async {
  try {
    setState(() => _uploadingAvatar = true);
    final ref = FirebaseStorage.instance.ref().child('avatars').child(userId).child('avatar.jpg');
    final Uint8List bytes = await file.readAsBytes();
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();
    return url;
  } catch (e) {
    if (!mounted) return null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(I18n.inline('Помилка завантаження: $e', 'Upload error: $e'))),
    );
    return null;
  } finally {
    if (mounted) setState(() => _uploadingAvatar = false);
  }
}

  Future<void> _showRateMeDialog() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    await _loadMyVideosForRequest();
    if (_myVideoIds.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Немає ваших відео для запиту оцінки'.i18n('No videos available for a rating request'))),
      );
      return;
    }

    final qs = await FirebaseFirestore.instance
        .collection('videos')
        .where('userId', isEqualTo: currentUser.uid)
        .limit(50)
        .get();
    final videos = qs.docs.map((d) => {'id': d.id, ...(d.data() as Map<String, dynamic>)}).toList();
    final selected = <String>{};

    await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          title: Text('Оберіть мої відео для оцінки'.i18n('Select my videos to rate'), style: const TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: _loadingMyVideos
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF4caf50)))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: videos.length,
                    itemBuilder: (context, index) {
                      final v = videos[index];
                      final id = (v['id'] ?? '').toString();
                      final title = (v['title'] ?? 'Відео'.i18n('Video')).toString();
                      final isSel = selected.contains(id);
                      return CheckboxListTile(
                        value: isSel,
                        onChanged: (val) => setStateDialog(() {
                          if (val == true) {
                            selected.add(id);
                          } else {
                            selected.remove(id);
                          }
                        }),
                        title: Text(title, style: const TextStyle(color: Colors.white)),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(I18n.t('cancel'), style: const TextStyle(color: Colors.white70))),
            ElevatedButton(
              onPressed: selected.isEmpty
                  ? null
                  : () async {
                      final meDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
                      final myName = (meDoc.data()?['displayName'] ?? meDoc.data()?['name'] ?? 'Користувач'.i18n('User')).toString();
                      await _notificationService.sendRatingRequest(
                        toUserIds: [widget.playerId],
                        fromUserName: myName,
                        videoIds: selected.toList(),
                      );
                      if (!mounted) return;
                      Navigator.pop(context, true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('✅ Запит на оцінку надіслано'.i18n('✅ Rating request sent'))),
                      );
                    },
              child: Text('Надіслати'.i18n('Send')),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _areFriends() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;

    try {
      return await _friendsService.areUsersFriends(currentUser.uid, widget.playerId);
    } catch (e) {
      return false;
    }
  }

  Future<bool> _hasPendingRequest() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;

    try {
      // Check outgoing requests
      final outgoingRequests = await _friendsService.getOutgoingFriendRequests().first;
      return outgoingRequests.any((request) => request.toUserId == widget.playerId);
    } catch (e) {
      return false;
    }
  }

  Future<void> _sendFriendRequest() async {
    try {
      setState(() {
        _isSendingRequest = true;
      });

      await _friendsService.sendFriendRequest(widget.playerId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Запрошення надіслано!'.i18n('✅ Invitation sent!')),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.inline('Помилка: $e', 'Error: $e'))),
        );
      }
    } finally {
      setState(() {
        _isSendingRequest = false;
      });
    }
  }

  Widget _buildStarRating(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          rating > index ? (rating > index + 0.5 ? Icons.star : Icons.star_half) : Icons.star_border,
          color: Colors.amber,
          size: 16,
        );
      }),
    );
  }

  Future<void> _showEditProfileDialog() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid != widget.playerId) return;

    final data = Map<String, dynamic>.from(playerData ?? {});
    final nameCtrl = TextEditingController(text: (data['name'] ?? '').toString());
    final surnameCtrl = TextEditingController(text: (data['surname'] ?? '').toString());
    final emailCtrl = TextEditingController(text: (data['email'] ?? '').toString());
    final phoneCtrl = TextEditingController(text: (data['phone'] ?? '').toString());
    final cityCtrl = TextEditingController(text: (data['city'] ?? '').toString());
    final ageCtrl = TextEditingController(text: (data['age'] ?? '').toString());
    String? selectedPosition = (data['position']?.toString().trim().isNotEmpty == true) ? data['position'].toString() : null;
    String? selectedExperience = (data['experience']?.toString().trim().isNotEmpty == true) ? data['experience'].toString() : null;
    final avatarUrlCtrl = TextEditingController(text: (data['avatarUrl'] ?? '').toString());
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          title: Text(I18n.t('edit_profile'), style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _textField('Ім’я'.i18n('First name'), nameCtrl),
                  const SizedBox(height: 8),
                  _textField('Прізвище'.i18n('Last name'), surnameCtrl),
                  const SizedBox(height: 8),
                  _textField('Email', emailCtrl, requiredField: false),
                  const SizedBox(height: 8),
                  _textField(I18n.t('phone'), phoneCtrl, requiredField: false),
                  const SizedBox(height: 8),
                  _textField(I18n.t('city'), cityCtrl),
                  const SizedBox(height: 8),
                  _textField('Вік'.i18n('Age'), ageCtrl, requiredField: false),
                  const SizedBox(height: 8),

                  // Позиція (випадаючий список)
                  DropdownButtonFormField<String>(
                    value: selectedPosition,
                    items: _positions
                        .map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(color: Colors.white))))
                        .toList(),
                    onChanged: (v) => selectedPosition = v,
                    dropdownColor: const Color(0xFF1a1a2e),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: I18n.t('position'),
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
                      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF4caf50))),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Оберіть позицію'.i18n('Select a position') : null,
                  ),
                  const SizedBox(height: 8),

                  // Досвід (випадаючий список)
                  DropdownButtonFormField<String>(
                    value: selectedExperience,
                    items: _experiences
                        .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white))))
                        .toList(),
                    onChanged: (v) => selectedExperience = v,
                    dropdownColor: const Color(0xFF1a1a2e),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Досвід'.i18n('Experience'),
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
                      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF4caf50))),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Оберіть досвід'.i18n('Select experience') : null,
                  ),
                  const SizedBox(height: 8),

                  // Аватар (вибір файлу)
Align(
  alignment: Alignment.centerLeft,
  child: Text(I18n.t('avatar'), style: const TextStyle(color: Colors.white70)),
),
const SizedBox(height: 6),
Row(
  children: [
    Container(
      width: 56, height: 56,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white24)),
      clipBehavior: Clip.antiAlias,
      child: _pickedAvatar != null
          ? FutureBuilder<Uint8List>(
              future: _pickedAvatar!.readAsBytes(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                return Image.memory(snap.data!, fit: BoxFit.cover);
              },
            )
          : (avatarUrlCtrl.text.isNotEmpty
              ? Image.network(avatarUrlCtrl.text, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.black26))
              : Container(color: Colors.black26, child: const Icon(Icons.person, color: Colors.white54))),
    ),
    const SizedBox(width: 12),
    ElevatedButton.icon(
      onPressed: _uploadingAvatar ? null : _pickAvatar,
      icon: const Icon(Icons.photo_library, size: 18),
      label: Text(_pickedAvatar == null ? 'Обрати фото'.i18n('Choose photo') : 'Змінити'.i18n('Change')),
    ),
    const SizedBox(width: 12),
    if (_uploadingAvatar) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
  ],
),
const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: Text(I18n.t('cancel'), style: const TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setStateDialog(() => saving = true);
                      try {
                        final displayName = '${nameCtrl.text.trim()} ${surnameCtrl.text.trim()}'.trim();
                        String avatarUrlToSave = avatarUrlCtrl.text.trim();
if (_pickedAvatar != null) {
  final uploaded = await _uploadAvatarToStorage(widget.playerId, _pickedAvatar!);
  if (uploaded != null) {
    avatarUrlToSave = uploaded;
  }
}

await FirebaseFirestore.instance.collection('users').doc(widget.playerId).update({
  'name': nameCtrl.text.trim(),
  'surname': surnameCtrl.text.trim(),
  'displayName': displayName.isNotEmpty ? displayName : null,
  'email': emailCtrl.text.trim(),
  'phone': phoneCtrl.text.trim(),
  'city': cityCtrl.text.trim(),
  'age': int.tryParse(ageCtrl.text.trim()) ?? FieldValue.delete(),
  'position': selectedPosition ?? FieldValue.delete(),
  'experience': selectedExperience ?? FieldValue.delete(),
  'avatarUrl': avatarUrlToSave,
  'updatedAt': FieldValue.serverTimestamp(),
});
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        _pickedAvatar = null;
                        await _loadPlayerData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('✅ Профіль оновлено'.i18n('✅ Profile updated'))),
                        );
                      } catch (e) {
                        setStateDialog(() => saving = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(I18n.inline('Помилка збереження: $e', 'Save error: $e'))),
                        );
                      }
                    },
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(I18n.t('save')),
            ),
          ],
        ),
      ),
    );

    nameCtrl.dispose();
    surnameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    cityCtrl.dispose();
    ageCtrl.dispose();
    avatarUrlCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0f0f23),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.playerName ?? 'Профіль гравця'.i18n('Player profile'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF4caf50)),
        ),
      );
    }

    if (playerData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0f0f23),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            I18n.t('profile_not_found'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        body: Center(
          child: Text(
            'Профіль гравця не знайдено'.i18n('Player profile not found'),
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }

    final displayName = (playerData!['displayName'] ?? 
                         playerData!['name'] ?? 
                         playerData!['authorName'] ?? 
                         playerData!['email']?.toString().split('@').first ?? 
                         I18n.t('player')).toString();
    final position = playerData!['position'] ?? '';
    final experience = playerData!['experience'] ?? '';
    final city = playerData!['city'] ?? '';
    final rating = (playerData!['rating'] ?? 0.0).toDouble();
    final matches = ((playerData!['totalMatches'] ?? playerData!['matches'] ?? playerData!['matchesPlayed'] ?? 0) as num).toInt();
    final averageRating = (playerData!['averageRating'] ?? rating).toDouble();
    final wins   = ((playerData!['wins'] ?? playerData!['wonMatches']  ?? 0) as num).toInt();
    final losses = ((playerData!['losses'] ?? playerData!['lostMatches'] ?? 0) as num).toInt();
    final draws  = ((playerData!['draws'] ?? playerData!['drawMatches']  ?? 0) as num).toInt();
    final avatarUrl = (playerData!['avatarUrl'] ?? playerData!['avatar'] ?? playerData!['photoUrl'] ?? '').toString();

    final me = FirebaseAuth.instance.currentUser?.uid;
    final isOwnProfile = me != null && widget.playerId == me;

    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.playerName ?? 'Профіль гравця'.i18n('Player profile'), style: const TextStyle(color: Colors.white)),
        actions: [
          if (isOwnProfile)
            IconButton(
              tooltip: I18n.t('edit_profile'),
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: _showEditProfileDialog,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Аватар
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(48),
                border: Border.all(color: Colors.white24, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(48),
                child: avatarUrl.isNotEmpty
                    ? Image.network(avatarUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildDefaultAvatar(displayName))
                    : _buildDefaultAvatar(displayName),
              ),
            ),
            const SizedBox(height: 12),
            Text(displayName,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (position.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Text('⚽ $position', style: const TextStyle(color: Colors.white)),
              ),
            const SizedBox(height: 12),
            if (city.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on, color: Colors.white70, size: 16),
                  const SizedBox(width: 4),
                  Text(city, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            const SizedBox(height: 20),

            // Рейтинг
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Text(rating.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
                Text(I18n.t('overall_rating'), style: const TextStyle(color: Colors.white70)),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _statBox(value: matches.toString(), label: 'Матчі зіграно'.i18n('Matches played'))),
              const SizedBox(width: 10),
              Expanded(child: _statBox(value: averageRating.toStringAsFixed(2), label: 'Середня оцінка'.i18n('Average rating'))),
            ]),
            const SizedBox(height: 20),

            // Win Rate + останні 5
Container(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.06),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Column(
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.percent, color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          Text('Win Rate: ${_winRate.toStringAsFixed(0)}%',
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _recentResults.map((r) {
          Color c;
          if (r == 'W') c = const Color(0xFF4CAF50);
          else if (r == 'D') c = Colors.grey;
          else if (r == 'L') c = Colors.red;
          else c = Colors.grey;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: c.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: c, width: 1.5),
            ),
            child: Center(child: Text(r, style: TextStyle(color: c, fontWeight: FontWeight.bold))),
          );
        }).toList(),
      ),
    ],
  ),
),
const SizedBox(height: 12),

            // Кнопки (приховані на власному профілі)
            Builder(
              builder: (context) {
                final me = FirebaseAuth.instance.currentUser?.uid;
                final isOwnProfile = me != null && widget.playerId == me;
                if (isOwnProfile) return const SizedBox.shrink();

                return FutureBuilder<Map<String, bool>>(
                  future: Future.wait([_areFriends(), _hasPendingRequest()]).then((results) {
                    return {'isFriend': results[0], 'hasPendingRequest': results[1]};
                  }),
                  builder: (context, snapshot) {
                    final data = snapshot.data ?? {'isFriend': false, 'hasPendingRequest': false};
                    final isFriend = data['isFriend']!;
                    final hasPendingRequest = data['hasPendingRequest']!;

                    return Row(children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isFriend || hasPendingRequest || _isSendingRequest ? null : () => _sendFriendRequest(),
                          icon: Icon(isFriend
                              ? Icons.people
                              : hasPendingRequest
                                  ? Icons.schedule
                                  : Icons.person_add),
                          label: Text(isFriend
                              ? I18n.t('friends')
                              : hasPendingRequest
                                  ? 'Запрошення надіслано'.i18n('Invitation sent')
                                  : _isSendingRequest
                                      ? 'Надсилання...'.i18n('Sending...')
                                      : 'Додати в друзі'.i18n('Add friend')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4caf50),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: hasPendingRequest ? Colors.orange.withOpacity(0.4) : Colors.grey.withOpacity(0.4),
                            disabledForegroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            side: BorderSide(color: Colors.white.withOpacity(0.2)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _showInviteToChallengeDialog(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.12),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        child: const Icon(Icons.emoji_events, size: 16),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _showRateMeDialog(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4caf50),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        child: Text('Оціни мене'.i18n('Rate me')),
                      ),
                    ]);
                  },
                );
              },
            ),

            // Бейджі
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(I18n.t('badges'), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (_userBadges.isEmpty)
                    Text('Бейджів поки немає'.i18n('No badges yet'), style: const TextStyle(color: Colors.white54))
                  else
                    SizedBox(
                      height: 82,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _userBadges.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (ctx, i) {
                          final badge = _userBadges[i];
                          final catColor = Color(badge.categoryColor);
                          return GestureDetector(
                            onTap: () => _endorseBadge(widget.playerId, badge),
                            child: Container(
                              width: 160,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: catColor.withOpacity(0.2),
                                      border: Border.all(color: catColor.withOpacity(0.5), width: 1.5),
                                    ),
                                    child: Center(child: Text(badge.emoji, style: const TextStyle(fontSize: 24))),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          badge.localizedName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 3),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: catColor.withOpacity(0.18),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: catColor.withOpacity(0.45)),
                                          ),
                                          child: Text(
                                            badge.rarityText,
                                            style: TextStyle(color: catColor, fontSize: 9, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        FutureBuilder<Map<String, dynamic>>(
                                          key: ValueKey('endorse-${badge.id}-$_badgeEndorseVersion'),
                                          future: _getBadgeEndorsementInfo(widget.playerId, badge.id),
                                          builder: (context, snapshot) {
                                            final count = snapshot.data?['count'] as int? ?? 0;
                                            final endorsed = snapshot.data?['endorsed'] as bool? ?? false;
                                            return Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: endorsed ? catColor.withOpacity(0.25) : Colors.white.withOpacity(0.12),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: endorsed ? catColor : Colors.white24),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.thumb_up, size: 11, color: endorsed ? catColor : Colors.white70),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        count.toString(),
                                                        style: TextStyle(
                                                          color: endorsed ? catColor : Colors.white,
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (endorsed) ...[
                                                  const SizedBox(width: 3),
                                                  const Icon(Icons.check_circle, color: Colors.greenAccent, size: 13),
                                                ],
                                              ],
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Відео гравця
            if (playerVideos.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(I18n.t('videos'), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: playerVideos.length,
                  itemBuilder: (context, index) {
                    final v = playerVideos[index];
                    final thumb = (v['thumbnailUrl'] ?? '').toString();
                    final vUrl = (v['videoUrl'] ?? '').toString();
                    final title = (v['title'] ?? 'Відео'.i18n('Video')).toString();
                    return GestureDetector(
                      onTap: () {
                        if (vUrl.isEmpty) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VideoPlayerScreen(
                              videoUrl: vUrl,
                              title: title,
                              authorName: displayName,
                              videoId: (v['id'] ?? '').toString(),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 160,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: thumb.isNotEmpty
                              ? (kIsWeb && thumb == vUrl
                                  ? _buildWebVideoPreview(vUrl)
                                  : Image.network(
                                      thumb,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _videoThumbFallback(title),
                                    ))
                              : (kIsWeb && vUrl.isNotEmpty ? _buildWebVideoPreview(vUrl) : _videoThumbFallback(title)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Поки що немає відео'.i18n('No videos yet'), style: const TextStyle(color: Colors.white54)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(String name) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _statBox({required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _videoThumbFallback(String title) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildWebVideoPreview(String videoUrl) {
    return FutureBuilder<VideoPlayerController>(
      future: _createVideoController(videoUrl),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.value.isInitialized) {
          final controller = snapshot.data!;
          return AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          );
        }
        return Container(
          color: Colors.black54,
          child: const Center(
            child: CircularProgressIndicator(color: Color(0xFF4caf50), strokeWidth: 2),
          ),
        );
      },
    );
  }

  Future<VideoPlayerController> _createVideoController(String videoUrl) async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    await controller.initialize();
    await controller.seekTo(const Duration(seconds: 1));
    await controller.pause();
    return controller;
  }

  Future<void> _showInviteToChallengeDialog() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('challenges')
          .where('creatorId', isEqualTo: currentUser.uid)
          .limit(50)
          .get();

      final all = snap.docs
          .map((d) {
            final data = d.data() as Map<String, dynamic>;
            data['id'] = d.id;
            return data;
          })
          .where((c) {
            final participants = List<String>.from(c['participants'] ?? []);
            return !participants.contains(widget.playerId);
          })
          .toList();

      if (all.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Немає доступних ваших челенджів для запрошення.'.i18n('No available challenges to invite.'))),
        );
        return;
      }

      int selectedIndex = -1;
      await showDialog<bool>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setStateDialog) => AlertDialog(
              backgroundColor: const Color(0xFF1a1a2e),
              title: Text('Запросити до челенджу'.i18n('Invite to challenge'), style: const TextStyle(color: Colors.white)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: all.length,
                  itemBuilder: (context, index) {
                    final c = all[index];
                    return RadioListTile<int>(
                      value: index,
                      groupValue: selectedIndex,
                      onChanged: (v) => setStateDialog(() => selectedIndex = v ?? -1),
                      title: Text(c['title'] ?? 'Челендж'.i18n('Challenge'), style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                          'Учасників: ${(c['participants'] as List?)?.length ?? 0}'.i18n('Participants: ${(c['participants'] as List?)?.length ?? 0}'),
                          style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(I18n.t('cancel'), style: const TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  onPressed: selectedIndex < 0
                      ? null
                      : () async {
                          final me = FirebaseAuth.instance.currentUser?.uid;
                          if (me == null || widget.playerId == me) return;
                          final selected = all[selectedIndex];
                          final ok = await _notificationService.sendChallengeInvitation(
                            toUserId: widget.playerId,
                            challengeId: (selected['id'] ?? '').toString(),
                            challengeTitle: (selected['title'] ?? 'Челендж'.i18n('Challenge')).toString(),
                            creatorName: (playerData?['displayName'] ?? 'Користувач'.i18n('User')).toString(),
                            challengeType: (selected['type'] ?? 'goal').toString(),
                          );
                          if (!mounted) return;
                          Navigator.pop(context, true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(ok ? '✅ Запрошення надіслано'.i18n('✅ Invitation sent') : '❌ Не вдалося надіслати'.i18n('❌ Failed to send'))),
                          );
                        },
                  child: Text('Запросити'.i18n('Invite')),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.inline('Помилка: $e', 'Error: $e'))),
      );
    }
  }

  // Універсальний текстовий інпут для форм модалки
  Widget _textField(String label, TextEditingController c, {bool requiredField = true}) {
    return TextFormField(
      controller: c,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF4caf50)),
        ),
      ),
      validator: requiredField
          ? (v) => (v == null || v.trim().isEmpty) ? 'Обов’язкове поле'.i18n('This field is required') : null
          : null,
    );
  }

  Future<Map<String, dynamic>> _getBadgeEndorsementInfo(String userId, String badgeId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('badge_endorsements')
          .doc(badgeId)
          .get();
      final currentUid = _auth.currentUser?.uid;
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final endorsers = List<String>.from(data['endorsers'] ?? []);
        final endorsed = currentUid != null && endorsers.contains(currentUid);
        return {'count': endorsers.length, 'endorsed': endorsed};
      }
      return {'count': 0, 'endorsed': false};
    } catch (_) {
      return {'count': 0, 'endorsed': false};
    }
  }

  Future<void> _endorseBadge(String ownerId, app_badge.Badge badge) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Увійдіть, щоб підтверджувати бейджі'.i18n('Sign in to endorse badges'))),
      );
      return;
    }
    if (currentUserId == ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не можна підтверджувати власні бейджі'.i18n('You cannot endorse your own badges'))),
      );
      return;
    }

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(ownerId)
        .collection('badge_endorsements')
        .doc(badge.id);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        List<String> endorsers = [];
        if (snap.exists) {
          endorsers = List<String>.from(snap.data()?['endorsers'] ?? []);
        }
        if (endorsers.contains(currentUserId)) {
          throw Exception('already-endorsed');
        }
        endorsers.add(currentUserId);
        tx.set(
          ref,
          {
            'endorsers': endorsers,
            'lastEndorsedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      final currentUserDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
      final currentName = currentUserDoc.data()?['displayName'] ?? currentUserDoc.data()?['name'] ?? 'Користувач'.i18n('User');

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': ownerId,
        'type': 'badgeEndorsed',
        'title': 'Підтвердження бейджу'.i18n('Badge endorsement'),
        'message': I18n.inline('$currentName підтвердив ваш бейдж "${badge.localizedName}"', '$currentName confirmed your badge "${badge.localizedName}"'),
        'data': {'badgeId': badge.id},
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.inline('✅ Ви підтвердили бейдж "${badge.localizedName}"', '✅ You endorsed the badge "${badge.localizedName}"'))),
      );
      setState(() {
        _badgeEndorseVersion++;
      });
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().contains('already-endorsed')
          ? 'Ви вже підтвердили цей бейдж'.i18n('You already endorsed this badge')
          : 'Помилка підтвердження'.i18n('Endorsement error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}