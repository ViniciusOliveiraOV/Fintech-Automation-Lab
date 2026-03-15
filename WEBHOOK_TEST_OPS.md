# Webhook Test and Operations Commands

Useful commands for local operation and testing of Stripe -> n8n webhook flow.

## 0. Fast command runner (Make + Menu)

Use the new `Makefile` shortcuts:

```bash
cd /home/ovni/n8n1

# List all shortcuts
make help

# Open interactive menu
make menu
```

Examples:

```bash
make up
make ps
make listen-test
make trigger
make db-revenue
```

### 0.1 Make target to verbose command mapping

Use this as a quick reference to understand exactly what each `make` target runs.

| Make target | Verbose command |
|---|---|
| `make up` | `docker compose up -d` |
| `make ps` | `docker compose ps` |
| `make down` | `docker compose down` |
| `make restart-n8n` | `docker compose up -d n8n` |
| `make logs` | `docker compose logs -f` |
| `make logs-n8n` | `docker compose logs -f n8n` |
| `make logs-postgres` | `docker compose logs -f postgres` |
| `make logs-metabase` | `docker compose logs -f metabase` |
| `make listen-test` | `stripe listen --events checkout.session.completed --forward-to http://localhost:5678/webhook-test/stripe-checkout` |
| `make listen-active` | `stripe listen --events checkout.session.completed --forward-to http://localhost:5678/webhook/stripe-checkout` |
| `make listen-test-auth` | `stripe listen --events checkout.session.completed --forward-to "http://$N8N_BASIC_AUTH_USER:$N8N_BASIC_AUTH_PASSWORD@localhost:5678/webhook-test/stripe-checkout"` |
| `make listen-active-auth` | `stripe listen --events checkout.session.completed --forward-to "http://$N8N_BASIC_AUTH_USER:$N8N_BASIC_AUTH_PASSWORD@localhost:5678/webhook/stripe-checkout"` |
| `make trigger` | `stripe trigger checkout.session.completed` |
| `make curl-test` | `curl -X POST http://localhost:5678/webhook-test/stripe-checkout ...` |
| `make curl-active` | `curl -X POST http://localhost:5678/webhook/stripe-checkout ...` |
| `make threshold-test` | `curl -X POST http://localhost:5678/webhook/stripe-checkout ... amount_total=60000 ...` |
| `make db-tables` | `docker compose exec -T postgres psql -U fintech_user -d fintech -c "\\dt"` |
| `make db-last` | `docker compose exec -T postgres psql -U fintech_user -d fintech -c "SELECT ... LIMIT 10;"` |
| `make db-revenue` | `docker compose exec -T postgres psql -U fintech_user -d fintech -c "SELECT COALESCE(SUM(amount_total), 0) AS total_revenue FROM payments WHERE status='paid';"` |
| `make reset-payments` | `docker compose exec -T postgres psql -U fintech_user -d fintech -c "TRUNCATE TABLE payments RESTART IDENTITY;"` |
| `make reset-all` | `docker compose down -v && docker compose up -d` |
| `make menu` | `./scripts/lab-menu.sh` |

## 1. Service operations

```bash
cd /home/ovni/n8n1

# Start stack
docker compose up -d

# Check containers
docker compose ps

# Follow logs
docker compose logs -f n8n
docker compose logs -f postgres
docker compose logs -f metabase

# Stop stack
docker compose down
```

## 2. n8n endpoints used in this project

- n8n UI: `http://localhost:5678`
- Webhook test URL: `http://localhost:5678/webhook-test/stripe-checkout`
- Webhook active URL: `http://localhost:5678/webhook/stripe-checkout`

## 3. Webhook test mode (n8n waiting)

Use this mode after clicking `Execute workflow` in n8n.

```bash
# Terminal 1: listen and forward to TEST webhook
stripe listen --events checkout.session.completed --forward-to http://localhost:5678/webhook-test/stripe-checkout

# Terminal 2: trigger a Stripe test event
stripe trigger checkout.session.completed
```

Notes:
- In test mode, n8n usually accepts one request while waiting.
- If you get 404, click `Execute workflow` again and retry.

## 4. Webhook active mode (published + active workflow)

Use this mode after `Publish` + `Activate` workflow.

```bash
# Terminal 1: listen and forward to ACTIVE webhook
stripe listen --events checkout.session.completed --forward-to http://localhost:5678/webhook/stripe-checkout

# Terminal 2: trigger a Stripe test event
stripe trigger checkout.session.completed
```

## 5. Direct curl payload test (without Stripe)

### 5.1 Test URL (requires n8n waiting)

```bash
curl -X POST http://localhost:5678/webhook-test/stripe-checkout \
  -H "Content-Type: application/json" \
  -d '{
    "type": "checkout.session.completed",
    "data": {
      "object": {
        "id": "cs_test_manual_001",
        "customer_details": { "email": "test@example.com" },
        "amount_total": 60000,
        "currency": "usd",
        "payment_status": "paid"
      }
    }
  }'
```

### 5.2 Active URL (published + active workflow)

```bash
curl -X POST http://localhost:5678/webhook/stripe-checkout \
  -H "Content-Type: application/json" \
  -d '{
    "type": "checkout.session.completed",
    "data": {
      "object": {
        "id": "cs_test_manual_002",
        "customer_details": { "email": "test@example.com" },
        "amount_total": 60000,
        "currency": "usd",
        "payment_status": "paid"
      }
    }
  }'
```

## 6. Threshold test (> 500)

This payload sends `amount_total = 60000` cents (= 600.00), which should pass threshold 500.

```bash
curl -X POST http://localhost:5678/webhook/stripe-checkout \
  -H "Content-Type: application/json" \
  -d '{
    "type": "checkout.session.completed",
    "data": {
      "object": {
        "id": "cs_test_over_500_001",
        "customer_details": { "email": "highvalue@example.com" },
        "amount_total": 60000,
        "currency": "usd",
        "payment_status": "paid"
      }
    }
  }'
```

Important:
- Use a new `id` each run (`cs_test_over_500_002`, etc.) to avoid unique constraint conflicts on `stripe_session_id`.

## 7. Database validation commands

```bash
# List tables
docker compose exec -T postgres psql -U fintech_user -d fintech -c "\\dt"

# Last 10 payments
docker compose exec -T postgres psql -U fintech_user -d fintech -c "SELECT id, stripe_session_id, customer_email, amount_total, currency, status, created_at FROM payments ORDER BY id DESC LIMIT 10;"

# Current paid revenue
docker compose exec -T postgres psql -U fintech_user -d fintech -c "SELECT COALESCE(SUM(amount_total), 0) AS total_revenue FROM payments WHERE status='paid';"
```

## 8. Optional reset commands for repeatable tests

```bash
# Clear payments only (keep schema)
docker compose exec -T postgres psql -U fintech_user -d fintech -c "TRUNCATE TABLE payments RESTART IDENTITY;"

# Full reset (removes all data volumes)
docker compose down -v && docker compose up -d
```

## 9. If Stripe signature validation is enabled

If your workflow uses the Code node from `n8n/stripe_signature_verification.js`:

1. Ensure `.env` contains real `STRIPE_WEBHOOK_SECRET` from `stripe listen` output.
2. Restart n8n after updating `.env`:

```bash
docker compose up -d n8n
```

3. Prefer Stripe-based tests (`stripe listen` + `stripe trigger`) instead of raw `curl`, because `curl` does not include Stripe signature header by default.
