# Paddle payments backend

Two Supabase Edge Functions power the Paddle payment flows — the premium
subscription and one-time **FL Coin** purchases:

- **`paddle-checkout`** — serves a public HTML page that loads Paddle.js and
  opens Paddle Checkout. The Flutter app loads it inside an in-app webview.
- **`paddle-webhook`** — the authoritative, signature-verified handler that
  writes subscription state to the `subscriptions` table and credits purchased
  FL Coins. **The only place premium access is granted or coins are minted.**

## Two environments (sandbox + live)

Paddle has fully separate **sandbox** and **live** dashboards with their own
tokens, product/price IDs and webhook secrets. This project supports both at
once:

- **App side** — both credential sets are committed in `paddle_config.dart`, and
  the active one is chosen at build time by the `PADDLE_ENV` dart-define
  (defaults to sandbox). No code edits to switch:

  ```bash
  flutter run                                    # sandbox (default)
  flutter run   --dart-define=PADDLE_ENV=production
  flutter build --dart-define=PADDLE_ENV=production
  ```

- **Server side** — the single deployed `paddle-webhook` holds both
  environments' secrets. Each incoming event is matched to an environment by
  which webhook secret verifies its signature, so sandbox and live can post to
  the same URL simultaneously.

Repeat the dashboard setup below **once per environment** (sandbox first, then
live) and keep the two sets of IDs straight.

## One-time setup

### 1. Paddle dashboard (repeat for sandbox, then live)

1. Create a **Product** ("Flap Premium") with two **Prices**:
   - Monthly — $1.00, billing period 1 month.
   - Yearly — $10.00, billing period 1 year.
   - Add a **21-day free trial** to each price (Trial period).
2. Copy the two **price IDs** (`pri_...`) and the **client-side token**
   (Developer Tools → Authentication). Sandbox tokens are prefixed `test_`,
   live tokens `live_`.
2b. Create a second **Product** ("FL Coins") with ONE **one-time** Price of
   **$1.00 USD** (no billing period). This single price is the $1 coin unit —
   packs are bought as `quantity` N of it, which is what keeps the rate at
   exactly 10 coins per dollar. Copy its price ID.
3. Create a **Notification destination** (webhook) pointing at the deployed
   `paddle-webhook` URL and copy its **secret key** (`pdl_ntfset_...`).
   Subscribe it to at least: `subscription.created`, `subscription.activated`,
   `subscription.updated`, `subscription.trialing`, `subscription.canceled`,
   `subscription.past_due`, `transaction.completed`, `transaction.payment_failed`.

### 2. App config

Put the **non-secret** values for each environment in
`lib/features/subscriptions/data/paddle_config.dart` — `_sandbox` holds the test
IDs, `_production` the live ones:

```dart
static const PaddleEnvCredentials _sandbox = PaddleEnvCredentials(
  name: 'sandbox',
  clientToken: 'test_xxx',
  priceMonthly: 'pri_xxx',
  priceYearly:  'pri_xxx',
  priceCoins:   'pri_xxx',   // the $1 one-time coin price
);

static const PaddleEnvCredentials _production = PaddleEnvCredentials(
  name: 'production',
  clientToken: 'live_xxx',
  priceMonthly: 'pri_xxx',
  priceYearly:  'pri_xxx',
  priceCoins:   'pri_xxx',
);
```

### 3. Deploy the functions (public — no JWT)

Paddle and the webview cannot send a Supabase JWT, so deploy both without JWT
verification. The webhook is protected by its HMAC signature instead.

```bash
supabase functions deploy paddle-checkout --no-verify-jwt
supabase functions deploy paddle-webhook  --no-verify-jwt
```

### 4. Function secrets (SECRET — never commit)

Set the per-environment secrets. Set only the environments you use — the webhook
picks whichever verifies each request:

```bash
supabase secrets set \
  PADDLE_WEBHOOK_SECRET_SANDBOX=pdl_ntfset_xxx \
  PADDLE_COIN_PRICE_ID_SANDBOX=pri_xxx \
  PADDLE_WEBHOOK_SECRET_LIVE=pdl_ntfset_xxx \
  PADDLE_COIN_PRICE_ID_LIVE=pri_xxx
# Optional: override the 10-coins-per-$1 rate (must match the app's copy)
# supabase secrets set PADDLE_COINS_PER_UNIT=10
# Optional: let paddle-checkout read the token from a secret instead of the URL
# supabase secrets set PADDLE_CLIENT_TOKEN=test_xxx
```

Legacy single-environment secrets (`PADDLE_WEBHOOK_SECRET`,
`PADDLE_COIN_PRICE_ID`) are still honoured as a fallback, so existing
deployments keep working until you migrate to the `_SANDBOX`/`_LIVE` names.

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are injected automatically.

## How state flows

1. App opens `paddle-checkout?price_id=…&user_id=…&email=…` in the webview.
2. User completes payment → Paddle fires `subscription.trialing` / `.created`.
3. `paddle-webhook` verifies the signature and upserts the `subscriptions` row
   keyed on `paddle_subscription_id`, mapping Paddle status → our status
   (`trialing→trial`, `active→active`, `past_due→past_due`, `canceled→cancelled`).
4. The checkout page redirects to `flap://checkout/success`; the app closes the
   webview and polls `getUserSubscription` until the row appears.

Renewals, cancellations, expirations, and payment failures all arrive as later
webhook events and update the same row — the app just re-reads it on resume.

## How FL Coins are credited

1. Buy Coins screen opens checkout for `priceCoins` with `quantity` = dollars.
2. Payment completes → Paddle fires `transaction.completed` with no
   `subscription_id`.
3. The webhook sums the quantity of line items matching the coin price for the
   verifying environment (`PADDLE_COIN_PRICE_ID_SANDBOX` / `_LIVE`) and
   multiplies by `PADDLE_COINS_PER_UNIT` (10). **The coin count comes only
   from Paddle's signed payload** — `custom_data` is client-controlled, so it
   supplies just `user_id`, never an amount.
4. `credit_coin_purchase()` (service-role only, `security definer`) writes the
   `coin_purchases` row and the matching `coin_transactions` credit atomically.
   It is keyed on `paddle_transaction_id`, so Paddle's retries and replays
   credit exactly once.
5. The app polls the balance for ~20s. If the webhook hasn't landed by then the
   user is told the coins are on the way — never that the purchase failed.

If a payment arrives without `custom_data.user_id` it cannot be attributed;
the webhook logs `coin purchase … cannot credit` and the grant must be made by
hand.

## Going live

1. Fill `_production` in `paddle_config.dart` with the live client token and
   price IDs.
2. Set `PADDLE_WEBHOOK_SECRET_LIVE` and `PADDLE_COIN_PRICE_ID_LIVE` (the webhook
   is already deployed; no redeploy needed to add live support).
3. Build the app with `--dart-define=PADDLE_ENV=production`.

Sandbox keeps working the whole time — the two environments run side by side.
