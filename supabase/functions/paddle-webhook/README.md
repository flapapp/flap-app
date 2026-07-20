# Paddle payments backend

Two Supabase Edge Functions power the Paddle payment flows — the premium
subscription and one-time **FL Coin** purchases:

- **`paddle-checkout`** — serves a public HTML page that loads Paddle.js and
  opens Paddle Checkout. The Flutter app loads it inside an in-app webview.
- **`paddle-webhook`** — the authoritative, signature-verified handler that
  writes subscription state to the `subscriptions` table and credits purchased
  FL Coins. **The only place premium access is granted or coins are minted.**

## One-time setup

### 1. Paddle dashboard (sandbox first)

1. Create a **Product** ("Flap Premium") with two **Prices**:
   - Monthly — $1.00, billing period 1 month.
   - Yearly — $10.00, billing period 1 year.
   - Add a **21-day free trial** to each price (Trial period).
2. Copy the two **price IDs** (`pri_...`) and the **client-side token**
   (Developer Tools → Authentication).
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

Put the **non-secret** values in `lib/features/subscriptions/data/paddle_config.dart`:

```dart
static const String env = 'sandbox';
static const String clientToken = 'test_xxx';   // client-side token
static const String priceMonthly = 'pri_xxx';
static const String priceYearly  = 'pri_xxx';
static const String priceCoins   = 'pri_xxx';   // the $1 one-time coin price
```

### 3. Deploy the functions (public — no JWT)

Paddle and the webview cannot send a Supabase JWT, so deploy both without JWT
verification. The webhook is protected by its HMAC signature instead.

```bash
supabase functions deploy paddle-checkout --no-verify-jwt
supabase functions deploy paddle-webhook  --no-verify-jwt
```

### 4. Function secrets (SECRET — never commit)

```bash
supabase secrets set \
  PADDLE_WEBHOOK_SECRET=pdl_ntfset_xxx \
  PADDLE_ENV=sandbox \
  PADDLE_COIN_PRICE_ID=pri_xxx     # same $1 coin price as PaddleConfig.priceCoins
# Optional: override the 10-coins-per-$1 rate (must match the app's copy)
# supabase secrets set PADDLE_COINS_PER_UNIT=10
# Optional: let paddle-checkout read the token from a secret instead of the URL
# supabase secrets set PADDLE_CLIENT_TOKEN=test_xxx
```

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
3. The webhook sums the quantity of line items matching `PADDLE_COIN_PRICE_ID`
   and multiplies by `PADDLE_COINS_PER_UNIT` (10). **The coin count comes only
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

Flip `env`/`PADDLE_ENV` to `production`, swap in the production client token +
price IDs + webhook secret, and redeploy.
