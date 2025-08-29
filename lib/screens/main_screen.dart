import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';
import 'videos_screen.dart';
import 'challenges_screen.dart';
import 'video_upload_screen.dart';
import 'challenge_create_screen.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  final NotificationService _notificationService = NotificationService();
  late TabController _tabController;
  bool _isVideoMode = true; // true = Videos, false = Challenges

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f0f23).withOpacity(0.95),
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.video_library, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'FLAP',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'FEEL LIKE A PRO',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // User chips: coins and rating
          _buildUserChips(),
          // Notifications
          StreamBuilder<int>(
            stream: _notificationService.getUnreadCount(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    tooltip: 'Сповіщення',
                    icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                    onPressed: () => Navigator.pushNamed(context, '/notifications'),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          // Profile button with avatar
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser?.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return IconButton(
                  icon: const Icon(Icons.person, color: Colors.white),
                  onPressed: () => _showProfile(context),
                );
              }

              final userData = snapshot.data!.data() as Map<String, dynamic>;
              final avatarUrl = userData['avatarUrl'] ?? userData['avatar'] ?? '';
              final userName = userData['displayName'] ?? userData['name'] ?? userData['email']?.split('@')[0] ?? 'User';

              return IconButton(
                onPressed: () => _showProfile(context),
                icon: CircleAvatar(
                  radius: 16,
                  backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  backgroundColor: const Color(0xFF4caf50),
                  child: avatarUrl.isEmpty ? Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ) : null,
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(25),
            ),
            child: TabBar(
              controller: _tabController,
              onTap: (index) => setState(() => _isVideoMode = index == 0),
              indicator: BoxDecoration(
                color: const Color(0xFF4caf50),
                borderRadius: BorderRadius.circular(25),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam, size: 20),
                      SizedBox(width: 8),
                      Text('Відео'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emoji_events, size: 20),
                      SizedBox(width: 8),
                      Text('Челенджі'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          VideosScreen(),
          ChallengesScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateOptions,
        backgroundColor: const Color(0xFF4caf50),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // User chips with coins and rating
  Widget _buildUserChips() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final coins = userData['coins'] ?? 0;
        final rating = (userData['rating'] ?? 0.0).toDouble();

        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Coins chip - клікабельний
              GestureDetector(
                onTap: () => _showCoinsHistory(coins),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFffc107).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFffc107), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on, color: Color(0xFFffc107), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        coins.toString(),
                        style: const TextStyle(
                          color: Color(0xFFffc107),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Rating chip - клікабельний
              GestureDetector(
                onTap: () => _showRatingHistory(rating),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4caf50).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF4caf50), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Color(0xFF4caf50), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Color(0xFF4caf50),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCoinsHistory(int currentCoins) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0f0f23),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.monetization_on, color: Color(0xFFffc107), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Мої монети',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Поточний баланс: $currentCoins монет',
                            style: const TextStyle(
                              color: Color(0xFFffc107),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              
              // Purchase coins button
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Implement coin purchase
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🚧 Покупка монет буде доступна незабаром!'),
                        backgroundColor: Color(0xFF4caf50),
                      ),
                    );
                  },
                  icon: const Icon(Icons.shopping_cart),
                  label: const Text('Купити монети'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFffc107),
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),
              
              // Transaction history
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Історія транзакцій',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              // Transactions list
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('transactions')
                      .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                      .orderBy('timestamp', descending: true)
                      .limit(50)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFFffc107)));
                    }
                    
                    final transactions = snapshot.data!.docs;
                    
                    if (transactions.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 64, color: Colors.white54),
                            SizedBox(height: 16),
                            Text(
                              'Поки немає транзакцій',
                              style: TextStyle(color: Colors.white70, fontSize: 16),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final transaction = transactions[index].data() as Map<String, dynamic>;
                        final amount = transaction['amount'] ?? 0;
                        final type = transaction['type'] ?? '';
                        final description = transaction['description'] ?? '';
                        final timestamp = transaction['timestamp'] as Timestamp?;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: amount > 0 
                                      ? const Color(0xFF4caf50).withOpacity(0.2)
                                      : Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  amount > 0 ? Icons.add : Icons.remove,
                                  color: amount > 0 ? const Color(0xFF4caf50) : Colors.red,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      description,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (timestamp != null)
                                      Text(
                                        _formatTransactionTime(timestamp.toDate()),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                '${amount > 0 ? '+' : ''}$amount',
                                style: TextStyle(
                                  color: amount > 0 ? const Color(0xFF4caf50) : Colors.red,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRatingHistory(double currentRating) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0f0f23),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFF4caf50), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Мій рейтинг',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Поточний рейтинг: ${currentRating.toStringAsFixed(1)} ⭐',
                            style: const TextStyle(
                              color: Color(0xFF4caf50),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              
              // Rating info
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4caf50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF4caf50).withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Як формується рейтинг?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Перемоги в челенджах: +0.1-0.5\n'
                        '• Високі оцінки за відео: +0.05-0.2\n'
                        '• Активна участь: +0.01-0.05\n'
                        '• Порушення правил: -0.1-1.0',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Rating history list
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('rating_history')
                      .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                      .orderBy('timestamp', descending: true)
                      .limit(50)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF4caf50)));
                    }
                    
                    final ratingChanges = snapshot.data!.docs;
                    
                    if (ratingChanges.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.timeline, size: 64, color: Colors.white54),
                            SizedBox(height: 16),
                            Text(
                              'Поки немає змін рейтингу',
                              style: TextStyle(color: Colors.white70, fontSize: 16),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Беріть участь у челенджах та отримуйте оцінки\nза свої відео, щоб побачити історію рейтингу',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white54, fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: ratingChanges.length,
                      itemBuilder: (context, index) {
                        final change = ratingChanges[index].data() as Map<String, dynamic>;
                        final ratingChange = (change['change'] ?? 0.0).toDouble();
                        final newRating = (change['newRating'] ?? 0.0).toDouble();
                        final oldRating = (change['oldRating'] ?? 0.0).toDouble();
                        final reason = change['reason'] ?? '';
                        final timestamp = change['timestamp'] as Timestamp?;
                        final challengeTitle = change['challengeTitle'] ?? '';
                        final voterName = change['voterName'] ?? '';
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: ratingChange > 0 
                                      ? const Color(0xFF4caf50).withOpacity(0.2)
                                      : ratingChange < 0
                                          ? Colors.red.withOpacity(0.2)
                                          : Colors.grey.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  ratingChange > 0 
                                      ? Icons.trending_up 
                                      : ratingChange < 0 
                                          ? Icons.trending_down
                                          : Icons.trending_flat,
                                  color: ratingChange > 0 
                                      ? const Color(0xFF4caf50) 
                                      : ratingChange < 0
                                          ? Colors.red
                                          : Colors.grey,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _formatRatingReason(reason, challengeTitle, voterName),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          '${oldRating.toStringAsFixed(1)} → ${newRating.toStringAsFixed(1)}',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.7),
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (timestamp != null)
                                          Text(
                                            _formatTransactionTime(timestamp.toDate()),
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.5),
                                              fontSize: 11,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${ratingChange > 0 ? '+' : ''}${ratingChange.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: ratingChange > 0 
                                      ? const Color(0xFF4caf50) 
                                      : ratingChange < 0
                                          ? Colors.red
                                          : Colors.grey,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTransactionTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 7) {
      // Показуємо точну дату для старих транзакцій
      final months = ['січ', 'лют', 'бер', 'квіт', 'трав', 'черв', 
                     'лип', 'серп', 'вер', 'жовт', 'лист', 'груд'];
      return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} дн. тому';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} год. тому';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} хв. тому';
    } else {
      return 'Щойно';
    }
  }

  String _formatRatingReason(String reason, String challengeTitle, String voterName) {
    switch (reason) {
      case 'challenge_vote':
        return voterName.isNotEmpty 
            ? '$voterName проголосував за ваше відео в "$challengeTitle"'
            : 'Отримано голос за відео в "$challengeTitle"';
      case 'challenge_win':
        return 'Перемога в челенджі "$challengeTitle"';
      case 'challenge_second':
        return '2-е місце в челенджі "$challengeTitle"';
      case 'challenge_third':
        return '3-є місце в челенджі "$challengeTitle"';
      case 'video_rating':
        return 'Оцінка за відео від користувача';
      case 'penalty':
        return 'Штраф за порушення правил';
      case 'bonus':
        return 'Бонус за активність';
      default:
        return reason.isNotEmpty ? reason : 'Зміна рейтингу';
    }
  }

  Future<void> _ensureTestTransactions() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Перевіряємо чи є транзакції
      final existingTransactions = await FirebaseFirestore.instance
          .collection('transactions')
          .where('userId', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      if (existingTransactions.docs.isEmpty) {
        // Створюємо тестові транзакції
        final batch = FirebaseFirestore.instance.batch();
        final now = DateTime.now();

        // Тестові транзакції
        final testTransactions = [
          {
            'userId': currentUser.uid,
            'type': 'initial_bonus',
            'amount': 100,
            'timestamp': Timestamp.fromDate(now.subtract(const Duration(days: 7))),
            'description': 'Початковий бонус за реєстрацію',
          },
          {
            'userId': currentUser.uid,
            'type': 'challenge_entry_fee',
            'amount': -10,
            'timestamp': Timestamp.fromDate(now.subtract(const Duration(days: 3))),
            'description': 'Вступна плата за челендж: Найкрутіший пас',
          },
          {
            'userId': currentUser.uid,
            'type': 'voting_reward',
            'amount': 5,
            'timestamp': Timestamp.fromDate(now.subtract(const Duration(days: 2))),
            'description': 'Нагорода за голосування в челенджах',
          },
          {
            'userId': currentUser.uid,
            'type': 'challenge_win',
            'amount': 50,
            'timestamp': Timestamp.fromDate(now.subtract(const Duration(days: 1))),
            'description': 'Перемога в челенджі: Гол зацінить',
          },
          {
            'userId': currentUser.uid,
            'type': 'badge_purchase',
            'amount': -25,
            'timestamp': Timestamp.fromDate(now.subtract(const Duration(hours: 12))),
            'description': 'Покупка значка: Майстер техніки',
          },
        ];

        for (final transaction in testTransactions) {
          final docRef = FirebaseFirestore.instance.collection('transactions').doc();
          batch.set(docRef, transaction);
        }

        await batch.commit();
        print('✅ Test transactions created');
      }
    } catch (e) {
      print('❌ Error creating test transactions: $e');
    }
  }

  Future<void> _ensureTestRatingHistory() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Перевіряємо чи є історія рейтингу
      final existingRatingHistory = await FirebaseFirestore.instance
          .collection('rating_history')
          .where('userId', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      if (existingRatingHistory.docs.isEmpty) {
        // Створюємо тестову історію рейтингу
        final batch = FirebaseFirestore.instance.batch();
        final now = DateTime.now();

        final testRatingChanges = [
          {
            'userId': currentUser.uid,
            'change': 0.15,
            'oldRating': 3.0,
            'newRating': 3.15,
            'reason': 'challenge_vote',
            'challengeTitle': 'Найкрутіший пас',
            'voterName': 'Leo Messi',
            'timestamp': Timestamp.fromDate(now.subtract(const Duration(days: 5))),
          },
          {
            'userId': currentUser.uid,
            'change': 0.25,
            'oldRating': 3.15,
            'newRating': 3.40,
            'reason': 'challenge_win',
            'challengeTitle': 'Гол зацінить',
            'voterName': '',
            'timestamp': Timestamp.fromDate(now.subtract(const Duration(days: 3))),
          },
          {
            'userId': currentUser.uid,
            'change': 0.10,
            'oldRating': 3.40,
            'newRating': 3.50,
            'reason': 'challenge_vote',
            'challengeTitle': 'Дриблінг через конуси',
            'voterName': 'Vinnie Jr',
            'timestamp': Timestamp.fromDate(now.subtract(const Duration(days: 1))),
          },
          {
            'userId': currentUser.uid,
            'change': -0.05,
            'oldRating': 3.50,
            'newRating': 3.45,
            'reason': 'challenge_vote',
            'challengeTitle': 'Технічний удар',
            'voterName': 'Cristiano',
            'timestamp': Timestamp.fromDate(now.subtract(const Duration(hours: 6))),
          },
        ];

        for (final ratingChange in testRatingChanges) {
          final docRef = FirebaseFirestore.instance.collection('rating_history').doc();
          batch.set(docRef, ratingChange);
        }

        await batch.commit();
        print('✅ Test rating history created');
      }
    } catch (e) {
      print('❌ Error creating test rating history: $e');
    }
  }

  void _showCreateOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0f0f23),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              
              Text(
                'Створити контент',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              
              // Create Video
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.videocam, color: Color(0xFF2196F3)),
                ),
                title: const Text(
                  'Створити відео',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Завантажте своє футбольне відео',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => VideoUploadScreen()),
                  );
                },
              ),
              
              const SizedBox(height: 8),
              
              // Create Challenge
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4caf50).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.emoji_events, color: Color(0xFF4caf50)),
                ),
                title: const Text(
                  'Створити челендж',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Запросіть інших на змагання',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ChallengeCreateScreen()),
                  );
                },
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showProfile(BuildContext context) {
    Navigator.pushNamed(context, '/profile');
  }
}



