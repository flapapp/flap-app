import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/di/injection.dart';
import '../../domain/repositories/badges_repository.dart';
import '../../data/models/badge.dart' as app_badge;
import 'package:flap_app/core/auth/app_auth.dart';
import 'package:flap_app/core/supabase/coin_ledger.dart';
import 'package:flap_app/theme/flap_tokens.dart';
import 'package:flap_app/widgets/flap/flap_kit.dart';
import 'package:flap_app/features/badges/presentation/badge_icon.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
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

      final currentUser = AppAuth.currentUser;
      if (currentUser != null) {
        await _badgesRepo.initializeDefaultBadges();

        final results = await Future.wait([
          _badgesRepo.getAvailableBadges().first,
          _badgesRepo.getUserBadgeIds(currentUser.id),
          coinBalance(Supabase.instance.client, currentUser.id),
        ]);

        final badges = results[0] as List<app_badge.Badge>;
        final userBadges = results[1] as List<String>;
        final coins = results[2] as int;

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
      backgroundColor: FlapColors.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: FlapColors.screenGlow),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildAppBar(),
              _buildTabs(),
              const SizedBox(height: 4),
              Expanded(
                child: _isLoading
                    ? const FlapLoadingGrid(
                        itemCount: 6,
                        crossAxisCount: 2,
                        childAspectRatio: 0.66,
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                        radius: 20,
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildBadgesGrid(_allBadges),
                          _buildBadgesGrid(_getBadgesByCategory('starter')),
                          _buildBadgesGrid(_skillTabBadges()),
                          _buildBadgesGrid(_getBadgesByCategory('achievement')),
                          _buildBadgesGrid(_getBadgesByCategory('legendary')),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          _glassButton(
            icon: Icons.chevron_left,
            iconSize: 19,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tr('il_7e02e138e6'),
              style: FlapText.sora(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: FlapColors.text,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          // Coin balance pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: FlapColors.gold.withOpacity(0.13),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: FlapColors.gold.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on_rounded,
                    color: FlapColors.gold, size: 16),
                const SizedBox(width: 5),
                Text(
                  _userCoins.toString(),
                  style: FlapText.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: FlapColors.gold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassButton({
    required IconData icon,
    required VoidCallback onTap,
    double iconSize = 19,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: FlapColors.surface2,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: FlapColors.border),
        ),
        child: Icon(icon, color: FlapColors.text, size: iconSize),
      ),
    );
  }

  Widget _buildTabs() {
    final labels = [
      tr('badge_tab_all'),
      tr('badge_tab_starter'),
      tr('badge_tab_skills'),
      tr('badge_tab_achievements'),
      tr('badge_tab_legendary'),
    ];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final active = _tabController.index == index;
          return GestureDetector(
            onTap: () => _tabController.animateTo(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: active
                    ? FlapColors.green.withOpacity(0.16)
                    : FlapColors.surface,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: active
                      ? FlapColors.green.withOpacity(0.55)
                      : FlapColors.border,
                ),
              ),
              child: Text(
                labels[index],
                style: FlapText.sora(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  color: active ? FlapColors.greenBright : FlapColors.muted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<app_badge.Badge> _getBadgesByCategory(String category) {
    return _allBadges.where((badge) => badge.category == category).toList();
  }

  List<app_badge.Badge> _skillTabBadges() {
    final skills = _allBadges
        .where((b) => app_badge.Badge.isSkillKindCategory(b.category))
        .toList(growable: false);
    final sorted = List<app_badge.Badge>.from(skills);
    sorted.sort(
      (a, b) => a.localizedName.toLowerCase().compareTo(
            b.localizedName.toLowerCase(),
          ),
    );
    return sorted;
  }

  Widget _buildBadgesGrid(List<app_badge.Badge> badges) {
    if (badges.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: FlapColors.green.withOpacity(0.10),
                shape: BoxShape.circle,
                border: Border.all(color: FlapColors.green.withOpacity(0.35)),
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                size: 38,
                color: FlapColors.greenBright,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tr('badges_category_empty'),
              style: FlapText.sora(
                color: FlapColors.muted,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: FlapColors.green,
      backgroundColor: FlapColors.card,
      onRefresh: _loadData,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.66,
        ),
        itemCount: badges.length,
        itemBuilder: (context, index) {
          final badge = badges[index];
          return _buildBadgeCard(badge);
        },
      ),
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
          color: FlapColors.card,
          borderRadius: BorderRadius.circular(FlapRadii.card),
          border: Border.all(
            color: isOwned
                ? FlapColors.green.withOpacity(0.6)
                : FlapColors.border,
            width: isOwned ? 1.4 : 1,
          ),
          boxShadow: isOwned
              ? [
                  BoxShadow(
                    color: FlapColors.green.withOpacity(0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Badge medallion + owned check
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          categoryColor.withOpacity(0.28),
                          categoryColor.withOpacity(0.10),
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: categoryColor.withOpacity(0.55),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: flapBadgeGlyph(badge.emoji, size: 28),
                    ),
                  ),
                  if (isOwned)
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: FlapColors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: FlapColors.card, width: 2),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: FlapColors.onGreen,
                          size: 13,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Badge info
              Column(
                children: [
                  Text(
                    badge.localizedName,
                    style: FlapText.sora(
                      color: FlapColors.text,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    badge.localizedDescription,
                    style: FlapText.sora(
                      color: FlapColors.muted,
                      fontSize: 11.5,
                      height: 1.25,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(7),
                      border:
                          Border.all(color: categoryColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      badge.rarityText.toUpperCase(),
                      style: FlapText.sora(
                        color: categoryColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Price / status button
              if (!isOwned)
                _priceButton(badge, canAfford)
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: FlapColors.green.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: FlapColors.green.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: FlapColors.greenBright, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        tr('badge_chip_purchased'),
                        style: FlapText.sora(
                          color: FlapColors.greenBright,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _priceButton(app_badge.Badge badge, bool canAfford) {
    return GestureDetector(
      onTap: canAfford ? () => _showPurchaseDialog(badge) : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          gradient: canAfford ? FlapColors.primaryButton : null,
          color: canAfford ? null : FlapColors.surface2,
          borderRadius: BorderRadius.circular(10),
          border: canAfford
              ? null
              : Border.all(color: FlapColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.monetization_on_rounded,
              size: 15,
              color: canAfford ? FlapColors.onGreen : FlapColors.muted,
            ),
            const SizedBox(width: 5),
            Text(
              '${badge.price}',
              style: FlapText.sora(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: canAfford ? FlapColors.onGreen : FlapColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPurchaseDialog(app_badge.Badge badge) {
    final categoryColor = Color(badge.categoryColor);
    final canAfford = _userCoins >= badge.price;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: FlapColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FlapRadii.card),
            side: const BorderSide(color: FlapColors.borderStrong),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            categoryColor.withOpacity(0.28),
                            categoryColor.withOpacity(0.10),
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: categoryColor.withOpacity(0.55),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: flapBadgeGlyph(badge.emoji, size: 26),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            badge.localizedName,
                            style: FlapText.sora(
                              color: FlapColors.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            badge.rarityText.toUpperCase(),
                            style: FlapText.sora(
                              color: categoryColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  badge.localizedDescription,
                  style: FlapText.sora(
                    color: FlapColors.muted,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                _dialogStatRow(tr('price_label'), badge.price.toString()),
                const SizedBox(height: 8),
                _dialogStatRow(
                    tr('your_balance_label'), _userCoins.toString()),
                if (!canAfford) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: FlapColors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: FlapColors.red.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: FlapColors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tr(
                              'badge_insufficient_coins',
                              namedArgs: {
                                'amount': '${badge.price - _userCoins}',
                              },
                            ),
                            style: FlapText.sora(
                              color: FlapColors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: FlapColors.surface2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: FlapColors.border),
                          ),
                          child: Text(
                            tr('cancel'),
                            style: FlapText.sora(
                              color: FlapColors.muted,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: canAfford ? () => _purchaseBadge(badge) : null,
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient:
                                canAfford ? FlapColors.primaryButton : null,
                            color: canAfford ? null : FlapColors.surface2,
                            borderRadius: BorderRadius.circular(12),
                            border: canAfford
                                ? null
                                : Border.all(color: FlapColors.border),
                          ),
                          child: Text(
                            tr('badge_store_buy'),
                            style: FlapText.sora(
                              color: canAfford
                                  ? FlapColors.onGreen
                                  : FlapColors.muted,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dialogStatRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: FlapColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlapColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: FlapText.sora(
              color: FlapColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            children: [
              const Icon(Icons.monetization_on_rounded,
                  color: FlapColors.gold, size: 18),
              const SizedBox(width: 5),
              Text(
                value,
                style: FlapText.sora(
                  color: FlapColors.gold,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _purchaseBadge(app_badge.Badge badge) async {
    try {
      Navigator.pop(context); // Close the dialog

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: FlapColors.green),
        ),
      );

      // Purchase the badge
      await _badgesRepo.purchaseBadge(badge.id);

      Navigator.pop(context); // Close loading indicator

      // Refresh data
      await _loadData();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              flapBadgeGlyph(badge.emoji, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr('il_f9ef28036b', args: [badge.name]),
                  style: FlapText.sora(
                    color: FlapColors.onGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: FlapColors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading indicator on error

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr('il_baad69c3af', args: [e.toString()]),
                  style: FlapText.sora(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: FlapColors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}
