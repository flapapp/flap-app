import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:typed_data';

class ModeSelectionScreen extends StatefulWidget {
  @override
  _ModeSelectionScreenState createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userStream;

  final List<Map<String, String>> _greetings = [
    {
      'greeting': 'Вітаю, Олександр! 👋',
      'rating': 'Ваш рейтинг: 4.2 • 45 матчів зіграно',
      'instruction': 'Оберіть режим роботи для початку гри'
    },
    {
      'greeting': 'Готовий до нових викликів? 🔥',
      'rating': 'Твій рейтинг: 4.2 • Відмінний результат! ',
      'instruction': 'Обери свій шлях до перемоги'
    },
    {
      'greeting': 'Привіт, чемпіоне! 🏆',
      'rating': 'Рейтинг: 4.2 з 5.0 • Продовжуй у тому ж дусі!',
      'instruction': 'Що сьогодні будемо робити?'
    },
    {
      'greeting': 'Доброго дня, майстре! ⚡',
      'rating': 'Твої досягнення: 4.2 • Ти на правильному шляху',
      'instruction': 'Вибери напрямок для розвитку'
    },
    {
      'greeting': 'З поверненням, легендо! 🌟',
      'rating': 'Статистика: 4.2 рейтинг • 45 ігор',
      'instruction': 'Куди спрямуємо твою енергію?'
    },
  ];

  String _currentGreeting = '';
  String _currentRatingText = '';
  String _currentInstruction = '';

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _userStream =
          FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
    }
    _updateGreeting();
  }

  void _updateGreeting() {
    final idx = DateTime.now().millisecondsSinceEpoch % _greetings.length;
    final g = _greetings[idx];
    setState(() {
      _currentGreeting = g['greeting'] ?? '';
      _currentRatingText = g['rating'] ?? '';
      _currentInstruction = g['instruction'] ?? '';
    });
  }

  Widget _avatarFromUrl(String? url) {
    if (url == null || url.isEmpty) {
      return const Icon(Icons.person, size: 40, color: Color(0xFF6a1b9a));
    }
    
    // Спрощений підхід - використовуємо URL безпосередньо
    return _buildAvatarImage(url);
  }

  Widget _buildAvatarImage(String url) {
    return Image.network(
      url,
      key: ValueKey(url),
      fit: BoxFit.cover,
      errorBuilder: (_, err, __) {
        print('Network avatar error: $err');
        return const Icon(Icons.person, size: 40, color: Color(0xFF6a1b9a));
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6a1b9a)),
        );
      },
    );
  }


  Widget _buildFallbackIcon() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(40),
      ),
      child: const Icon(Icons.person, size: 40, color: Color(0xFF6a1b9a)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1e7d32),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _updateGreeting,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(40),
                          child: StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>>(
                            stream: _userStream,
                            builder: (context, snapshot) {
                              print(
                                  'user doc: state=${snapshot.connectionState} hasData=${snapshot.hasData} exists=${snapshot.data?.exists}');
                              
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6a1b9a)),
                                );
                              }
                              
                              if (snapshot.hasError) {
                                print('StreamBuilder error: ${snapshot.error}');
                                return const Icon(Icons.person, size: 40, color: Color(0xFF6a1b9a));
                              }
                              
                              if (!snapshot.hasData || !snapshot.data!.exists) {
                                print('No user data found');
                                return const Icon(Icons.person, size: 40, color: Color(0xFF6a1b9a));
                              }
                              
                              final data = snapshot.data!.data();
                              if (data == null) {
                                print('User data is null');
                                return const Icon(Icons.person, size: 40, color: Color(0xFF6a1b9a));
                              }
                              
                              final avatarUrl = data['avatarUrl'] as String?;
                              print('avatarUrl on mode: $avatarUrl');
                              
                              if (avatarUrl == null || avatarUrl.isEmpty) {
                                print('No avatar URL found');
                                return const Icon(Icons.person, size: 40, color: Color(0xFF6a1b9a));
                              }
                              
                              return _avatarFromUrl(avatarUrl);
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    // Відображення імені користувача
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: _userStream,
                      builder: (context, snapshot) {
                                                 if (snapshot.hasData && snapshot.data!.exists) {
                           final data = snapshot.data!.data();
                           final displayName = data?['authorName'] ?? data?['displayName'] ?? 'Гравець';
                          return Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          );
                        }
                        return const Text(
                          'Гравець',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _currentGreeting,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentRatingText,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _currentInstruction,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Відео
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/video-main'),
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    // Відповідно до MVP: відео секція має теплий (червоний/оранжевий) градієнт
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B6B), Color(0xFFEE5A24)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.video_library, size: 30, color: Colors.white),
                            SizedBox(width: 15),
                                                     Text(
                           'ВІДЕО',
                           style: TextStyle(
                             fontSize: 32,
                             fontWeight: FontWeight.bold,
                             color: Colors.white,
                           ),
                         ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Створюй контент, приймай челенджі та показуй свої навички',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: const [
                            _FunctionItem(Icons.cloud_upload, 'Завантаження'),
                            _FunctionItem(Icons.emoji_events, 'Челенджі'),
                            _FunctionItem(Icons.how_to_vote, 'Голосування'),
                            _FunctionItem(Icons.comment, 'Коментарі'),
                            _FunctionItem(Icons.star, 'Рейтинг'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Матчі
              GestureDetector(
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Режим Матчі')),
                ),
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    // Відповідно до MVP: матчі секція має зелений градієнт
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.sports_soccer, size: 30, color: Colors.white),
                            SizedBox(width: 15),
                                                     Text(
                           'МАТЧІ',
                           style: TextStyle(
                             fontSize: 32,
                             fontWeight: FontWeight.bold,
                             color: Colors.white,
                           ),
                         ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Знаходь гравців, створюй команди та грай у живому футболі',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: const [
                            _FunctionItem(Icons.search, 'Пошук'),
                            _FunctionItem(Icons.add, 'Створення'),
                            _FunctionItem(Icons.balance, 'Баланс'),
                            _FunctionItem(Icons.bar_chart, 'Рейтинг'),
                            _FunctionItem(Icons.people, 'Друзі'),
                          ],
                        ),
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
}

class _FunctionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FunctionItem(this.icon, this.label, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.white),
        const SizedBox(height: 5),
        Text(
          label,
          style:
              TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.8)),
        ),
      ],
    );
  }
}