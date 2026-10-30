# App Store (StoreKit) purchases on iOS

iOS sells Premium and FL Coins through StoreKit in-app purchase. Android and web
keep using Paddle — nothing in the Paddle flow changed.

Why: App Store Review Guideline 3.1.1 requires in-app purchase for digital
content consumed in the app, and 3.1.3(b)/3.1.5 scope Apple Pay to *physical*
goods and services. The native StoreKit sheet charges the card in the user's
Apple Wallet with Face ID, so from the player's side this is the Apple Pay
experience — it just goes through Apple, who take their 15–30%.

## The pieces

| Piece | Role |
| --- | --- |
| `lib/core/purchases/app_store_products.dart` | Product ids, display only |
| `lib/core/purchases/iap_service.dart` | Starts purchases, posts the signed transaction to the server, finishes transactions |
| `supabase/functions/_shared/appstore.ts` | Signature verification + the **authoritative** product catalog and fulfilment |
| `supabase/functions/appstore-verify` | Fast path: fulfils the moment the app reports a purchase |
| `supabase/functions/appstore-notifications` | Authoritative path: renewals, expiry, billing failures, refunds |
| `supabase/migrations/20260811000000_app_store_purchases.sql` | Store-agnostic purchase rows + `credit_appstore_coin_purchase` |

The app never grants itself anything. A purchase is only worth something once an
edge function has checked Apple's signature on the transaction and written the
row with the service-role key — the same rule the Paddle flow follows. The coins
a product is worth come from `PRODUCTS` in `_shared/appstore.ts`, keyed by a
product id Apple signed; the Dart catalog is for display only.
`test/app_store_products_test.dart` fails the build if the two drift.

## 1. App Store Connect products

The ids must match exactly. Note that these live in **two different places** in
App Store Connect, which is easy to get wrong:

### Premium → Monetization → **Subscriptions**

NOT "In-App Purchases". Auto-renewable subscriptions are only creatable under
Subscriptions, inside a subscription group — the In-App Purchase dialog's Type
menu doesn't even offer them (it has Consumable, Non-Consumable and
Non-Renewing Subscription).

Create ONE subscription group — Reference Name **Flap Premium** — holding both:

| Product ID | Duration | Price | Reference Name | Display Name |
| --- | --- | --- | --- | --- |
| `com.flap.flapapp.premium.monthly` | 1 month | $1 | Flap Premium Monthly | Premium Monthly |
| `com.flap.flapapp.premium.yearly` | 1 year | $10 | Flap Premium Yearly | Premium Yearly |

Same group matters: that is what lets a subscriber switch between monthly and
yearly rather than holding two subscriptions at once.

Reference Name is internal; **Display Name** and **Description** are shown to the
buyer in the payment sheet and in Settings → Subscriptions, and are reviewed by
Apple. Suggested descriptions: "Full access to Flap, billed monthly." / "…billed
yearly." The group also needs a customer-facing display name — "Flap Premium"
works. These match `ios/Configuration.storekit`; keep them in step.

Do **not** substitute a "Non-Renewing Subscription" to stay in the In-App
Purchase dialog. StoreKit treats those as consumables with no renewal lifecycle,
and `appstore-notifications` is built on the auto-renewable events
(`SUBSCRIBED` / `DID_RENEW` / `EXPIRED`) keyed on `originalTransactionId` —
premium would be granted once and then never renew or expire.

### FL Coins → Monetization → **In-App Purchases**, Type = **Consumable**

Five products, at **10 coins per $1.29** — deliberately *not* Paddle's 10 per
$1. Apple take 15–30%, so matching the web price would mean selling coins on iOS
at a loss. Create each with Type **Consumable** — never Non-Consumable (those can
only ever be bought once) and never Non-Renewing Subscription.

| Product ID | Coins | Price | Reference Name |
| --- | --- | --- | --- |
| `com.flap.flapapp.coins.10` | 10 | $1.29 | Flap Coins 0010 |
| `com.flap.flapapp.coins.50` | 50 | $6.45 | Flap Coins 0050 |
| `com.flap.flapapp.coins.100` | 100 | $12.90 | Flap Coins 0100 |
| `com.flap.flapapp.coins.500` | 500 | $64.50 | Flap Coins 0500 |
| `com.flap.flapapp.coins.1000` | 1000 | $129.00 | Flap Coins 1000 |

