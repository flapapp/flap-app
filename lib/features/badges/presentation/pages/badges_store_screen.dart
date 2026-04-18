import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../domain/repositories/badges_repository.dart';
import '../../../../router/app_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/badge.dart' as app_badge;
import '../../../../utils/i18n.dart';

@RoutePage()
class BadgesStoreScreen extends StatefulWidget {
  @override
  _BadgesStoreScreenState createState() => _BadgesStoreScreenState();
}

class _BadgesStoreScreenState extends State<BadgesStoreScreen>
    with SingleTickerProviderStateMixin {
  BadgesRepository get _badgesRepo => sl<BadgesRepository>();

  late TabController _tabController;
  List<app_badge.Badge> _allBadges = [];
  List<String> _userBadges = [];
  int _userCoins = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await _badgesRepo.initializeDefaultBadges();

        final results = await Future.wait([
          _badgesRepo.getAvailableBadges().first,
          _badgesRepo.getUserBadgeIds(currentUser.uid),
          FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get(),
        ]);

        final badges = results[0] as List<app_badge.Badge>;
        final userBadges = results[1] as List<String>;
        final userDoc = results[2] as DocumentSnapshot<Map<String, dynamic>>;
        final userData = userDoc.data() ?? {};
        final coins = userData['coins'] ?? 0;
        
        setState(() {
          _allBadges = badges;
          _userBadges = userBadges;
          _userCoins = coins;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading badges data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f0f23),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFF4caf50), size: 24),
            const SizedBox(width: 8),
            Text(
              I18n.inline('Додати скіли', 'Add skills'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Показуємо поточний баланс монет
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFffc107).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFffc107)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on, color: Color(0xFFffc107), size: 16),
                const SizedBox(width: 4),
                Text(
                  _userCoins.toString(),
                  style: const TextStyle(
                    color: Color(0xFFffc107),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: const Color(0xFF4caf50),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(text: 'Всі'.i18n('All')),
            Tab(text: 'Початкові'.i18n('Starter')),
            Tab(text: 'Навички'.i18n('Skills')),
            Tab(text: 'Досягнення'.i18n('Achievements')),
            Tab(text: 'Легендарні'.i18n('Legendary')),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4caf50)),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBadgesGrid(_allBadges),
                _buildBadgesGrid(_getBadgesByCategory('starter')),
                _buildBadgesGrid(_getBadgesByCategory('skill')),
                _buildBadgesGrid(_getBadgesByCategory('achievement')),
                _buildBadgesGrid(_getBadgesByCategory('legendary')),
              ],
            ),
    );
  }

  List<app_badge.Badge> _getBadgesByCategory(String category) {
    return _allBadges.where((badge) => badge.category == category).toList();
  }

  Widget _buildBadgesGrid(List<app_badge.Badge> badges) {
    if (badges.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.emoji_events_outlined,
              size: 64,
              color: Colors.white30,
            ),
            const SizedBox(height: 16),
            Text(
              'Немає бейджів у цій категорії'.i18n('No badges in this category'),
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.68,
      ),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        final badge = badges[index];
        return _buildBadgeCard(badge);
      },
    );
  }

  Widget _buildBadgeCard(app_badge.Badge badge) {
    final isOwned = _userBadges.contains(badge.id);
    final canAfford = _userCoins >= badge.price;
    final categoryColor = Color(badge.categoryColor);

    return GestureDetector(
      onTap: isOwned ? null : () => _showPurchaseDialog(badge),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOwned 
                ? const Color(0xFF4caf50) 
                : canAfford 
                    ? categoryColor.withOpacity(0.5)
                    : Colors.white.withOpacity(0.1),
            width: isOwned ? 2 : 1,
          ),
          boxShadow: isOwned
              ? [
                  BoxShadow(
                    color: const Color(0xFF4caf50).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Badge emoji and status
              Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: categoryColor.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        badge.emoji,
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                  ),
                  if (isOwned) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4caf50),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'МАЄТЕ'.i18n('OWNED'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              
              // Badge info
              Column(
                children: [
                  ValueListenableBuilder<String>(
                    valueListenable: I18n.language,
                    builder: (context, _, __) => Text(
                      badge.localizedName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ValueListenableBuilder<String>(
                    valueListenable: I18n.language,
                    builder: (context, _, __) => Text(
                      badge.localizedDescription,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: categoryColor.withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      badge.rarityText,
                      style: TextStyle(
                        color: categoryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              
              // Price and purchase button
              if (!isOwned) ...[
                Container(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: canAfford ? () => _showPurchaseDialog(badge) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canAfford 
                          ? const Color(0xFF4caf50) 
                          : Colors.grey.withOpacity(0.3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.monetization_on,
                          size: 16,
                          color: canAfford ? Colors.white : Colors.white54,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${badge.price}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: canAfford ? Colors.white : Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4caf50).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF4caf50)),
                  ),
                  child: Text(
                    '✓ КУПЛЕНО'.i18n('✓ PURCHASED'),
                    style: const TextStyle(
                      color: Color(0xFF4caf50),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showPurchaseDialog(app_badge.Badge badge) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Text(
                badge.emoji,
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ValueListenableBuilder<String>(
                      valueListenable: I18n.language,
                      builder: (context, _, __) => Text(
                        badge.localizedName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ValueListenableBuilder<String>(
                      valueListenable: I18n.language,
                      builder: (context, _, __) => Text(
                        badge.rarityText,
                        style: TextStyle(
                          color: Color(badge.categoryColor),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<String>(
                valueListenable: I18n.language,
                builder: (context, _, __) => Text(
                  badge.localizedDescription,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ціна:'.i18n('Price:'),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.monetization_on,
                          color: Color(0xFFffc107),
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${badge.price}',
                          style: const TextStyle(
                            color: Color(0xFFffc107),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ваш баланс:'.i18n('Your balance:'),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.monetization_on,
                          color: Color(0xFFffc107),
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _userCoins.toString(),
                          style: const TextStyle(
                            color: Color(0xFFffc107),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_userCoins < badge.price) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Недостатньо монет! Потрібно ще ${badge.price - _userCoins} монет.'
                        .i18n('Not enough coins! You need ${badge.price - _userCoins} more.'),
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                I18n.t('cancel'),
                style: const TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: _userCoins >= badge.price ? () => _purchaseBadge(badge) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _userCoins >= badge.price 
                    ? const Color(0xFF4caf50) 
                    : Colors.grey,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Купити'.i18n('Buy'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _purchaseBadge(app_badge.Badge badge) async {
    try {
      Navigator.pop(context); // Закриваємо діалог
      
      // Показуємо індикатор завантаження
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF4caf50)),
        ),
      );
      
      // Купуємо бейдж
      await _badgesRepo.purchaseBadge(badge.id);
      
      Navigator.pop(context); // Закриваємо індикатор
      
      // Оновлюємо дані
      await _loadData();
      
      // Показуємо повідомлення про успіх
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Text(badge.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: I18n.language,
                  builder: (context, _, __) => Text(
                    I18n.inline('Бейдж "${badge.localizedName}" успішно куплено!', 'Badge "${badge.localizedName}" purchased successfully!'),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF4caf50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Закриваємо індикатор якщо є помилка
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  I18n.inline('Помилка покупки: ${e.toString()}', 'Purchase error: ${e.toString()}'),
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
    }
  }
}
