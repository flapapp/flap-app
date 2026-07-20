import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../../router/app_router.dart';
import '../../../theme/flap_tokens.dart';
import '../domain/subscription_access.dart';

/// Gate for premium-only ("protected") actions. Call at the top of any handler
/// that creates, edits, rates, submits, joins, or otherwise mutates:
///
/// ```dart
/// if (!await PremiumGate.ensure(context)) return;
/// ```
///
/// Free (view-only) users are shown an upsell sheet and the action is aborted.
class PremiumGate {
  const PremiumGate._();

  /// Returns `true` when the user has premium access (action may proceed).
  /// Otherwise presents the upsell sheet and returns `false`.
  static Future<bool> ensure(BuildContext context, {String? feature}) async {
    final access = sl<SubscriptionAccess>();

    // Make sure we've loaded state at least once before deciding.
    if (!access.isResolved) {
      await access.ensureLoaded();
    }
    if (access.isPremium) return true;

    if (!context.mounted) return false;
    await _showUpsell(context, feature: feature);
    // Coming back from checkout may have flipped access to premium.
    return access.isPremium;
  }

  static Future<void> _showUpsell(BuildContext context, {String? feature}) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _UpsellSheet(feature: feature),
    );
  }
}

class _UpsellSheet extends StatelessWidget {
  const _UpsellSheet({this.feature});

  final String? feature;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: BoxDecoration(
          color: FlapColors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: FlapColors.borderStrong),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: FlapColors.gold.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.lock_rounded,
                      color: FlapColors.gold, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tr('subscription_upsell_title'),
                    style:
                        FlapText.cond(fontSize: 21, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              feature != null
                  ? tr('subscription_upsell_body_feature', args: [feature!])
                  : tr('subscription_upsell_body'),
              style: FlapText.sora(
                  fontSize: 13.5, color: FlapColors.muted, height: 1.5),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () async {
                Navigator.pop(context); // close the sheet
                await context.router.push(const SubscriptionRoute());
                // SubscriptionAccess is refreshed by the subscription screen on
                // successful checkout; nothing else to do here.
              },
              child: Container(
                width: double.infinity,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: FlapColors.primaryButton,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  tr('subscription_upsell_cta'),
                  style: FlapText.sora(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: FlapColors.onGreen),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  tr('subscription_upsell_dismiss'),
                  style: FlapText.sora(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: FlapColors.muted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
