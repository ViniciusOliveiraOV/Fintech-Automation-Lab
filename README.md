# Fintech Automation Lab (Arch Linux + Docker)

Pipeline simulated locally:

Stripe (simulated events with Stripe CLI) -> n8n -> PostgreSQL -> Metabase -> Slack alerts

Operational command guide:

- `WEBHOOK_TEST_OPS.md`

## 1. Project folder structure

```text
n8n1/
├── .env.example
├── .gitignore
├── docker-compose.yml
├── README.md
├── n8n/
│   └── stripe_signature_verification.js
├── postgres/
│   └── init/
│       └── 01_create_payments_table.sql
├── sql/
│   └── metabase_queries.sql
└── examples/
    └── simulated_payments.json
```

## 2. Docker Compose services

The `docker-compose.yml` starts:

- `postgres` (database)
- `n8n` (workflow automation)
- `metabase` (analytics)

### Configure secrets before first run

1. Create your local secrets file from template:

```bash
cp .env.example .env
```

2. Edit `.env` and replace all placeholder values (`change_this...`, `whsec_replace_me`).
3. Generate a strong n8n encryption key (32+ chars), for example:

```bash
openssl rand -hex 32
```

4. Keep `.env` private. It is ignored by git via `.gitignore`.

### Start all services

```bash
docker compose up -d
```

### Check containers

```bash
docker compose ps
```

### URLs

- n8n: `http://localhost:5678`
- Metabase: `http://localhost:3000`
- PostgreSQL: `localhost:5432`

n8n default auth from `.env`:

- user: value of `N8N_BASIC_AUTH_USER` in `.env`
- password: value of `N8N_BASIC_AUTH_PASSWORD` in `.env`

## 3. PostgreSQL initialization

The file `postgres/init/01_create_payments_table.sql` creates table `payments`:

- `id`
- `stripe_session_id`
- `customer_email`
- `amount_total`
- `currency`
- `status`
- `created_at`

Important note:

- `amount_total` is stored in major currency units (for example `149.90`).
- Stripe sends `amount_total` in cents, so we convert in the n8n Function node.

## 4. Stripe CLI commands (local)

### Install Stripe CLI on Arch Linux

Option A (if package is available in your repos):

```bash
sudo pacman -S stripe-cli
```

Option B (official script):

```bash
curl -fsSL https://stripe.com/install.sh | bash
```

### Login to Stripe

```bash
stripe login
```

### Forward Stripe events to n8n webhook

Use this after creating and activating your n8n workflow webhook URL:

```bash
stripe listen --events checkout.session.completed --forward-to http://localhost:5678/webhook/stripe-checkout
```

If n8n basic auth is enabled for your instance, include credentials in the forward URL:

```bash
stripe listen --events checkout.session.completed --forward-to "http://N8N_BASIC_AUTH_USER:N8N_BASIC_AUTH_PASSWORD@localhost:5678/webhook/stripe-checkout"
```

### Simulate checkout completion event

```bash
stripe trigger checkout.session.completed
```

## 5. How Stripe event forwarding works

1. Stripe CLI opens a local listener.
2. `stripe trigger checkout.session.completed` creates a fake event in your Stripe test account.
3. Stripe CLI receives that event and forwards it to your n8n webhook endpoint (`/webhook/stripe-checkout`).
4. n8n receives the JSON payload and executes your workflow.

n8n webhook endpoint format:

- Test URL (editor/test mode): `http://localhost:5678/webhook-test/stripe-checkout`
- Production URL (active workflow): `http://localhost:5678/webhook/stripe-checkout`

Use `webhook-test` while testing with "Execute workflow", and `webhook` after activating workflow.

Quick reference:

- Test mode: `stripe listen --events checkout.session.completed --forward-to http://localhost:5678/webhook-test/stripe-checkout`
- Active workflow: `stripe listen --events checkout.session.completed --forward-to http://localhost:5678/webhook/stripe-checkout`

## 6. n8n workflow step-by-step (beginner friendly)

### Before creating nodes

1. Open n8n at `http://localhost:5678`.
2. Login with credentials from compose file.
3. Click **Create Workflow**.

### Node 1: Webhook (receive Stripe event)

1. Add node: **Webhook**.
2. Set **HTTP Method** to `POST`.
3. Set **Path** to `stripe-checkout`.
4. Set **Authentication** to `None` for first local test.
5. Set **Respond** to `Immediately` for first local test.
6. For Stripe signature validation, enable **Options -> Raw Body**.
7. Save node.
8. Click **Execute workflow** (or **Listen for test event**) to enable test mode.
9. Copy the **Test URL** shown in the Webhook node panel.

With path `stripe-checkout`, expected URLs are:

- Test URL (only while workflow is waiting): `http://localhost:5678/webhook-test/stripe-checkout`
- Production URL (workflow published + active): `http://localhost:5678/webhook/stripe-checkout`

Important: the Test URL works only after you click **Execute workflow** and usually for one request at a time.

Expected payload field for event type:

