# Paddle subscription backend

Two Supabase Edge Functions power the Paddle subscription flow:

- **`paddle-checkout`** — serves a public HTML page that loads Paddle.js and
  opens Paddle Checkout. The Flutter app loads it inside an in-app webview.
- **`paddle-webhook`** — the authoritative, signature-verified handler that
  writes subscription state to the `subscriptions` table. **The only place
  premium access is granted or revoked.**

## One-time setup

### 1. Paddle dashboard (sandbox first)

1. Create a **Product** ("Flap Premium") with two **Prices**:
   - Monthly — $1.00, billing period 1 month.
   - Yearly — $10.00, billing period 1 year.
   - Add a **21-day free trial** to each price (Trial period).
2. Copy the two **price IDs** (`pri_...`) and the **client-side token**
   (Developer Tools → Authentication).
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
  PADDLE_ENV=sandbox
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

## Going live

Flip `env`/`PADDLE_ENV` to `production`, swap in the production client token +
price IDs + webhook secret, and redeploy.
