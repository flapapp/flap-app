import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/di/injection.dart';
import '../../../../theme/flap_tokens.dart';
import '../../data/models/subscription.dart';
import '../../domain/repositories/subscriptions_repository.dart';
import 'package:flap_app/core/auth/app_auth.dart';

@RoutePage()
class SubscriptionScreen extends StatefulWidget {
  @override
  _SubscriptionScreenState createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  SubscriptionsRepository get _subscriptionsRepo => sl<SubscriptionsRepository>();
  Subscription? _currentSubscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentSubscription();
  }

  Future<void> _loadCurrentSubscription() async {
    try {
      setState(() => _isLoading = true);
      final userId = AppAuth.currentUserId;
      if (userId != null) {
        final subscription = await _subscriptionsRepo.getUserSubscription(userId);
        setState(() {
          _currentSubscription = subscription;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading subscription: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlapColors.bg,
      appBar: AppBar(
        backgroundColor: FlapColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 66,
        leadingWidth: 60,
        titleSpacing: 0,
        leading: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: FlapColors.surface2,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: FlapColors.border),
                ),
                child: const Icon(Icons.chevron_left,
                    color: FlapColors.text, size: 19),
              ),
            ),
          ),
        ),
        title: Text(
          tr('il_a151f2e912'),
          style: FlapText.sora(fontSize: 19, fontWeight: FontWeight.w800),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: FlapColors.screenGlow),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: FlapColors.green),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current subscription status
                    if (_currentSubscription != null) ...[
                      _buildCurrentSubscriptionCard(),
                      const SizedBox(height: 24),
                    ],

                    // Available plans
                    Text(
                      tr('il_20efa44d56'),
                      style: FlapText.cond(
                          fontSize: 24, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),

                    _buildSubscriptionPlan(SubscriptionType.free),
                    const SizedBox(height: 14),
                    _buildSubscriptionPlan(SubscriptionType.europa),
                    const SizedBox(height: 14),
                    _buildSubscriptionPlan(SubscriptionType.champions),

                    const SizedBox(height: 26),

                    // Disclaimer
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: FlapColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: FlapColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline,
                                  color: FlapColors.muted, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                tr('il_ce20f737bb'),
                                style: FlapText.sora(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tr('subscriptions_policy_bullets'),
                            style: FlapText.sora(
                                fontSize: 12.5,
                                color: FlapColors.muted,
                                height: 1.5),
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

  Widget _buildCurrentSubscriptionCard() {
    final subscription = _currentSubscription!;
    final isActive = subscription.isActive;
    final isInTrial = subscription.isInTrial;
    final daysLeft = subscription.endDate.difference(DateTime.now()).inDays;
    final daysLeftLabel = daysLeft < 0 ? 0 : daysLeft;

    final onGrad = FlapColors.onGreen;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isActive ? FlapColors.primaryButton : null,
        color: isActive ? null : FlapColors.card,
        borderRadius: BorderRadius.circular(20),
        border: isActive
            ? null
            : Border.all(color: FlapColors.borderStrong),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: FlapColors.green.withValues(alpha: 0.30),
                  blurRadius: 22,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (isActive ? onGrad : FlapColors.gold)
                      .withValues(alpha: isActive ? 0.16 : 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isInTrial
                      ? Icons.card_giftcard_rounded
                      : Icons.workspace_premium_rounded,
                  color: isActive ? onGrad : FlapColors.gold,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isInTrial ? tr('il_ca3e67a0a1') : tr('il_4e761d178e'),
                      style: FlapText.sora(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isActive
                              ? onGrad.withValues(alpha: 0.8)
                              : FlapColors.muted),
                    ),
                    Text(
                      subscription.name,
                      style: FlapText.cond(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: isActive ? onGrad : FlapColors.text),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: isActive
                      ? onGrad.withValues(alpha: 0.18)
                      : FlapColors.muted.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  isActive ? tr('il_630c2f1c0e') : tr('il_df343bd4f0'),
                  style: FlapText.sora(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isActive ? onGrad : FlapColors.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isActive) ...[
            Row(
              children: [
                Icon(Icons.schedule_rounded,
                    color: onGrad.withValues(alpha: 0.85), size: 15),
                const SizedBox(width: 6),
                Text(
                  tr('il_83e2b2a115', args: ['$daysLeftLabel']),
                  style: FlapText.sora(fontSize: 13, color: onGrad),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Text(
            subscription.description,
            style: FlapText.sora(
                fontSize: 13,
                color: isActive
                    ? onGrad.withValues(alpha: 0.92)
                    : FlapColors.muted),
          ),
          if (subscription.type != SubscriptionType.free) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _cancelSubscription,
              child: Container(
                width: double.infinity,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isActive
                      ? onGrad.withValues(alpha: 0.14)
                      : FlapColors.red.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: isActive
                        ? onGrad.withValues(alpha: 0.4)
                        : FlapColors.red.withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  tr('il_3f85967f7f'),
                  style: FlapText.sora(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isActive ? onGrad : FlapColors.red),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubscriptionPlan(SubscriptionType type) {
    final subscription = Subscription(
      id: '',
      userId: '',
      type: type,
      status: SubscriptionStatus.active,
      startDate: DateTime.now(),
      endDate: DateTime.now(),
      price: 0,
      features: {},
    );

    final isCurrentPlan = _currentSubscription?.type == type;
    final canUpgrade = _currentSubscription != null &&
                       _currentSubscription!.type.index < type.index;

    final planColor = _getPlanColor(type);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: FlapColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrentPlan
              ? FlapColors.green.withValues(alpha: 0.6)
              : FlapColors.borderStrong,
          width: isCurrentPlan ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: planColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: planColor.withValues(alpha: 0.4)),
                ),
                child: Icon(_getPlanIcon(type), color: planColor, size: 25),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subscription.name,
                      style: FlapText.cond(
                          fontSize: 21, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      subscription.description,
                      style: FlapText.sora(
                          fontSize: 12.5, color: FlapColors.muted),
                    ),
                  ],
                ),
              ),
              if (subscription.monthlyPrice > 0) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${subscription.monthlyPrice}₴',
                      style: FlapText.cond(
                          fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      tr('il_88b1d1a67e'),
                      style: FlapText.sora(
                          fontSize: 11, color: FlapColors.muted),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: FlapColors.green.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: FlapColors.green.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    tr('il_19f1fa5ec9'),
                    style: FlapText.sora(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: FlapColors.greenBright),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 18),

          // Features list
          ...subscription.featuresList.map((feature) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded, color: planColor, size: 16),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      feature,
                      style: FlapText.sora(
                          fontSize: 13, color: FlapColors.text, height: 1.3),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 14),

          // Action buttons
          if (isCurrentPlan) ...[
            Container(
              width: double.infinity,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: FlapColors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
                border:
                    Border.all(color: FlapColors.green.withValues(alpha: 0.45)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_rounded,
                      color: FlapColors.greenBright, size: 17),
                  const SizedBox(width: 7),
                  Text(
                    tr('il_c382511dcd'),
                    style: FlapText.sora(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: FlapColors.greenBright),
                  ),
                ],
              ),
            ),
          ] else if (type == SubscriptionType.free) ...[
            const SizedBox.shrink(),
          ] else if (type == SubscriptionType.champions &&
                     subscription.isTrialAvailable &&
                     (_currentSubscription?.trialEndDate == null)) ...[
            _planButton(
              label: tr('il_6ce93ecadf'),
              onTap: () => _startTrial(),
              color: FlapColors.gold,
            ),
            const SizedBox(height: 8),
            _planButton(
              label: tr('il_85b6ac87d3'),
              onTap: () => _purchaseSubscription(type),
              gradient: true,
            ),
          ] else if (canUpgrade || type != SubscriptionType.free) ...[
            _planButton(
              label: canUpgrade ? tr('il_4e04dd7931') : tr('il_f75cc7ae4b'),
              onTap: () => _purchaseSubscription(type),
              gradient: true,
            ),
          ],
        ],
      ),
    );
  }

  /// Plan CTA: gradient (primary) or a solid accent-tinted color button.
  Widget _planButton({
    required String label,
    required VoidCallback onTap,
    bool gradient = false,
    Color? color,
  }) {
    final solid = color ?? FlapColors.green;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: gradient ? FlapColors.primaryButton : null,
          color: gradient ? null : solid,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: FlapText.sora(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: FlapColors.onGreen),
        ),
      ),
    );
  }

  Color _getPlanColor(SubscriptionType type) {
    switch (type) {
      case SubscriptionType.europa:
        return FlapColors.blue;
      case SubscriptionType.champions:
        return FlapColors.gold;
      default:
        return FlapColors.greenBright;
    }
  }

  IconData _getPlanIcon(SubscriptionType type) {
    switch (type) {
      case SubscriptionType.europa:
        return Icons.shield_rounded;
      case SubscriptionType.champions:
        return Icons.workspace_premium_rounded;
      default:
        return Icons.sports_soccer_rounded;
    }
  }

  Future<void> _startTrial() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: FlapColors.green),
        ),
      );

      await _subscriptionsRepo.startChampionsTrialSubscription();

      Navigator.pop(context); // Close loading dialog

      await _loadCurrentSubscription();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_3450d42850')),
          backgroundColor: FlapColors.green,
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_7bdfebf56b', args: [e.toString()])),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _purchaseSubscription(SubscriptionType type) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: FlapColors.green),
        ),
      );

      await _subscriptionsRepo.purchaseSubscription(type);

      Navigator.pop(context); // Close loading dialog

      await _loadCurrentSubscription();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_34319363d3', args: [type.name])),
          backgroundColor: FlapColors.green,
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('il_7bdfebf56b', args: [e.toString()])),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelSubscription() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FlapColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: FlapColors.borderStrong),
        ),
        title: Text(
          tr('il_107af94c1f'),
          style: FlapText.sora(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Text(
          tr('il_d08efd03d8'),
          style: FlapText.sora(fontSize: 13.5, color: FlapColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('il_1ea442a134'),
                style: FlapText.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: FlapColors.muted)),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context, true),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: FlapColors.red.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: FlapColors.red.withValues(alpha: 0.5)),
              ),
              child: Text(tr('il_3a4454427b'),
                  style: FlapText.sora(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: FlapColors.red)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: FlapColors.green),
          ),
        );

        await _subscriptionsRepo.cancelSubscription();

        Navigator.pop(context); // Close loading dialog

        await _loadCurrentSubscription();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_3aa8ee2275')),
            backgroundColor: FlapColors.green,
          ),
        );
      } catch (e) {
        Navigator.pop(context); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('il_7bdfebf56b', args: [e.toString()])),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
