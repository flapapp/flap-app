import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/di/injection.dart';
import '../../../../theme/flap_tokens.dart';
import '../../../../widgets/flap/flap_kit.dart';
import '../../data/models/subscription.dart';
import '../../domain/repositories/subscriptions_repository.dart';
import '../../domain/subscription_access.dart';
import '../paddle_checkout_sheet.dart';

@RoutePage()
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  SubscriptionAccess get _access => sl<SubscriptionAccess>();

  BillingInterval _interval = BillingInterval.monthly;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Refresh in the background; the UI reacts via the ValueListenableBuilder.
    _access.refresh();
  }

  // --- Actions ---------------------------------------------------------------

  Future<void> _startCheckout() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await PaddleCheckoutSheet.openSubscription(
        context,
        interval: _interval,
      );
      if (!mounted) return;

      switch (result) {
        case CheckoutResult.success:
          // The webhook writes the row asynchronously; poll until it lands.
          final becamePremium = await _access.refreshUntilPremium();
          if (!mounted) return;
          _snack(
            becamePremium
                ? tr('subscription_checkout_success')
                : tr('subscription_checkout_pending'),
            success: becamePremium,
          );
          break;
        case CheckoutResult.cancelled:
          _snack(tr('subscription_checkout_cancelled'), success: false);
          break;
        case CheckoutResult.failed:
          _snack(tr('subscription_checkout_failed'), error: true);
          break;
      }
    } catch (e) {
      if (mounted) _snack(tr('subscription_checkout_failed'), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelSubscription() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: FlapColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: FlapColors.borderStrong),
        ),
        title: Text(
          tr('subscription_cancel_title'),
          style: FlapText.sora(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Text(
          tr('subscription_cancel_body'),
          style: FlapText.sora(fontSize: 13.5, color: FlapColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('subscription_cancel_keep'),
                style: FlapText.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: FlapColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('subscription_cancel_confirm'),
                style: FlapText.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: FlapColors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await sl<SubscriptionsRepository>().cancelSubscription();
      await _access.refresh();
      if (mounted) _snack(tr('subscription_cancel_done'), success: true);
    } catch (e) {
      if (mounted) _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message, {bool success = false, bool error = false}) {
    final color = error
        ? FlapColors.red
        : success
            ? FlapColors.green
            : FlapColors.surfaceSolid;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  // --- UI --------------------------------------------------------------------

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
          tr('subscription_screen_title'),
          style: FlapText.sora(fontSize: 19, fontWeight: FontWeight.w800),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: FlapColors.screenGlow),
        child: ValueListenableBuilder<SubscriptionSnapshot>(
          valueListenable: _access.notifier,
          builder: (context, snapshot, _) {
            if (!snapshot.resolved) {
              return const FlapLoadingList(
                itemCount: 3,
                itemHeight: 160,
                padding: EdgeInsets.fromLTRB(16, 12, 16, 28),
                gap: 14,
                radius: 20,
              );
            }
            final sub = snapshot.subscription;
            final isPremium = snapshot.isPremium;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sub != null && (isPremium || sub.isPastDue)) ...[
                    _currentStatusCard(sub),
                    const SizedBox(height: 24),
                  ],
                  if (!isPremium) ...[
                    _premiumOffer(),
                    const SizedBox(height: 20),
                  ],
                  _policyNote(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _premiumOffer() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FlapColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: FlapColors.borderStrong),
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
                  color: FlapColors.gold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: FlapColors.gold.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: FlapColors.gold, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('subscription_premium_name'),
                      style: FlapText.cond(
                          fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      tr('subscription_premium_desc'),
                      style: FlapText.sora(
                          fontSize: 12.5, color: FlapColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _billingToggle(),
          const SizedBox(height: 18),

          ...[
            tr('subscription_feature_create'),
            tr('subscription_feature_rate'),
            tr('subscription_feature_join'),
            tr('subscription_feature_interact'),
            tr('subscription_feature_challenges'),
          ].map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: FlapColors.greenBright, size: 16),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        feature,
                        style: FlapText.sora(
                            fontSize: 13,
                            color: FlapColors.text,
                            height: 1.3),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 14),

          _primaryButton(
            label: tr('subscription_start_trial_cta'),
            onTap: _busy ? null : _startCheckout,
            busy: _busy,
          ),
        ],
      ),
    );
  }

  Widget _billingToggle() {
    return Row(
      children: [
        Expanded(
          child: _billingOption(
            interval: BillingInterval.monthly,
            title: tr('subscription_billing_monthly'),
            price: tr('subscription_price_monthly',
                args: ['$kPremiumMonthlyPrice']),
            subtitle: tr('subscription_per_month'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _billingOption(
            interval: BillingInterval.yearly,
            title: tr('subscription_billing_yearly'),
            price: tr('subscription_price_yearly',
                args: ['$kPremiumYearlyPrice']),
            subtitle: tr('subscription_per_year'),
            badge: tr('subscription_best_value'),
          ),
        ),
      ],
    );
  }

  Widget _billingOption({
    required BillingInterval interval,
    required String title,
    required String price,
    required String subtitle,
    String? badge,
  }) {
    final selected = _interval == interval;
    return GestureDetector(
      onTap: () => setState(() => _interval = interval),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? FlapColors.green.withValues(alpha: 0.12)
              : FlapColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? FlapColors.green.withValues(alpha: 0.6)
                : FlapColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: FlapText.sora(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: FlapColors.gold.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: FlapText.sora(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: FlapColors.gold),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              price,
              style: FlapText.cond(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            Text(
              subtitle,
              style: FlapText.sora(fontSize: 11, color: FlapColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _currentStatusCard(Subscription sub) {
    final isTrial = sub.isInTrial;
    final isPastDue = sub.isPastDue;
    final onGrad = FlapColors.onGreen;

    final String statusLabel = isPastDue
        ? tr('subscription_status_past_due')
        : isTrial
            ? tr('subscription_status_trialing')
            : tr('subscription_status_active');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isPastDue ? null : FlapColors.primaryButton,
        color: isPastDue ? FlapColors.card : null,
        borderRadius: BorderRadius.circular(20),
        border: isPastDue
            ? Border.all(color: FlapColors.red.withValues(alpha: 0.5))
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
                  color: (isPastDue ? FlapColors.red : onGrad)
                      .withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isPastDue
                      ? Icons.error_outline_rounded
                      : isTrial
                          ? Icons.card_giftcard_rounded
                          : Icons.workspace_premium_rounded,
                  color: isPastDue ? FlapColors.red : onGrad,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusLabel,
                      style: FlapText.sora(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isPastDue
                              ? FlapColors.red
                              : onGrad.withValues(alpha: 0.8)),
                    ),
                    Text(
                      sub.name,
                      style: FlapText.cond(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: isPastDue ? FlapColors.text : onGrad),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isPastDue) ...[
            Text(
              tr('subscription_past_due_body'),
              style: FlapText.sora(
                  fontSize: 13, color: FlapColors.muted, height: 1.4),
            ),
          ] else ...[
            Row(
              children: [
                Icon(Icons.schedule_rounded,
                    color: onGrad.withValues(alpha: 0.85), size: 15),
                const SizedBox(width: 6),
                Text(
                  isTrial
                      ? tr('subscription_trial_days_left',
                          args: ['${sub.daysLeft}'])
                      : sub.autoRenew
                          ? tr('subscription_renews_in',
                              args: ['${sub.daysLeft}'])
                          : tr('subscription_ends_in',
                              args: ['${sub.daysLeft}']),
                  style: FlapText.sora(fontSize: 13, color: onGrad),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (sub.autoRenew)
              GestureDetector(
                onTap: _busy ? null : _cancelSubscription,
                child: Container(
                  width: double.infinity,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: onGrad.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(13),
                    border:
                        Border.all(color: onGrad.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    tr('subscription_cancel_cta'),
                    style: FlapText.sora(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: onGrad),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback? onTap,
    bool busy = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.6 : 1,
        child: Container(
          width: double.infinity,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: FlapColors.primaryButton,
            borderRadius: BorderRadius.circular(14),
          ),
          child: busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: FlapColors.onGreen),
                )
              : Text(
                  label,
                  style: FlapText.sora(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: FlapColors.onGreen),
                ),
        ),
      ),
    );
  }

  Widget _policyNote() {
    return Container(
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
                tr('subscription_policy_title'),
                style:
                    FlapText.sora(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tr('subscriptions_policy_bullets'),
            style: FlapText.sora(
                fontSize: 12.5, color: FlapColors.muted, height: 1.5),
          ),
        ],
      ),
    );
  }
}
