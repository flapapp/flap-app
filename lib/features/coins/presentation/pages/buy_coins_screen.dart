import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/app_auth.dart';
import '../../../../core/purchases/app_store_products.dart';
import '../../../../core/purchases/iap_service.dart';
import '../../../../theme/flap_tokens.dart';
import '../../../subscriptions/data/paddle_config.dart';
import '../../../subscriptions/presentation/paddle_checkout_sheet.dart';
import '../../data/coin_purchase_service.dart';

/// Buy FL Coins in units of 10 with a flexible quantity picker.
///
/// Two purchase paths, chosen by platform, but the same picker either way —
/// both stores can buy several units of one price/product in one transaction:
///   * iOS uses StoreKit, because App Store guideline 3.1.1 requires in-app
///     purchase for digital content. Apple caps the per-purchase quantity, so
///     `AppStoreProducts.purchasePlanFor` pays with the largest denomination
///     that divides the amount, and the picker only offers amounts that can be
///     charged exactly. Each 10 coins is $1.29 there rather than $1: Apple take
///     15–30%, and the price shown is always the App Store's own, in the
///     buyer's currency.
///   * Everywhere else opens Paddle checkout with a quantity of the $1 price.
///
/// Either way the screen only *starts* a purchase and then waits: the coins are
/// credited server-side (`appstore-verify` / `paddle-webhook`), so a completed
/// payment is a promise of coins, not proof of them.
@RoutePage()
class BuyCoinsScreen extends StatefulWidget {
  const BuyCoinsScreen({super.key});

  @override
  State<BuyCoinsScreen> createState() => _BuyCoinsScreenState();
}