- Without signature-normalization node: `{{$json.body?.type || $json.type}}`
- With signature-normalization node (recommended): `{{$json.type}}`

### Recommended security node: validate Stripe signature

For production-like security, insert a **Code (JavaScript)** node between Webhook and IF:

1. Add a **Code** node right after Webhook.
2. Use mode `Run Once for All Items`.
3. Paste code from `n8n/stripe_signature_verification.js`.
4. Ensure `STRIPE_WEBHOOK_SECRET` is set in your `.env` and restart stack if needed.
5. Connect this Code node to the IF node.

This node verifies `Stripe-Signature` (`t` + `v1`) with HMAC SHA-256 and rejects invalid or stale payloads.

#### Webhook parameter details (important)

Authentication options:

- `None`: no auth check. Best for local testing only.
- `Basic Auth`: requires username/password configured in the Webhook credentials.
- `Header Auth`: validates a specific header and value/token.
- `JWT Auth`: expects JWT token and validates according to your JWT settings.

Recommended for this lab:

- Start with `None` while building.
- Move to `Header Auth` or `JWT Auth` after first successful end-to-end test.

Respond options:

- `Immediately`: returns HTTP response as soon as webhook is received.
- `When Last Node Finishes`: waits until workflow finishes before returning response.
- `Using "Respond to Webhook" node`: gives full control of status/body/headers via a dedicated node.
- `Streaming`: streams response progressively (advanced use cases).

Recommended for this lab:

- Use `Immediately` while validating Stripe -> n8n connectivity.
- If you need custom API-style responses, switch to `Using "Respond to Webhook" node`.

Webhook **Options -> Add option** reference:

- `Allowed Origin (CORS)`: set allowed frontend origin (example `http://localhost:3000`).
- `Field Name for Binary Data`: field name used when receiving file/binary payloads.
- `Ignore Bots`: ignores common bot user agents.
- `IP(s) Allowlist`: accepts requests only from listed IPs/CIDRs.
- `No Response Body`: sends empty body in response.
- `Raw Body`: keeps raw request body (useful for signature validation).
- `Response Code`: custom HTTP status code returned by webhook.
- `Response Data`: choose what to return (for example first entry JSON).
- `Response Headers`: add custom HTTP response headers.

Practical defaults for this Stripe lab:

- `Allowed Origin (CORS)`: leave empty.
- `Ignore Bots`: enabled.
- `IP(s) Allowlist`: optional in local mode.
- `Raw Body`: enable for production-like Stripe signature validation.
- `Response Code`: `200`.
- `No Response Body`: disabled.

#### Node Settings (tab "Settings")

You can configure these settings in most nodes (Webhook, IF, Function, Postgres, Slack):

- `Always Output Data?`: forces output even if node returns nothing. Keep `Off` for this lab.
- `Execute Once?`: executes node once for all incoming items. Keep `Off`.
- `Retry On Fail?`: retries node when it fails. Keep `On` for DB/Slack nodes.
- `On Error?`:
  - `Stop Workflow`: stop on first error (recommended while debugging).
  - `Continue`: continue and ignore that node failure.
  - `Continue (Using Error Output)`: route errors to dedicated error branch.

Recommended lab profile:

- During setup: `On Error = Stop Workflow`.
- In production-like runs: use `Continue (Using Error Output)` on Slack node, so payment insert does not stop if Slack is down.

Specific note for Webhook:

- `Allow Multiple HTTP Methods?`: keep `Off` and use only `POST` for Stripe events.

### Node 2: IF (filter only checkout.session.completed)

1. Add **IF** node connected from Webhook.
2. Rule type: **String**.
3. Value 1 (Expression): `{{$json.body?.type || $json.type}}`
4. Operation: `equals`.
5. Value 2: `checkout.session.completed`
6. True output continues flow.

### Node 3: Function (extract payment fields)

1. Add **Function** node connected to IF (true path).
2. Paste this code:

```javascript
const event = $input.first().json.body ?? $input.first().json;
const session = event.data.object;

return [
  {
    json: {
      stripe_session_id: session.id,
      customer_email: session.customer_details?.email || "",
      amount_total: (session.amount_total || 0) / 100,
      currency: (session.currency || "usd").toUpperCase(),
      status: session.payment_status || "unknown"
    }
  }
];
```

### Node 4: PostgreSQL (insert payment)

1. Add **Postgres** node after Function.
2. Create Postgres credentials:
   - Host: `postgres`
   - Port: `5432`
  - Database: value of `POSTGRES_DB`
  - User: value of `POSTGRES_USER`
  - Password: value of `POSTGRES_PASSWORD`
3. Operation: **Insert rows in a table** (`Insert`).
4. Schema: `public`.
5. Table: `payments`.
6. Mapping mode: `Map Each Column Manually`.
7. Fill columns:
  - `stripe_session_id`: `{{$json.stripe_session_id}}`
  - `customer_email`: `{{$json.customer_email || null}}`
  - `amount_total`: `{{$json.amount_total}}`
  - `currency`: `{{$json.currency}}`
  - `status`: `{{$json.status}}`
