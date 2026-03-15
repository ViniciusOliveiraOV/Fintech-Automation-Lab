SHELL := /bin/bash

ifneq (,$(wildcard .env))
include .env
export
endif

N8N_HOST ?= localhost
N8N_PORT ?= 5678
POSTGRES_DB ?= fintech
POSTGRES_USER ?= fintech_user

TEST_WEBHOOK_URL := http://$(N8N_HOST):$(N8N_PORT)/webhook-test/stripe-checkout
ACTIVE_WEBHOOK_URL := http://$(N8N_HOST):$(N8N_PORT)/webhook/stripe-checkout

.PHONY: help menu up ps down logs logs-n8n logs-postgres logs-metabase
.PHONY: listen-test listen-active listen-test-auth listen-active-auth trigger
.PHONY: curl-test curl-active threshold-test
.PHONY: db-tables db-last db-revenue reset-payments reset-all restart-n8n

help:
	@echo "Fintech Automation Lab - Make Commands"
	@echo ""
	@echo "Stack"
	@echo "  make up               - start containers"
	@echo "  make ps               - show container status"
	@echo "  make down             - stop containers"
	@echo "  make restart-n8n      - restart only n8n"
	@echo ""
	@echo "Logs"
	@echo "  make logs             - follow all logs"
	@echo "  make logs-n8n         - follow n8n logs"
	@echo "  make logs-postgres    - follow postgres logs"
	@echo "  make logs-metabase    - follow metabase logs"
	@echo ""
	@echo "Stripe / Webhook"
	@echo "  make listen-test      - stripe listen -> webhook-test"
	@echo "  make listen-active    - stripe listen -> webhook"
	@echo "  make listen-test-auth - stripe listen -> webhook-test with basic auth"
	@echo "  make listen-active-auth - stripe listen -> webhook with basic auth"
	@echo "  make trigger          - stripe trigger checkout.session.completed"
	@echo ""
	@echo "Direct HTTP tests"
	@echo "  make curl-test        - POST sample payload to webhook-test"
	@echo "  make curl-active      - POST sample payload to webhook"
	@echo "  make threshold-test   - POST payload amount_total=60000"
	@echo ""
	@echo "Database"
	@echo "  make db-tables        - list tables"
	@echo "  make db-last          - show last 10 payments"
	@echo "  make db-revenue       - show current paid revenue"
	@echo "  make reset-payments   - truncate payments table"
	@echo "  make reset-all        - down -v and up -d"
	@echo ""
	@echo "Interactive"
	@echo "  make menu             - open interactive menu"

menu:
	@./scripts/lab-menu.sh

up:
	docker compose up -d

ps:
	docker compose ps

down:
	docker compose down

restart-n8n:
	docker compose up -d n8n

logs:
	docker compose logs -f

logs-n8n:
	docker compose logs -f n8n

logs-postgres:
	docker compose logs -f postgres

logs-metabase:
	docker compose logs -f metabase

listen-test:
	stripe listen --events checkout.session.completed --forward-to $(TEST_WEBHOOK_URL)

listen-active:
	stripe listen --events checkout.session.completed --forward-to $(ACTIVE_WEBHOOK_URL)

listen-test-auth:
	stripe listen --events checkout.session.completed --forward-to "http://$(N8N_BASIC_AUTH_USER):$(N8N_BASIC_AUTH_PASSWORD)@$(N8N_HOST):$(N8N_PORT)/webhook-test/stripe-checkout"

listen-active-auth:
	stripe listen --events checkout.session.completed --forward-to "http://$(N8N_BASIC_AUTH_USER):$(N8N_BASIC_AUTH_PASSWORD)@$(N8N_HOST):$(N8N_PORT)/webhook/stripe-checkout"

trigger:
	stripe trigger checkout.session.completed

curl-test:
	curl -X POST $(TEST_WEBHOOK_URL) \
	  -H "Content-Type: application/json" \
	  -d '{"type":"checkout.session.completed","data":{"object":{"id":"cs_test_manual_001","customer_details":{"email":"test@example.com"},"amount_total":60000,"currency":"usd","payment_status":"paid"}}}'

curl-active:
	curl -X POST $(ACTIVE_WEBHOOK_URL) \
	  -H "Content-Type: application/json" \
	  -d '{"type":"checkout.session.completed","data":{"object":{"id":"cs_test_manual_002","customer_details":{"email":"test@example.com"},"amount_total":60000,"currency":"usd","payment_status":"paid"}}}'

threshold-test:
	curl -X POST $(ACTIVE_WEBHOOK_URL) \
	  -H "Content-Type: application/json" \
	  -d '{"type":"checkout.session.completed","data":{"object":{"id":"cs_test_over_500_001","customer_details":{"email":"highvalue@example.com"},"amount_total":60000,"currency":"usd","payment_status":"paid"}}}'

db-tables:
	docker compose exec -T postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -c "\\dt"

db-last:
	docker compose exec -T postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -c "SELECT id, stripe_session_id, customer_email, amount_total, currency, status, created_at FROM payments ORDER BY id DESC LIMIT 10;"

db-revenue:
	docker compose exec -T postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -c "SELECT COALESCE(SUM(amount_total), 0) AS total_revenue FROM payments WHERE status='paid';"

reset-payments:
	docker compose exec -T postgres psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -c "TRUNCATE TABLE payments RESTART IDENTITY;"

reset-all:
	docker compose down -v && docker compose up -d