Those are the exact $1.29-per-10 multiples. Apple only sells at its own price
points, so the picker may not offer every one of them — **take the nearest
available point**. Nothing breaks if you do: see "Prices are Apple's, coins are
ours" below. Pick the nearest point *upward* on the larger packs if you have the
choice, so a big purchase never works out cheaper per coin than the amount just
below it.

Product ID is permanent and must match the tables above character for character.
Reference Name is internal only (App Store Connect lists, Sales & Trends) and can
be edited later — the zero-padding just keeps the rows in value order, since
reports sort them as text and would otherwise give you 10, 100, 1000, 50, 500.

Each product also needs a **Localization** (Display Name + Description), and
unlike Reference Name these ARE shown to the buyer in the payment sheet, so they
get reviewed by Apple. Suggested:

| Product ID | Display Name | Description |
| --- | --- | --- |
| `…coins.10` | 10 FL Coins | 10 FL Coins for challenges and badges. |
| `…coins.50` | 50 FL Coins | 50 FL Coins for challenges and badges. |
| `…coins.100` | 100 FL Coins | 100 FL Coins for challenges and badges. |
| `…coins.500` | 500 FL Coins | 500 FL Coins for challenges and badges. |
| `…coins.1000` | 1000 FL Coins | 1000 FL Coins for challenges and badges. |

App Store Connect caps **Display Name at 30 characters and Description at 45**,
for subscriptions and consumables alike. The strings above are 13 and 40 at
worst, so they fit with room to spare — but anything longer is silently
untypeable, which is easy to hit if you try to spell out what coins are for.

Keep these in step with `ios/Configuration.storekit`, which carries the same
names for local testing.

#### These are denominations, not a menu

StoreKit can buy several units of one consumable in a single transaction
(`Sk2PurchaseParam.quantity`), so the buy screen keeps the same free-form
`+`/`−` picker Paddle uses. `AppStoreProducts.purchasePlanFor` decides which
denomination to charge and how many of it, always picking the largest one that
divides the amount exactly — 500 coins is `coins.500 x 1`, not `coins.10 x 50`.

Several denominations exist because Apple caps the quantity of a single
purchase, and paying with the largest one keeps the quantity near 1. **The exact
cap is unverified** — Apple's documentation on it could not be confirmed — so
`AppStoreProducts.maxQuantity` is deliberately conservative at **10**. If a
sandbox test proves a higher ceiling, raise it; if a large purchase is ever
rejected by StoreKit, lower it.

That cap is what makes the picker's granularity uneven. With these five
denominations and a cap of 10, the buyable amounts are:

* every **10** from 10 to 100
* every **50** from 100 to 500
* every **100** from 500 to 1000

— 23 values in total. The `+`/`−` buttons walk that list rather than stepping by
a fixed 10, and a typed amount snaps down to the nearest buyable one so the user
is never charged more than they asked for. Off iOS, Paddle keeps the flat
step-of-10 range.

Raising `maxQuantity` is the cheapest way to make this finer: at 100, the
10-coin denomination alone covers every multiple of 10 up to 1000 and the
unevenness disappears entirely. Otherwise, adding a denomination `D` makes
`D, 2D … maxQuantity x D` buyable — so filling the gap at 550 would need a
denomination that divides it (55, 110 or 275), not another round number.

To add one, put it in **both** `AppStoreProducts.coinPacks` and `PRODUCTS`, then
create the product in App Store Connect.
`test/app_store_products_test.dart` fails if those two disagree.

#### Prices are Apple's, coins are ours

The $ column above is the intended tier, but Apple charges in the user's own
currency and its price points do not map exactly across storefronts. That is
fine and does not affect fulfilment: the server derives the coins owed from the
**product id and quantity Apple signed**, never from the price. The app displays
whatever the App Store reports (`IapService.coinPriceFor` multiplies the unit
price by the quantity), so a user always sees the real charge.

For the same reason the buy screen drops its "you always get 10 FL Coins for
every $1" line on iOS and shows `coins_rate_note_store` instead — no dollar rate
is true in every storefront. `ios/Configuration.storekit` carries the US figures
above so local testing shows realistic totals.

**Do not add an introductory offer / free trial to the subscription prices.** The
21-day trial is granted server-side at signup (`bootstrap_new_auth_user`), so an
App Store trial would stack on top of it — the same trap the Paddle prices have.

Products must be in at least "Ready to Submit", and the Paid Applications
agreement must be active, or `queryProductDetails` returns them in `notFoundIDs`
and the store screen shows nothing.

## 2. Supabase secrets

```sh
supabase secrets set \
  APPLE_BUNDLE_ID=com.flap.flapapp \
  APPLE_APP_APPLE_ID=6771325234
```

