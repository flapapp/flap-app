import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flap_app/features/badges/domain/badge_failure.dart';
import 'package:flap_app/features/badges/domain/repositories/badge_repository.dart';
import 'package:flap_app/features/badges/presentation/bloc/badge_store_bloc.dart';
import 'package:flap_app/features/badges/presentation/bloc/badge_store_event.dart';
import 'package:flap_app/features/badges/presentation/bloc/badge_store_state.dart';
import 'package:flap_app/models/badge.dart' as app_badge;
import 'package:flap_app/utils/i18n.dart';

class BadgesStoreScreen extends StatefulWidget {
  const BadgesStoreScreen({super.key});

  @override
  State<BadgesStoreScreen> createState() => _BadgesStoreScreenState();
}

class _BadgesStoreScreenState extends State<BadgesStoreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => BadgeStoreBloc(context.read<BadgeRepository>())
        ..add(const BadgeStoreLoadRequested()),
      child: BlocBuilder<BadgeStoreBloc, BadgeStoreState>(
          builder: (context, state) {
            if (state is BadgeStoreLoading || state is BadgeStoreInitial) {
              return _scaffoldShell(
                context,
                body: const Center(
                  child: CircularProgressIndicator(color: Color(0xFF4caf50)),
                ),
                coins: 0,
              );
            }
            if (state is BadgeStoreFailure) {
              return _scaffoldShell(
                context,
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          state.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => context
                              .read<BadgeStoreBloc>()
                              .add(const BadgeStoreLoadRequested()),
                          child: Text(I18n.inline('Повторити', 'Retry')),
                        ),
                      ],
                    ),
                  ),
                ),
                coins: 0,
              );
            }
            final ready = state as BadgeStoreReady;
            return _scaffoldShell(
              context,
              coins: ready.coins,
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildBadgesGrid(context, ready, ready.allBadges),
                  _buildBadgesGrid(
                    context,
                    ready,
                    _getBadgesByCategory(ready.allBadges, 'starter'),
                  ),
                  _buildBadgesGrid(
                    context,
                    ready,
                    _getBadgesByCategory(ready.allBadges, 'skill'),
                  ),
                  _buildBadgesGrid(
                    context,
                    ready,
                    _getBadgesByCategory(ready.allBadges, 'achievement'),
                  ),
                  _buildBadgesGrid(
                    context,
                    ready,
                    _getBadgesByCategory(ready.allBadges, 'legendary'),
                  ),
                ],
              ),
            );
          },
        ),
    );
  }

  Widget _scaffoldShell(
    BuildContext context, {
    required Widget body,
    required int coins,
  }) {
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
                  coins.toString(),
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
      body: body,
    );
  }

  List<app_badge.Badge> _getBadgesByCategory(
    List<app_badge.Badge> all,
    String category,
  ) {
    return all.where((badge) => badge.category == category).toList();
  }

  Widget _buildBadgesGrid(
    BuildContext context,
    BadgeStoreReady ready,
    List<app_badge.Badge> badges,
  ) {
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
        return _buildBadgeCard(context, ready, badge);
      },
    );
  }

  Widget _buildBadgeCard(
    BuildContext context,
    BadgeStoreReady ready,
    app_badge.Badge badge,
  ) {
    final isOwned = ready.userBadgeIds.contains(badge.id);
    final canAfford = ready.coins >= badge.price;
    final categoryColor = Color(badge.categoryColor);

    return GestureDetector(
      onTap: isOwned ? null : () => _showPurchaseDialog(context, ready, badge),
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
              if (!isOwned) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: canAfford ? () => _showPurchaseDialog(context, ready, badge) : null,
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

  void _showPurchaseDialog(
    BuildContext context,
    BadgeStoreReady ready,
    app_badge.Badge badge,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
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
                          ready.coins.toString(),
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
              if (ready.coins < badge.price) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Недостатньо монет! Потрібно ще ${badge.price - ready.coins} монет.'
                        .i18n('Not enough coins! You need ${badge.price - ready.coins} more.'),
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
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                I18n.t('cancel'),
                style: const TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: ready.coins >= badge.price
                  ? () => _purchaseBadge(context, badge)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: ready.coins >= badge.price
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

  Future<void> _purchaseBadge(BuildContext context, app_badge.Badge badge) async {
    Navigator.pop(context);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF4caf50)),
      ),
    );

    final repo = context.read<BadgeRepository>();
    try {
      await repo.purchaseBadge(badge.id);
      if (!context.mounted) return;
      Navigator.pop(context);

      context.read<BadgeStoreBloc>().add(const BadgeStoreLoadRequested());

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
                    I18n.inline(
                      'Бейдж "${badge.localizedName}" успішно куплено!',
                      'Badge "${badge.localizedName}" purchased successfully!',
                    ),
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
    } on BadgeFailure catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (!context.mounted) return;
      final msg = _messageForBadgeFailure(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  I18n.inline('Помилка покупки: $msg', 'Purchase error: $msg'),
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
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            I18n.inline('Помилка покупки: $e', 'Purchase error: $e'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _messageForBadgeFailure(BadgeFailure e) {
    switch (e.code) {
      case 'not-authenticated':
        return I18n.inline('Увійдіть у систему', 'Sign in required');
      case 'badge-not-found':
        return I18n.inline('Бейдж не знайдено', 'Badge not found');
      case 'badge-unavailable':
        return I18n.inline('Бейдж недоступний', 'Badge unavailable');
      case 'already-owned':
        return I18n.inline('Ви вже маєте цей бейдж', 'You already own this badge');
      case 'profile-not-found':
        return I18n.inline('Профіль не знайдено', 'Profile not found');
      case 'insufficient-coins':
        return I18n.inline('Недостатньо монет', 'Not enough coins');
      default:
        return e.message ?? e.code;
    }
  }
}