8. Do not send `id` and `created_at` (PostgreSQL fills these automatically).
9. Recommended options:
  - `Skip On Conflict`: `On`
  - `Replace Empty Strings With Null`: `On`
  - `Connection Timeout`: `30`

Alternative (equivalent): you can use **Execute a SQL query** with `INSERT ... ON CONFLICT DO NOTHING`.

### Node 5: PostgreSQL (calculate total revenue)

1. Add another **Postgres** node after insert node.
2. Operation: **Execute a SQL query**.
3. Query:

```sql
SELECT COALESCE(SUM(amount_total), 0) AS total_revenue
FROM payments
WHERE status = 'paid';
```

4. Keep this node after the insert node so each new payment recalculates the running total.

### Node 6: IF (check threshold)

1. Add **IF** node after revenue query.
2. Use expression from returned row:
  - Value 1 (Expression): `{{ Number($json["total_revenue"]) }}`
3. Operation: `larger`.
4. Value 2: set your threshold, for example `500`.

### Node 7: Slack (send financial alert)

1. Add **Slack** node on IF true branch.
2. Create Slack credentials (Bot User OAuth Token).
3. Choose operation to send a message to your channel (for example `#finance-alerts`).
4. Example message:

```text
Financial alert: Total revenue reached ${{ Number($json["total_revenue"]).toFixed(2) }}.
Latest Stripe checkout processed successfully.
```

### Activate and test

1. Click **Activate** in n8n workflow.
2. Run Stripe listener command pointing to production webhook URL.
3. Trigger event: `stripe trigger checkout.session.completed`.
4. Check workflow executions in n8n UI.

## 7. SQL queries for Metabase dashboards

You can use the queries in `sql/metabase_queries.sql`.

### Daily revenue

```sql
SELECT
  DATE(created_at) AS day,
  SUM(amount_total) AS daily_revenue
FROM payments
WHERE status = 'paid'
GROUP BY DATE(created_at)
ORDER BY day;
```

### Total revenue

```sql
SELECT SUM(amount_total) AS total_revenue
FROM payments
WHERE status = 'paid';
```

### Payments count

```sql
SELECT COUNT(*) AS payments_count
FROM payments
WHERE status = 'paid';
```

### Average order value

```sql
SELECT AVG(amount_total) AS average_order_value
FROM payments
WHERE status = 'paid';
```

## 8. Connect Metabase to PostgreSQL (step-by-step)

1. Open `http://localhost:3000`.
2. Complete first Metabase admin setup.
3. Click **Add your data** (or **Settings -> Admin settings -> Databases -> Add database**).
4. Choose **PostgreSQL**.
5. Fill connection info:
   - Display Name: `Fintech Postgres`
   - Host: `postgres`
   - Port: `5432`
  - Database name: value of `POSTGRES_DB`
  - Username: value of `POSTGRES_USER`
  - Password: value of `POSTGRES_PASSWORD`
6. Click **Save**.
7. Go to **Browse data** and select `payments` table.
8. Create questions from SQL queries above and pin to a dashboard.

If host `postgres` does not work from Metabase UI for any reason, use `localhost` with port `5432`.

## 9. Example simulated payment JSON

File available at `examples/simulated_payments.json`.

Example object:

```json
{
  "id": "evt_test_001",
  "type": "checkout.session.completed",
  "created": 1710489000,
  "data": {
    "object": {
      "id": "cs_test_a1b2c3d4",
      "customer_details": {
        "email": "ana.silva@example.com"
      },
      "amount_total": 14990,
      "currency": "usd",
      "payment_status": "paid"
    }
  }
}
```

## 10. Troubleshooting common issues

### A) Webhook not triggering

- Confirm workflow is **Active** in n8n.
- Confirm Stripe forward URL matches exactly:
  - Active workflow: `/webhook/stripe-checkout`
  - Test execution: `/webhook-test/stripe-checkout`
- If using Stripe signature validation, confirm `STRIPE_WEBHOOK_SECRET` matches current `stripe listen` secret.
- Check Stripe CLI terminal output for delivery status.
- Check n8n execution history for incoming requests.
- Verify port mapping with `docker compose ps` and ensure `5678` is exposed.

### B) Database connection failing

- Check PostgreSQL container health:

```bash
docker compose ps
docker compose logs postgres
```

- Validate credentials in n8n/Metabase match compose env values.
- Ensure n8n and Metabase use `postgres` as host (container network).
- Confirm table exists:

```bash
docker compose exec postgres psql -U fintech_user -d fintech -c "\dt"
```

### C) Slack alerts not sending

- Verify Slack bot token is valid in n8n credentials.
- Ensure bot is added to target channel.
- Check IF threshold condition; alert runs only on true path.
- Inspect Slack node execution output in n8n for API error details.
- If message formatting fails, test with a plain message first.

## Useful local commands

```bash
# Start stack
docker compose up -d

# Follow logs
docker compose logs -f n8n
docker compose logs -f postgres
docker compose logs -f metabase

# Stop stack
docker compose down

# Stop stack and remove volumes (fresh reset)
docker compose down -v
```
