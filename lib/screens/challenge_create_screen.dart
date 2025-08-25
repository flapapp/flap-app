import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/challenge.dart';
import '../services/challenge_service.dart';

class ChallengeCreateScreen extends StatefulWidget {
  @override
  _ChallengeCreateScreenState createState() => _ChallengeCreateScreenState();
}

class _ChallengeCreateScreenState extends State<ChallengeCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _prizePoolController = TextEditingController();
  final _maxParticipantsController = TextEditingController();
  
  ChallengeType _selectedType = ChallengeType.technical;
  ChallengeAudience _selectedAudience = ChallengeAudience.city;
  String _selectedCity = 'Київ';
  int _selectedEntryFee = 10;
  int _recruitmentDays = 7;
  int _submissionDays = 7;
  int _votingDays = 5;
  bool _isCreating = false;
  File? _selectedVideoFile;
  
  final ChallengeService _challengeService = ChallengeService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final List<String> _cities = [
    'Київ',
    'Харків',
    'Одеса',
    'Дніпро',
    'Львів',
    'Запоріжжя',
    'Кривий Ріг',
    'Миколаїв',
    'Вінниця',
    'Полтава',
    'Черкаси',
    'Суми',
    'Хмельницький',
    'Чернівці',
    'Житомир',
    'Тернопіль',
    'Івано-Франківськ',
    'Луцьк',
    'Рівне',
    'Ужгород',
  ];

  final List<int> _entryFees = [5, 10, 15, 20, 25];
  final List<int> _durations = [1, 3, 7, 14];

  @override
  void initState() {
    super.initState();
    _maxParticipantsController.text = '20';
    _prizePoolController.text = '100';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _prizePoolController.dispose();
    _maxParticipantsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1e7d32),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber, size: 24),
            const SizedBox(width: 8),
            const Text(
              'Створити челендж',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Заголовок
                _buildSectionTitle(Icons.info, 'Основна інформація'),
                const SizedBox(height: 15),

                // Завантаження відео для челенджу
                _buildSectionTitle(Icons.video_library, 'Відео челенджу'),
                const SizedBox(height: 15),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      if (_selectedVideoFile == null) ...[
                        Icon(
                          Icons.video_library,
                          size: 48,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Завантажте відео для челенджу',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Це відео буде показуватися як приклад для інших учасників',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _pickVideo(fromCamera: false),
                                icon: const Icon(Icons.video_library),
                                label: const Text('Галерея'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4caf50),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _pickVideo(fromCamera: true),
                                icon: const Icon(Icons.videocam),
                                label: const Text('Камера'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white24,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Icon(
                              Icons.video_file,
                              size: 32,
                              color: const Color(0xFF4caf50),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Відео обрано',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    _selectedVideoFile!.path.split('/').last,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(() => _selectedVideoFile = null),
                              icon: const Icon(Icons.close, color: Colors.white70),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                
                // Назва челенджу
                _buildTextField(
                  controller: _titleController,
                  label: 'Назва челенджу *',
                  hint: 'Наприклад: "Дриблінг через конуси"',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Введіть назву челенджу';
                    }
                    if (value.trim().length < 5) {
                      return 'Назва має бути не менше 5 символів';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 20),
                
                // Опис
                _buildTextField(
                  controller: _descriptionController,
                  label: 'Опис челенджу *',
                  hint: 'Детально опишіть правила та вимоги до челенджу...',
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Введіть опис челенджу';
                    }
                    if (value.trim().length < 20) {
                      return 'Опис має бути не менше 20 символів';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 25),
                
                // Тип та аудиторія
                _buildSectionTitle(Icons.settings, 'Налаштування'),
                const SizedBox(height: 15),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdownField(
                        label: 'Тип челенджу *',
                        value: _selectedType,
                        items: ChallengeType.values,
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value!;
                          });
                        },
                        itemBuilder: (type) => Text(type == ChallengeType.technical ? 'Технічні' : 'Позиційні'),
                        icon: _selectedType == ChallengeType.technical ? Icons.sports_soccer : Icons.location_on,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildDropdownField(
                        label: 'Аудиторія *',
                        value: _selectedAudience,
                        items: ChallengeAudience.values,
                        onChanged: (value) {
                          setState(() {
                            _selectedAudience = value!;
                          });
                        },
                        itemBuilder: (audience) => Text(audience == ChallengeAudience.friends ? 'Моїм друзям' : 
                                                      audience == ChallengeAudience.city ? 'Моєму місту' :
                                                      audience == ChallengeAudience.country ? 'Моїй країні' : 'Усьому світу'),
                        icon: _selectedAudience == ChallengeAudience.friends ? '👥' : 
                              _selectedAudience == ChallengeAudience.city ? '🏙️' :
                              _selectedAudience == ChallengeAudience.country ? '🇺🇦' : '🌍',
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Ставка входу
                _buildDropdownField(
                  label: 'Ставка входу *',
                  value: _selectedEntryFee,
                  items: _entryFees,
                  onChanged: (value) {
                    setState(() {
                      _selectedEntryFee = value!;
                    });
                  },
                  itemBuilder: (fee) => Text('$fee монет'),
                  icon: Icons.monetization_on,
                ),
                
                const SizedBox(height: 20),
                
                // Тривалості етапів
                _buildSectionTitle(Icons.schedule, 'Тривалості етапів'),
                const SizedBox(height: 15),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdownField(
                        label: 'Збір учасників *',
                        value: _recruitmentDays,
                        items: _durations,
                        onChanged: (value) {
                          setState(() {
                            _recruitmentDays = value!;
                          });
                        },
                        itemBuilder: (days) => Text('$days дн.'),
                        icon: Icons.people,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDropdownField(
                        label: 'Подання відео *',
                        value: _submissionDays,
                        items: _durations,
                        onChanged: (value) {
                          setState(() {
                            _submissionDays = value!;
                          });
                        },
                        itemBuilder: (days) => Text('$days дн.'),
                        icon: Icons.video_library,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDropdownField(
                        label: 'Голосування *',
                        value: _votingDays,
                        items: [3, 5, 7],
                        onChanged: (value) {
                          setState(() {
                            _votingDays = value!;
                          });
                        },
                        itemBuilder: (days) => Text('$days дн.'),
                        icon: Icons.how_to_vote,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 25),
                
                // Інформація про етапи
                _buildSectionTitle(Icons.schedule, 'Етапи челенджу'),
                const SizedBox(height: 15),
                
                _buildStageInfo(),
                
                const SizedBox(height: 25),
                
                // Призовий фонд розподіл
                _buildSectionTitle(Icons.monetization_on, 'Розподіл призів'),
                const SizedBox(height: 15),
                
                _buildPrizeDistribution(),
                
                const SizedBox(height: 30),
                
                // Кнопка створення
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isCreating ? null : _createChallenge,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9800),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 8,
                    ),
                    child: _isCreating
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.emoji_events, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Створити челендж',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Пояснення
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.white70, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Важливо знати:',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                                                 '• Ліміт: 1 челендж на місяць\n'
                         '• Ставка входу: ${_selectedEntryFee} монет\n'
                         '• Призовий фонд: ${_selectedEntryFee * 20} монет\n'
                         '• 1-е місце: 50% (${(_selectedEntryFee * 20 * 0.5).toInt()} монет)\n'
                         '• 2-е місце: 30% (${(_selectedEntryFee * 20 * 0.3).toInt()} монет)\n'
                         '• 3-є місце: 20% (${(_selectedEntryFee * 20 * 0.2).toInt()} монет)',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.4,
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
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,

          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: TextFormField(
            controller: controller,
            validator: validator,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T value,
    required List<T> items,
    required Function(T?) onChanged,
    required Widget Function(T) itemBuilder,
    required dynamic icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              dropdownColor: Colors.white,
              style: const TextStyle(color: Colors.black87, fontSize: 16),
              items: items.map((item) {
                return DropdownMenuItem<T>(
                  value: item,
                  child: Row(
                    children: [
                      if (icon is IconData) 
                        Icon(icon, size: 20, color: Colors.grey[600])
                      else if (icon is String)
                        Text(icon),
                      const SizedBox(width: 8),
                      Expanded(child: itemBuilder(item)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStageInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          _buildStageItem(Icons.people, 'Збір учасників', '$_recruitmentDays днів', Colors.green),
          const Divider(color: Colors.white24, height: 20),
          _buildStageItem(Icons.video_library, 'Подання відео', '$_submissionDays днів', Colors.orange),
          const Divider(color: Colors.white24, height: 20),
          _buildStageItem(Icons.how_to_vote, 'Голосування', '$_votingDays днів', Colors.blue),
          const Divider(color: Colors.white24, height: 20),
          _buildStageItem(Icons.emoji_events, 'Оголошення переможців', 'Автоматично', Colors.purple),
        ],
      ),
    );
  }

  Widget _buildStageItem(dynamic icon, String title, String duration, Color color) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Center(
            child: icon is IconData 
              ? Icon(icon, size: 18, color: color)
              : Text(
                  icon,
                  style: const TextStyle(fontSize: 18),
                ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                duration,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrizeDistribution() {
    final prizePool = _selectedEntryFee * 20; // Призовий фонд = ставка × 20
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          _buildPrizeItem('🥇', '1-е місце', '50%', (prizePool * 0.5).toInt(), Colors.amber),
          const SizedBox(height: 15),
          _buildPrizeItem('🥈', '2-е місце', '30%', (prizePool * 0.3).toInt(), Colors.grey),
          const SizedBox(height: 15),
          _buildPrizeItem('🥉', '3-є місце', '20%', (prizePool * 0.2).toInt(), Colors.orange),
        ],
      ),
    );
  }

  Widget _buildPrizeItem(String icon, String place, String percentage, int coins, Color color) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Center(
            child: Text(
              icon,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                place,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                percentage,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Text(
            '$coins монет',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _createChallenge() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedVideoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Будь ласка, оберіть відео для челенджу',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Користувач не авторизований');
      }

      // Отримати дані користувача
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      if (!userDoc.exists) {
        throw Exception('Профіль користувача не знайдено');
      }

      final userData = userDoc.data()!;
      final userName = userData['displayName'] ?? userData['name'] ?? 'Невідомий';
      final userCity = userData['city'] ?? _selectedCity;

      // Розрахунок дат з окремими тривалостями
      final now = DateTime.now();
      final startDate = now;
      final submissionDeadline = now.add(Duration(days: _recruitmentDays));
      final votingDeadline = submissionDeadline.add(Duration(days: _submissionDays));
      final endDate = votingDeadline.add(Duration(days: _votingDays));

      // Розрахунок призового фонду
      final prizePool = _selectedEntryFee * 20; // Призовий фонд = ставка × 20

      // Створення челенджу
      final challenge = Challenge(
        id: '', // Буде встановлено Firestore
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        audience: _selectedAudience,
        creatorId: currentUser.uid,
        creatorName: userName,
        city: userCity,
        entryFee: _selectedEntryFee,
        duration: _recruitmentDays,
        createdAt: now,
        startDate: startDate,
        submissionDeadline: submissionDeadline,
        votingDeadline: votingDeadline,
        endDate: endDate,
        status: ChallengeStatus.submission,
        maxParticipants: 100, // Максимум учасників
        currentParticipants: 0,
        prizePool: prizePool.toDouble(),
        participants: [],
        submissions: [],
        votes: {},
        detailedVotes: {},
        winners: [],
        finalScores: {},
        isActive: true,
        tags: _generateTags(),
      );

      final challengeId = await _challengeService.createChallenge(challenge);
      
      if (challengeId != null) {
        // Додаємо створювача як учасника (статус вже правильний)
        await FirebaseFirestore.instance
            .collection('challenges')
            .doc(challengeId)
            .update({
          'participants': FieldValue.arrayUnion([currentUser.uid]),
          'currentParticipants': FieldValue.increment(1),
        });

        // Потім завантажуємо відео створювача
        if (_selectedVideoFile != null) {
          await _uploadCreatorVideo(challengeId, currentUser.uid, userName);
        }
        // Показати повідомлення про успіх та запитати про завантаження відео
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1e7d32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'Челендж створено!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Text(
                _selectedVideoFile != null 
                  ? 'Челендж та ваше відео успішно створені! Тепер інші гравці можуть приєднатися та завантажити свої відео.'
                  : 'Челендж створено! Ви можете додати відео пізніше в деталях челенджу.',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Закрити діалог
                    Navigator.pop(context); // Повернутися назад
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1e7d32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Готово',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      } else {
        throw Exception('Помилка створення челенджу');
      }
    } catch (e) {
      // Показати помилку
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Помилка: ${e.toString()}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }

  List<String> _generateTags() {
    final tags = <String>[];
    
    // Додати тип
    tags.add(_selectedType == ChallengeType.technical ? 'техніка' : 'позиція');
    
    // Додати місто
    tags.add(_selectedCity.toLowerCase());
    
    // Додати теги з назви та опису
    final title = _titleController.text.toLowerCase();
    final description = _descriptionController.text.toLowerCase();
    
    if (title.contains('дриблінг') || description.contains('дриблінг')) {
      tags.add('дриблінг');
    }
    if (title.contains('удар') || description.contains('удар')) {
      tags.add('удари');
    }
    if (title.contains('передача') || description.contains('передача')) {
      tags.add('передачі');
    }
    if (title.contains('воротар') || description.contains('воротар')) {
      tags.add('воротар');
    }
    if (title.contains('захист') || description.contains('захист')) {
      tags.add('захист');
    }
    
    return tags;
  }

  Future<void> _pickVideo({bool fromCamera = false}) async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: fromCamera ? ImageSource.camera : ImageSource.gallery);
    
    if (video != null) {
      setState(() {
        _selectedVideoFile = File(video.path);
      });
    }
  }

  Future<void> _uploadCreatorVideo(String challengeId, String userId, String authorName) async {
    if (_selectedVideoFile == null) return;
    
    try {
      // Завантажуємо відео в Storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'creator_video_$timestamp.mp4';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('videos/$userId/$fileName');
      
      final uploadTask = storageRef.putFile(_selectedVideoFile!);
      final snapshot = await uploadTask;
      final videoUrl = await snapshot.ref.getDownloadURL();
      
      // Зберігаємо відео створювача в submissions і помічаємо як головне
      await FirebaseFirestore.instance
          .collection('challenges')
          .doc(challengeId)
          .collection('submissions')
          .doc(userId)
          .set({
        'userId': userId,
        'authorName': authorName,
        'title': 'Відео створювача',
        'videoUrl': videoUrl,
        'isCreatorVideo': true,
        'createdAt': FieldValue.serverTimestamp(),
        'averageRating': 0.0,
        'voteCount': 0,
        'votes': <String, dynamic>{},
      });
      
      // Додаємо до списку submissions (учасником вже є)
      await FirebaseFirestore.instance
          .collection('challenges')
          .doc(challengeId)
          .update({
        'submissions': FieldValue.arrayUnion([userId]),
      });
      
    } catch (e) {
      print('Error uploading creator video: $e');
    }
  }
}
