import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../models/subscription.dart';
import '../../../../utils/i18n.dart';
import '../../domain/repositories/subscriptions_repository.dart';

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
      final userId = FirebaseAuth.instance.currentUser?.uid;
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
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f0f23),
        elevation: 0,
        title: Text(
          I18n.inline('Підписки', 'Subscriptions'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4caf50)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
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
                    I18n.inline('Доступні плани', 'Available plans'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Free plan
                  _buildSubscriptionPlan(SubscriptionType.free),
                  const SizedBox(height: 16),

                  // Europa League plan
                  _buildSubscriptionPlan(SubscriptionType.europa),
                  const SizedBox(height: 16),

                  // Champions League plan
                  _buildSubscriptionPlan(SubscriptionType.champions),

                  const SizedBox(height: 32),

                  // Disclaimer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.white70, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              I18n.inline('Важлива інформація', 'Important information'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          I18n.inline(
    '• Підписки оновлюються автоматично\n'
    '• Ви можете скасувати підписку в будь-який момент\n'
    '• Пробний період доступний лише один раз\n'
    '• Ціни вказані в гривнях (UAH)',
    '• Subscriptions renew automatically\n'
    '• You can cancel your subscription anytime\n'
    '• The trial period is available only once\n'
    '• Prices are shown in Ukrainian hryvnia (UAH)',
  ),
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentSubscriptionCard() {
    final subscription = _currentSubscription!;
    final isActive = subscription.isActive;
    final isInTrial = subscription.isInTrial;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isActive
              ? [const Color(0xFF4caf50), const Color(0xFF66bb6a)]
              : [Colors.grey, Colors.grey.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isActive ? const Color(0xFF4caf50) : Colors.grey).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isInTrial ? '🎁' : '👑',
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isInTrial ? I18n.inline('Пробний період', 'Trial period') : I18n.inline('Поточна підписка', 'Current subscription'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    ValueListenableBuilder<String>(
                      valueListenable: I18n.language,
                      builder: (context, _, __) => Text(
                        subscription.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isActive ? I18n.inline('АКТИВНА', 'ACTIVE') : I18n.inline('НЕАКТИВНА', 'INACTIVE'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (isActive) ...[
            Row(
              children: [
                const Icon(Icons.schedule, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  I18n.inline('Залишилось: ${subscription.daysLeft} днів', 'Days left: ${subscription.daysLeft}'),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          ValueListenableBuilder<String>(
            valueListenable: I18n.language,
            builder: (context, _, __) => Text(
              subscription.description,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),

          if (subscription.type != SubscriptionType.free) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _cancelSubscription,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                    ),
                    child: Text(I18n.inline('Скасувати підписку', 'Cancel subscription')),
                  ),
                ),
              ],
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentPlan
              ? const Color(0xFF4caf50)
              : Colors.white.withOpacity(0.1),
          width: isCurrentPlan ? 2 : 1,
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
                decoration: BoxDecoration(
                  color: _getPlanColor(type).withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: _getPlanColor(type)),
                ),
                child: Center(
                  child: Text(
                    _getPlanEmoji(type),
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ValueListenableBuilder<String>(
                      valueListenable: I18n.language,
                      builder: (context, _, __) => Text(
                        subscription.name,
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
                        subscription.description,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      I18n.inline('на місяць', 'per month'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4caf50).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF4caf50)),
                  ),
                  child: Text(
                    I18n.inline('БЕЗКОШТОВНО', 'FREE'),
                    style: const TextStyle(
                      color: Color(0xFF4caf50),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 20),

          // Features list
          ...subscription.featuresList.map((feature) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: _getPlanColor(type),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ValueListenableBuilder<String>(
                      valueListenable: I18n.language,
                      builder: (context, _, __) => Text(
                        feature,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 20),

          // Action buttons
          if (isCurrentPlan) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF4caf50).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF4caf50)),
              ),
              child: Text(
                I18n.inline('ПОТОЧНИЙ ПЛАН', 'CURRENT PLAN'),
                style: const TextStyle(
                  color: Color(0xFF4caf50),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ] else if (type == SubscriptionType.free) ...[
            // Free plan - no action needed
            const SizedBox.shrink(),
          ] else if (type == SubscriptionType.champions &&
                     subscription.isTrialAvailable &&
                     (_currentSubscription?.trialEndDate == null)) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _startTrial(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFffc107),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      I18n.inline('СПРОБУВАТИ 30 ДНІВ БЕЗКОШТОВНО', 'TRY 30 DAYS FREE'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _purchaseSubscription(type),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getPlanColor(type),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      I18n.inline('ПРИДБАТИ ЗАРАЗ', 'BUY NOW'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (canUpgrade || type != SubscriptionType.free) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _purchaseSubscription(type),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getPlanColor(type),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      canUpgrade ? I18n.inline('ОНОВИТИ ПЛАН', 'UPGRADE PLAN') : I18n.inline('ОБРАТИ ПЛАН', 'CHOOSE PLAN'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getPlanColor(SubscriptionType type) {
    switch (type) {
      case SubscriptionType.europa:
        return const Color(0xFF2196F3); // Blue
      case SubscriptionType.champions:
        return const Color(0xFFffc107); // Gold
      default:
        return const Color(0xFF4caf50); // Green
    }
  }

  String _getPlanEmoji(SubscriptionType type) {
    switch (type) {
      case SubscriptionType.europa:
        return '⚽';
      case SubscriptionType.champions:
        return '👑';
      default:
        return '🆓';
    }
  }

  Future<void> _startTrial() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF4caf50)),
        ),
      );

      await _subscriptionsRepo.startChampionsTrialSubscription();

      Navigator.pop(context); // Close loading dialog

      await _loadCurrentSubscription();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.inline('🎉 Пробний період Champions League активовано на 30 днів!', '🎉 Champions League trial activated for 30 days!')),
          backgroundColor: const Color(0xFF4caf50),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.inline('Помилка: ${e.toString()}', 'Error: ${e.toString()}')),
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
          child: CircularProgressIndicator(color: Color(0xFF4caf50)),
        ),
      );

      await _subscriptionsRepo.purchaseSubscription(type);

      Navigator.pop(context); // Close loading dialog

      await _loadCurrentSubscription();

      final subscription = Subscription(
        id: '', userId: '', type: type, status: SubscriptionStatus.active,
        startDate: DateTime.now(), endDate: DateTime.now(), price: 0, features: {},
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: ValueListenableBuilder<String>(
            valueListenable: I18n.language,
            builder: (context, _, __) => Text(I18n.inline('🎉 Підписку ${subscription.name} успішно активовано!', '🎉 ${subscription.name} subscription activated successfully!')),
          ),
          backgroundColor: const Color(0xFF4caf50),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(I18n.inline('Помилка: ${e.toString()}', 'Error: ${e.toString()}')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelSubscription() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text(
          I18n.inline('Скасувати підписку?', 'Cancel subscription?'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          I18n.inline('Ви впевнені, що хочете скасувати підписку? Ви втратите всі переваги преміум плану.', 'Are you sure you want to cancel the subscription? You will lose all premium plan benefits.'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(I18n.inline('Ні', 'No'), style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(I18n.inline('Так, скасувати', 'Yes, cancel'), style: const TextStyle(color: Colors.white)),
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
            child: CircularProgressIndicator(color: Color(0xFF4caf50)),
          ),
        );

        await _subscriptionsRepo.cancelSubscription();

        Navigator.pop(context); // Close loading dialog

        await _loadCurrentSubscription();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(I18n.inline('Підписку успішно скасовано', 'Subscription cancelled successfully')),
            backgroundColor: const Color(0xFF4caf50),
          ),
        );
      } catch (e) {
        Navigator.pop(context); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(I18n.inline('Помилка: ${e.toString()}', 'Error: ${e.toString()}')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
