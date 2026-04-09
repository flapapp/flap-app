import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flap_app/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:flap_app/features/subscription/domain/usecases/cancel_subscription_usecase.dart';
import 'package:flap_app/features/subscription/domain/usecases/load_user_subscription_usecase.dart';
import 'package:flap_app/features/subscription/domain/usecases/purchase_subscription_usecase.dart';
import 'package:flap_app/features/subscription/domain/usecases/start_champions_trial_usecase.dart';
import 'package:flap_app/features/subscription/presentation/bloc/subscription_bloc.dart';
import 'package:flap_app/features/subscription/presentation/bloc/subscription_event.dart';
import 'package:flap_app/features/subscription/presentation/bloc/subscription_state.dart';
import 'package:flap_app/models/subscription.dart';
import 'package:flap_app/utils/i18n.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SubscriptionBloc(
        loadUserSubscription: LoadUserSubscriptionUseCase(
          context.read<SubscriptionRepository>(),
        ),
        purchaseSubscription: PurchaseSubscriptionUseCase(
          context.read<SubscriptionRepository>(),
        ),
        startChampionsTrial: StartChampionsTrialUseCase(
          context.read<SubscriptionRepository>(),
        ),
        cancelSubscription: CancelSubscriptionUseCase(
          context.read<SubscriptionRepository>(),
        ),
      )..add(const SubscriptionStarted()),
      child: const _SubscriptionScaffold(),
    );
  }
}

class _SubscriptionScaffold extends StatefulWidget {
  const _SubscriptionScaffold();

  @override
  State<_SubscriptionScaffold> createState() => _SubscriptionScaffoldState();
}