`APPLE_APP_APPLE_ID` is the numeric Apple ID from App Store Connect → App
Information → General Information (`6771325234` for Flap — public, not a
secret; it is the same number as in an `apps.apple.com/app/id…` URL). It is
neither the bundle id nor the 10-character Team ID. The verifier **requires** it
for production payloads; without it only sandbox purchases verify (which is what
you want before the first release, but it will silently reject live purchases
after).

No Apple private key or shared secret is needed: verification is done against
Apple's signature using the root CA pinned in `_shared/appstore.ts`, not by
calling the App Store Server API.

## 3. Deploy the functions

```sh
# Client-called: JWT verification ON (the caller's identity matters).
supabase functions deploy appstore-verify

# Apple-called: Apple cannot send a Supabase JWT, so the signature IS the auth.
supabase functions deploy appstore-notifications --no-verify-jwt
```

Then apply the migration:

```sh
supabase db push
```

## 4. Point Apple at the notifications endpoint

App Store Connect → your app → **App Information → App Store Server
Notifications**. Set both URLs to:

```
https://<project-ref>.supabase.co/functions/v1/appstore-notifications
```

Use **Version 2** notifications. Set the Production URL and the Sandbox URL —
they can be the same; the function figures out which environment a payload came
from by which verifier accepts its signature, the same way `paddle-webhook`
serves both Paddle environments at once.

Without this endpoint a subscription would be granted once and never renew,
expire, or revoke.

## 5. Testing

### Locally, with no App Store Connect setup at all

`ios/Configuration.storekit` defines the same products locally, so the store
screens work before anything exists in App Store Connect. It is already wired
into the Runner scheme.

**It only applies when the app is launched by Xcode.** `flutter run` starts the
app itself and never consults the scheme's launch action, so products will still
come back not-found there. To use it:

1. `open ios/Runner.xcworkspace`
2. Product → Run
3. optionally `flutter attach` in a terminal for hot reload

Purchases made this way are entirely local — Apple never sees them, so nothing
reaches `appstore-verify` with a real signature and no coins are credited. It is
for exercising the UI, prices and cancel/failure paths, not fulfilment. Use the
`.storekit` file's own debug controls (Editor → Enable/Disable Ask to Buy, fail
transactions, etc.) to drive the pending and failure branches.

If you add or rename a product, update `AppStoreProducts`, `PRODUCTS` **and**
this file; the ids are cross-checked by `test/app_store_products_test.dart` for
the first two, but the `.storekit` file is not.

### Against the real sandbox

Sandbox purchases need a Sandbox Apple Account (App Store Connect → Users and
Access → Sandbox) signed in on the device under Settings → Developer → Sandbox
Apple Account. Xcode and TestFlight builds hit sandbox automatically. Remove the
StoreKit configuration from the scheme first, or it shadows the real sandbox.

This is the only way to exercise fulfilment end to end, because it is the only
way to get a transaction Apple actually signed.

Server-side unit tests, including real ES256 signature verification against a
throwaway certificate chain:

```sh
deno test --allow-env --allow-net --no-lock --node-modules-dir=false \
  supabase/functions/_shared/appstore_test.ts
```

Catalog-consistency tests:

```sh
flutter test test/app_store_products_test.dart
```

## Notes on behaviour worth knowing

**A purchase is never lost.** `appstore-verify` and `appstore-notifications` are
both idempotent on the App Store transaction id, so they can race safely. If
verification fails, `IapService` deliberately leaves the transaction
*unfinished*, so StoreKit hands it back on the next launch — and
`appstore-notifications` applies it independently in the meantime. That is why a
`PurchaseOutcome.pending` is reported to the user as "on its way", never as a
failure.

**`appAccountToken` is how a purchase finds its account.** It is StoreKit's
counterpart of Paddle's `custom_data.user_id`: the app sets it to the Supabase
user id (which is already a UUID, as StoreKit requires) via
`PurchaseParam.applicationUserName`. `appstore-verify` refuses a transaction
whose token names a *different* account than the caller — otherwise anyone could
replay someone else's signed transaction and, because fulfilment is idempotent,
permanently block the real owner from claiming it.

**Refunds.** A refunded subscription is expired immediately. A refunded coin
purchase is logged but **not** clawed back, since the coins may already be spent;
handle those by hand if they show up.

**Switching platforms.** Granting App Store premium expires any other active row
for that user, including a Paddle one, so nobody ends up billed twice over.
