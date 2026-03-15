# Feature Checklist

This file tracks delivered features and pending work for the Fintech Automation Lab.

## Legend

- `[x]` Implemented
- `[ ]` Pending

## Core Lab Scope

- [x] Project folder structure scaffolded
- [x] `docker-compose.yml` with PostgreSQL, n8n, Metabase
- [x] PostgreSQL init SQL for `payments` table
- [x] Stripe CLI setup and event simulation commands documented
- [x] Stripe -> n8n webhook forwarding flow documented
- [x] n8n step-by-step nodes (Webhook, IF, Code, Postgres, Slack)
- [x] Metabase SQL queries (daily revenue, total revenue, count, AOV)
- [x] Metabase connection instructions documented
- [x] Simulated payment JSON examples included
- [x] Troubleshooting section for webhook, DB, and Slack issues

## Security and Configuration

- [x] Secrets moved out of hardcoded Compose values into `.env`
- [x] `.env.example` added as safe template
- [x] Sensitive files ignored via `.gitignore`
- [x] Stripe signature validation script added (`n8n/stripe_signature_verification.js`)
- [x] README updated with webhook signature validation steps
- [ ] Real `STRIPE_WEBHOOK_SECRET` set in `.env` and validated end-to-end
- [ ] Signature validation node enabled in the currently running workflow

## Operations and Developer Experience

- [x] `WEBHOOK_TEST_OPS.md` created with test and operations commands
- [x] `Makefile` created with shortcut commands
- [x] Interactive menu script (`scripts/lab-menu.sh`) created
- [x] Menu updated to return from follow commands with Enter
- [x] README linked to webhook operations guide
- [ ] Add `make smoke-test` target (reset payments + inject test payload + check revenue)

## Runtime Environment Status (After Volume Reset)

- [x] Containers recreated successfully (`postgres`, `n8n`, `metabase`)
- [x] Database schema re-initialized (`payments` table exists)
- [ ] n8n workflow fully re-created in current runtime
- [ ] Slack credentials reconfigured in current runtime
- [ ] Postgres credential reconfigured in current n8n instance

## Production-Like Roadmap

- [ ] Add reverse proxy with HTTPS (Nginx/Traefik)
- [ ] Enforce webhook auth + signature validation policy in all environments
- [ ] Add backup/restore automation for PostgreSQL
- [ ] Add error workflow branching and retry policy standard
- [ ] Add centralized logs/metrics/alerts
- [ ] Add CI checks (lint/docs/compose validation)

## How to Use This Checklist

1. Mark completed items by changing `[ ]` to `[x]`.
2. Add new items as requirements evolve.
3. Keep this file updated whenever functionality is added or changed.