class _BuyCoinsScreenState extends State<BuyCoinsScreen>
    with SingleTickerProviderStateMixin {
  late final CoinPurchaseService _service =
      CoinPurchaseService(Supabase.instance.client);

  /// The raw amount the field currently holds. Kept unclamped so the summary
  /// can react live while typing; [_effectiveCoins] is what actually gets
  /// bought. Starts at a friendly default.
  int _coins = 100;

  final TextEditingController _controller =
      TextEditingController(text: '100');
  final FocusNode _focus = FocusNode();

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  int _balance = 0;
  bool _loadingBalance = true;
  bool _busy = false;

  /// Whether this platform buys through StoreKit (iOS) rather than Paddle.
  bool get _useStoreKit => IapService.isSupported;

  /// The amount that will actually be purchased: [_coins] snapped to a valid
  /// multiple of the step and clamped to the min/max bounds. On StoreKit it is
  /// snapped further, to an amount a denomination can charge exactly — see
  /// [AppStoreProducts.purchasePlanFor].
  int get _effectiveCoins {
    final normalized = CoinMath.normalize(_coins);
    if (!_useStoreKit) return normalized;
    return _nearestBuyable(normalized);
  }

  /// The buyable amount closest to [coins], preferring the one at or below it
  /// so the user is never charged more than they asked for.
  static int _nearestBuyable(int coins) {
    final buyable = AppStoreProducts.buyableCoinAmounts;
    if (buyable.contains(coins)) return coins;
    final atOrBelow = buyable.where((c) => c <= coins);
    return atOrBelow.isNotEmpty ? atOrBelow.last : buyable.first;
  }

  /// True when the typed amount had to be adjusted to become valid.
  bool get _wasAdjusted => _coins > 0 && _coins != _effectiveCoins;

  bool get _canBuy => !_busy && _coins >= PaddleConfig.minCoins;

  /// The App Store's localized total for the selected amount ("£8.99"), or null
  /// before products have loaded. Never show a hardcoded dollar amount on iOS:
  /// Apple charges in the user's own currency and price tier.
  String? get _storePrice =>
      _useStoreKit ? IapService.instance.coinPriceFor(_effectiveCoins) : null;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      // On blur, snap the field to the value that will actually be charged.
      if (!_focus.hasFocus) _commit(_effectiveCoins);
    });
    _loadBalance();
    if (_useStoreKit) _loadStorePrices();
  }

  /// Pull the App Store's localized prices so the packs can show real amounts.
  Future<void> _loadStorePrices() async {
    try {
      await IapService.instance.loadProducts();
    } catch (e) {
      debugPrint('[coins] store price load failed: $e');
    }
    // Prices only affect labels, so a failure here degrades to the USD
    // fallback rather than blocking the screen.
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pulse.dispose();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    final userId = AppAuth.currentUserId;
    if (userId == null) {
      if (mounted) setState(() => _loadingBalance = false);
      return;
    }
    try {
      final balance = await _service.balance(userId);
      if (mounted) {
        setState(() {
          _balance = balance;
          _loadingBalance = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBalance = false);
    }
  }

  // --- Quantity control ------------------------------------------------------

  /// Sets the amount from a control (stepper / preset), syncing the text field
  /// and firing the feedback pulse. [coins] is normalized first.
  void _commit(int coins) {
    final next = CoinMath.normalize(coins);
    final text = next.toString();
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    if (next != _coins) _bump();
    setState(() => _coins = next);
  }

  /// Handles free-form typing: keep the raw value live (so the summary tracks
  /// it) but don't fight the cursor by rewriting the field mid-edit.
  void _onTyped(String raw) {
    final parsed = int.tryParse(raw.trim());
    setState(() => _coins = parsed ?? 0);
  }

  void _step(int deltaCoins) {
    HapticFeedback.selectionClick();
    _commit(_stepTarget(deltaCoins));
  }

  /// Where a `+`/`-` press should land.
  ///
  /// Off StoreKit that is simply one step away. On StoreKit the buyable amounts
  /// are not evenly spaced — fine-grained up to 100, then coarser — so a fixed
  /// step would land on an unbuyable value, get snapped back, and leave the
  /// button looking dead. Move to the next buyable amount instead.
  int _stepTarget(int deltaCoins) {
    final current = _effectiveCoins;
    if (!_useStoreKit) return current + deltaCoins;

    final buyable = AppStoreProducts.buyableCoinAmounts
        .where((c) => c >= PaddleConfig.minCoins && c <= PaddleConfig.maxCoins)
        .toList();
    if (deltaCoins > 0) {
      return buyable.firstWhere((c) => c > current, orElse: () => current);
    }
    return buyable.lastWhere((c) => c < current, orElse: () => current);
  }

  void _bump() {
    _pulse.forward(from: 0);
  }

  // --- Purchase --------------------------------------------------------------

  Future<void> _buy() async {
    if (!_canBuy) return;
    final userId = AppAuth.currentUserId;
    if (userId == null) return;

    final coins = _effectiveCoins;
    final units = CoinMath.unitsFor(coins);

    setState(() => _busy = true);
    try {
      // Re-read rather than trusting `_balance`: if the initial load failed it
      // is still 0, and a 0 baseline makes awaitCredit return on its first poll
      // with the user's pre-existing balance — reporting coins that were
      // already there as if this purchase had just added them.
      int before;
      try {
        before = await _service.balance(userId);
      } catch (_) {
        before = _balance;
      }

      if (!mounted) return;

      final CheckoutResult result;
      if (_useStoreKit) {
        // StoreKit presents Apple's own payment sheet; there is no webview and
        // no redirect to intercept. The outcome is mapped onto the same
        // CheckoutResult the Paddle path returns so the handling below is
        // shared.
        final outcome = await IapService.instance.buyCoins(coins);
        switch (outcome) {
          case PurchaseOutcome.success:
            result = CheckoutResult.success;
          case PurchaseOutcome.cancelled:
            result = CheckoutResult.cancelled;
          case PurchaseOutcome.failed:
            result = CheckoutResult.failed;
          case PurchaseOutcome.pending:
            // Charged, but fulfilment isn't confirmed. Treated as success so
            // the "coins on their way" branch below runs — calling this a
            // failure would be wrong, the purchase is not lost.
            result = CheckoutResult.success;
        }
      } else {
        result = await PaddleCheckoutSheet.openCoins(context, units: units);
      }
      if (!mounted) return;
      debugPrint('[coins] checkout result=$result baseline=$before '
          'units=$units expected=+$coins');

      switch (result) {
        case CheckoutResult.success:
          final credited =
              await _service.awaitCredit(userId, previousBalance: before);
          if (!mounted) return;
          debugPrint('[coins] after poll: credited=$credited');
          if (credited != null) {
            setState(() => _balance = credited);
            _snack(
              tr('coins_purchase_success', args: ['${credited - before}']),
              success: true,
            );
          } else {
            // Paid, but the webhook hasn't landed yet. Never call this a
            // failure — the credit is still coming.
            _snack(tr('coins_purchase_pending'));
          }
          break;
        case CheckoutResult.cancelled:
          _snack(tr('coins_purchase_cancelled'));
          break;
        case CheckoutResult.failed:
          _snack(tr('coins_purchase_failed'), error: true);
          break;
      }
    } catch (e, st) {
      debugPrint('[coins] purchase flow threw: $e\n$st');
      if (mounted) _snack(tr('coins_purchase_failed'), error: true);
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

  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
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
          tr('coins_buy_title'),
          style: FlapText.sora(fontSize: 19, fontWeight: FontWeight.w800),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: FlapColors.screenGlow),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _balanceCard(),
                    const SizedBox(height: 20),
                    _selectorCard(),
                    const SizedBox(height: 16),
                    _presets(),
                    const SizedBox(height: 20),
                    _summaryCard(),
                    const SizedBox(height: 16),
                    _primaryButton(),
                    const SizedBox(height: 12),
                    Text(
                      tr('coins_credit_note'),
                      textAlign: TextAlign.center,
                      style: FlapText.sora(
                          fontSize: 11.5,
                          color: FlapColors.muted,
                          height: 1.45),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _balanceCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: FlapColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FlapColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: FlapColors.gold.withOpacity(0.13),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: FlapColors.gold.withOpacity(0.4)),
            ),
            child: const Icon(Icons.monetization_on_rounded,
                color: FlapColors.gold, size: 22),
          ),
          const SizedBox(width: 13),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('coins_current_balance'),
                style: FlapText.sora(fontSize: 12, color: FlapColors.muted),
              ),
              const SizedBox(height: 2),
              _loadingBalance
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: FlapColors.gold),
                    )
                  : Text(
                      _fmt(_balance),
                      style: FlapText.cond(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: FlapColors.gold),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _selectorCard() {
    final min = _effectiveCoins <= PaddleConfig.minCoins;
    final max = _effectiveCoins >= PaddleConfig.maxCoins;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: FlapColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: FlapColors.border),
      ),
      child: Column(
        children: [
          Text(
            tr('coins_amount_question'),
            style: FlapText.sora(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            // Paddle sells at a flat 10-per-$1, so the rate can be stated
            // outright. The App Store cannot: it charges its own tier in the
            // buyer's currency, so promising a dollar rate would be a lie.
            _useStoreKit
                ? tr('coins_rate_note_store')
                : tr('coins_rate_note', args: ['${PaddleConfig.coinsPerUnit}']),
            style: FlapText.sora(fontSize: 12, color: FlapColors.muted),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _stepButton(
                icon: Icons.remove_rounded,
                enabled: !min && !_busy,
                onTap: () => _step(-PaddleConfig.coinStep),
              ),
              Expanded(child: _amountField()),
              _stepButton(
                icon: Icons.add_rounded,
                enabled: !max && !_busy,
                onTap: () => _step(PaddleConfig.coinStep),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Reserve a line so the layout doesn't jump as the hint appears.
          SizedBox(
            height: 18,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _wasAdjusted
                  ? Text(
                      tr('coins_adjusted', args: [_fmt(_effectiveCoins)]),
                      key: const ValueKey('adjusted'),
                      style: FlapText.sora(
                          fontSize: 11.5, color: FlapColors.gold),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountField() {
    return ScaleTransition(
      scale: Tween<double>(begin: 1, end: 1.06).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeOutBack),
      ),
      child: Column(
        children: [
          IntrinsicWidth(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              onChanged: _onTyped,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              cursorColor: FlapColors.greenBright,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              style: FlapText.cond(
                fontSize: 46,
                fontWeight: FontWeight.w800,
                color: FlapColors.text,
                height: 1,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            tr('coins_unit_label'),
            style: FlapText.sora(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: FlapColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _stepButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1 : 0.35,
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: FlapColors.surface2,
            shape: BoxShape.circle,
            border: Border.all(color: FlapColors.borderStrong),
          ),
          child: Icon(icon, color: FlapColors.text, size: 24),
        ),
      ),
    );
  }

  Widget _presets() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: CoinMath.presets.map((coins) {
        final selected = _effectiveCoins == coins && !_wasAdjusted;
        return GestureDetector(
          onTap: _busy ? null : () => _commit(coins),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? FlapColors.green.withOpacity(0.14)
                  : FlapColors.surface2,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: selected ? FlapColors.greenBright : FlapColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.monetization_on_rounded,
                    size: 15,
                    color: selected ? FlapColors.greenBright : FlapColors.gold),
                const SizedBox(width: 6),
                Text(
                  _fmt(coins),
                  style: FlapText.sora(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color:
                        selected ? FlapColors.greenBright : FlapColors.text,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            FlapColors.green.withOpacity(0.10),
            FlapColors.green.withOpacity(0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FlapColors.greenBright.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('coins_you_receive'),
                  style:
                      FlapText.sora(fontSize: 12, color: FlapColors.muted),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.monetization_on_rounded,
                        size: 18, color: FlapColors.gold),
                    const SizedBox(width: 6),
                    _animatedInt(
                      _effectiveCoins,
                      style: FlapText.cond(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: FlapColors.text),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      tr('coins_unit_label'),
                      style: FlapText.sora(
                          fontSize: 12, color: FlapColors.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                tr('coins_total'),
                style: FlapText.sora(fontSize: 12, color: FlapColors.muted),
              ),
              const SizedBox(height: 3),
              // On StoreKit the total is whatever Apple charges in the user's
              // currency, so it is shown verbatim rather than counted up from
              // the USD rate.
              if (_storePrice != null)
                Text(
                  _storePrice!,
                  style: FlapText.cond(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: FlapColors.greenBright),
                )
              else
                _animatedInt(
                  CoinMath.priceUsd(_effectiveCoins),
                  prefix: '\$',
                  style: FlapText.cond(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: FlapColors.greenBright),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// A number that counts up/down smoothly whenever [value] changes.
  Widget _animatedInt(int value, {String prefix = '', required TextStyle style}) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.toDouble()),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (_, v, __) =>
          Text('$prefix${_fmt(v.round())}', style: style),
    );
  }

  Widget _primaryButton() {
    final enabled = _canBuy;
    return GestureDetector(
      onTap: enabled ? _buy : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.6,
        child: Container(
          width: double.infinity,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: FlapColors.primaryButton,
            borderRadius: BorderRadius.circular(15),
          ),
          child: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: FlapColors.onGreen),
                )
              : Text(
                  // The App Store price already carries its own currency
                  // symbol, so it needs the variant without the literal "$".
                  _storePrice != null
                      ? tr('coins_buy_cta_price',
                          args: [_fmt(_effectiveCoins), _storePrice!])
                      : tr('coins_buy_cta', args: [
                          _fmt(_effectiveCoins),
                          '${CoinMath.priceUsd(_effectiveCoins)}',
                        ]),
                  style: FlapText.sora(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: FlapColors.onGreen),
                ),
        ),
      ),
    );
  }
}
