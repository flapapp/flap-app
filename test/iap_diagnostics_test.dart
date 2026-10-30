import 'package:flap_app/core/purchases/app_store_products.dart';
import 'package:flap_app/core/purchases/iap_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// When a StoreKit purchase can't start, this one log line is usually the only
/// thing anyone has to go on — and the failure is almost never in our code, so
/// misattributing it costs real debugging time.
void main() {
  String? diagnose({
    List<String> notFound = const <String>[],
    String? errorCode,
    String? errorText,
  }) =>
      IapService.diagnoseProductLoad(
        requested: AppStoreProducts.allIds,
        notFoundIDs: notFound,
        errorCode: errorCode,
        errorText: errorText,
      );

  test('a fully successful load has nothing to report', () {
    expect(diagnose(), isNull);
  });

  test('storekit_no_response is explained as missing products, not a fault', () {
    // The regression that prompted this test: the StoreKit 2 wrapper raises
    // this when StoreKit returns an EMPTY product list, so it means "no such
    // products" — but it arrives as an `error`, and an error-first branch
    // reported it as a generic failure and swallowed the useful explanation.
    final message = diagnose(
      notFound: AppStoreProducts.allIds.toList(),
      errorCode: 'storekit_no_response',
      errorText: 'IAPError(code: storekit_no_response, ...)',
    );
    expect(message, isNotNull);
    expect(message, contains('knows no such products'));
    expect(message, contains('App Store Connect'));
    expect(message, isNot(contains('queryProductDetails failed')));
  });

  test('storekit_no_response is still explained when notFoundIDs is empty', () {
    // Defensive: the plugin currently populates notFoundIDs on this path, but
    // the explanation must not depend on that.
    final message = diagnose(errorCode: 'storekit_no_response');
    expect(message, contains('knows no such products'));
    // Falls back to naming everything that was asked for.
    expect(message, contains(AppStoreProducts.premiumMonthly));
  });

  test('an ordinary not-found list names the missing products', () {
    final message = diagnose(notFound: <String>[AppStoreProducts.premiumYearly]);
    expect(message, contains(AppStoreProducts.premiumYearly));
    expect(message, contains('knows no such products'));
  });

  test('an unrelated error is reported as an error, not as missing products', () {
    final message = diagnose(
      errorCode: 'storekit_duplicate_product_object',
      errorText: 'IAPError(code: storekit_duplicate_product_object)',
    );
    expect(message, contains('queryProductDetails failed'));
    expect(message, isNot(contains('knows no such products')));
  });

  test('the guidance names the StoreKit config caveat', () {
    // The most common local cause is running under `flutter run`, where the
    // StoreKit configuration file is never applied.
    final message = diagnose(notFound: <String>[AppStoreProducts.premiumMonthly]);
    expect(message, contains('Configuration.storekit'));
    expect(message, contains('flutter run'));
  });
}