class _SubscriptionScaffoldState extends State<_SubscriptionScaffold> {
  String? _pendingSuccessMessage;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SubscriptionBloc, SubscriptionState>(
      listener: (context, state) {
        if (state is SubscriptionFailure) {
          setState(() => _pendingSuccessMessage = null);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                I18n.inline(
                  'Помилка: ${state.message}',
                  'Error: ${state.message}',
                ),
              ),
              backgroundColor: Colors.red,
            ),
          );
          context.read<SubscriptionBloc>().add(const SubscriptionRefreshed());
        } else if (state is SubscriptionReady &&
            _pendingSuccessMessage != null) {
          final msg = _pendingSuccessMessage!;
          setState(() => _pendingSuccessMessage = null);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: const Color(0xFF4caf50),
            ),
          );
        }
      },
      builder: (context, state) {
        final current =
            state is SubscriptionReady ? state.current : null;
        final loading = state is SubscriptionLoadInProgress ||
            state is SubscriptionInitial;

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
          body: loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF4caf50)),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (current != null) ...[
                        _CurrentSubscriptionCard(
                          subscription: current,
                          onCancelConfirmed: () => setState(
                            () => _pendingSuccessMessage = I18n.inline(
                              'Підписку успішно скасовано',
                              'Subscription cancelled successfully',
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      Text(
                        I18n.inline('Доступні плани', 'Available plans'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _PlanCard(
                        type: SubscriptionType.free,
                        current: current,
                        onArmSuccessMessage: (msg) =>
                            setState(() => _pendingSuccessMessage = msg),
                      ),
                      const SizedBox(height: 16),
                      _PlanCard(
                        type: SubscriptionType.europa,
                        current: current,
                        onArmSuccessMessage: (msg) =>
                            setState(() => _pendingSuccessMessage = msg),
                      ),
                      const SizedBox(height: 16),
                      _PlanCard(
                        type: SubscriptionType.champions,
                        current: current,
                        onArmSuccessMessage: (msg) =>
                            setState(() => _pendingSuccessMessage = msg),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info_outline,
                                    color: Colors.white70, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  I18n.inline(
                                    'Важлива інформація',
                                    'Important information',
                                  ),
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
                              style: const TextStyle(
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
      },
    );
  }
}

class _CurrentSubscriptionCard extends StatelessWidget {
  const _CurrentSubscriptionCard({
    required this.subscription,
    required this.onCancelConfirmed,
  });

  final Subscription subscription;
  final VoidCallback onCancelConfirmed;

  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text(
          I18n.inline('Скасувати підписку?', 'Cancel subscription?'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          I18n.inline(
            'Ви впевнені, що хочете скасувати підписку? Ви втратите всі переваги преміум плану.',
            'Are you sure you want to cancel the subscription? You will lose all premium plan benefits.',
          ),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              I18n.inline('Ні', 'No'),
              style: const TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              I18n.inline('Так, скасувати', 'Yes, cancel'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      onCancelConfirmed();
      context.read<SubscriptionBloc>().add(const SubscriptionCancelRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
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
            color: (isActive ? const Color(0xFF4caf50) : Colors.grey)
                .withOpacity(0.3),
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
                      isInTrial
                          ? I18n.inline('Пробний період', 'Trial period')
                          : I18n.inline(
                              'Поточна підписка', 'Current subscription'),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isActive
                      ? I18n.inline('АКТИВНА', 'ACTIVE')
                      : I18n.inline('НЕАКТИВНА', 'INACTIVE'),
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
                  I18n.inline(
                    'Залишилось: ${subscription.daysLeft} днів',
                    'Days left: ${subscription.daysLeft}',
                  ),
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
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          if (subscription.type != SubscriptionType.free) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _confirmCancel(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                    ),
                    child: Text(
                      I18n.inline('Скасувати підписку', 'Cancel subscription'),
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
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.type,
    required this.current,
    required this.onArmSuccessMessage,
  });

  final SubscriptionType type;
  final Subscription? current;
  final void Function(String message) onArmSuccessMessage;

  @override
  Widget build(BuildContext context) {
    final subscription = Subscription(
      id: '',
      userId: '',
      type: type,
      status: SubscriptionStatus.active,
      startDate: DateTime.now(),
      endDate: DateTime.now(),
      price: 0,
      features: const {},
    );

    final isCurrentPlan = current?.type == type;
    final canUpgrade =
        current != null && current!.type.index < type.index;

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
                  color: _planColor(type).withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: _planColor(type)),
                ),
                child: Center(
                  child: Text(
                    _planEmoji(type),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          ...subscription.featuresList.map((feature) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: _planColor(type), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ValueListenableBuilder<String>(
                      valueListenable: I18n.language,
                      builder: (context, _, __) => Text(
                        feature,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 20),
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
            const SizedBox.shrink(),
          ] else if (type == SubscriptionType.champions &&
              subscription.isTrialAvailable &&
              (current?.championsTrialConsumed != true)) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      onArmSuccessMessage(
                        I18n.inline(
                          '🎉 Пробний період Champions League активовано на 30 днів!',
                          '🎉 Champions League trial activated for 30 days!',
                        ),
                      );
                      context
                          .read<SubscriptionBloc>()
                          .add(const SubscriptionTrialRequested());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFffc107),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      I18n.inline(
                        'СПРОБУВАТИ 30 ДНІВ БЕЗКОШТОВНО',
                        'TRY 30 DAYS FREE',
                      ),
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
                    onPressed: () {
                      final name = subscription.name;
                      onArmSuccessMessage(
                        I18n.inline(
                          '🎉 Підписку $name успішно активовано!',
                          '🎉 $name subscription activated successfully!',
                        ),
                      );
                      context.read<SubscriptionBloc>().add(
                            SubscriptionPurchaseRequested(type),
                          );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _planColor(type),
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
                    onPressed: () {
                      final name = subscription.name;
                      onArmSuccessMessage(
                        I18n.inline(
                          '🎉 Підписку $name успішно активовано!',
                          '🎉 $name subscription activated successfully!',
                        ),
                      );
                      context.read<SubscriptionBloc>().add(
                            SubscriptionPurchaseRequested(type),
                          );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _planColor(type),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      canUpgrade
                          ? I18n.inline('ОНОВИТИ ПЛАН', 'UPGRADE PLAN')
                          : I18n.inline('ОБРАТИ ПЛАН', 'CHOOSE PLAN'),
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

  Color _planColor(SubscriptionType type) {
    switch (type) {
      case SubscriptionType.europa:
        return const Color(0xFF2196F3);
      case SubscriptionType.champions:
        return const Color(0xFFffc107);
      default:
        return const Color(0xFF4caf50);
    }
  }

  String _planEmoji(SubscriptionType type) {
    switch (type) {
      case SubscriptionType.europa:
        return '⚽';
      case SubscriptionType.champions:
        return '👑';
      default:
        return '🆓';
    }
  }
}
